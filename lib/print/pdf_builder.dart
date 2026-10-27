import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../viewer/sheet_parser.dart';

/// Membuat PDF untuk dicetak / disimpan dari dokumen yang BUKAN PDF:
/// halaman Word (gambar hasil penampil), tabel Excel/CSV, teks, dan foto.
/// Murni Dart (paket `pdf`) — tidak butuh Office/WPS.

/// Font sistem (supaya huruf seperti — • “ ” é tampil benar). Kalau tidak ada,
/// pakai Helvetica bawaan PDF.
class PdfFonts {
  final Uint8List? regular;
  final Uint8List? bold;
  const PdfFonts(this.regular, this.bold);

  static PdfFonts load() {
    Uint8List? read(List<String> paths) {
      for (final p in paths) {
        try {
          final f = File(p);
          if (f.existsSync()) return f.readAsBytesSync();
        } catch (_) {}
      }
      return null;
    }

    final win = Platform.environment['WINDIR'] ?? r'C:\Windows';
    return PdfFonts(
      read([
        '$win\\Fonts\\arial.ttf',
        '$win\\Fonts\\segoeui.ttf',
        '/System/Library/Fonts/Supplemental/Arial.ttf',
        '/Library/Fonts/Arial.ttf',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      ]),
      read([
        '$win\\Fonts\\arialbd.ttf',
        '$win\\Fonts\\segoeuib.ttf',
        '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
        '/Library/Fonts/Arial Bold.ttf',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
      ]),
    );
  }

  pw.ThemeData theme() {
    final r = regular, b = bold;
    if (r == null) return pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold());
    return pw.ThemeData.withFont(
      base: pw.Font.ttf(r.buffer.asByteData(r.offsetInBytes, r.lengthInBytes)),
      bold: b == null ? null : pw.Font.ttf(b.buffer.asByteData(b.offsetInBytes, b.lengthInBytes)),
    );
  }
}

/// Satu halaman gambar (mis. halaman Word yang dirender penampil).
class PageImage {
  final Uint8List png;
  final double widthPt, heightPt;
  const PageImage(this.png, this.widthPt, this.heightPt);
}

/// Halaman Word -> PDF (setiap halaman = gambar penuh seukuran kertas aslinya).
Future<Uint8List> pdfFromPageImages(List<PageImage> pages) {
  final doc = pw.Document();
  for (final p in pages) {
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(p.widthPt, p.heightPt, marginAll: 0),
      build: (_) => pw.Image(pw.MemoryImage(p.png), fit: pw.BoxFit.fill),
    ));
  }
  return _save(doc);
}

/// Foto -> PDF satu halaman A4 (otomatis mendatar kalau fotonya lebar).
Future<Uint8List> pdfFromImageFile(Uint8List bytes, {required bool landscape}) {
  final doc = pw.Document();
  doc.addPage(pw.Page(
    pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(24),
    build: (_) => pw.Center(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain)),
  ));
  return _save(doc);
}

/// Teks -> PDF A4 (huruf monospace, nomor halaman di bawah).
Future<Uint8List> pdfFromText(String text, String title, PdfFonts fonts) {
  final doc = pw.Document(theme: fonts.theme());
  final lines = text.replaceAll('\r\n', '\n').replaceAll('\t', '    ').split('\n');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
    maxPages: 5000,
    header: (c) => _header(title, c),
    footer: _footer,
    build: (_) => [
      for (final l in lines)
        pw.Text(l.isEmpty ? ' ' : l, style: pw.TextStyle(font: pw.Font.courier(), fontSize: 9, lineSpacing: 1.5)),
    ],
  ));
  return _save(doc);
}

/// Sheet Excel / CSV -> PDF A4 mendatar, kolom diperkecil supaya muat selebar kertas.
Future<Uint8List> pdfFromSheet(SheetData s, String title, PdfFonts fonts) {
  final doc = pw.Document(theme: fonts.theme());
  final format = PdfPageFormat.a4.landscape;
  const margin = 24.0;
  final avail = format.width - margin * 2;
  // kolom yang terlihat (lebar > 0), lebar px -> pt
  final cols = <int>[for (var i = 0; i < s.colCount; i++) if (i < s.colWidths.length && s.colWidths[i] > 0) i];
  final widths = [for (final c in cols) s.colWidths[c] * 0.75];
  final total = widths.fold<double>(0, (a, b) => a + b);
  final scale = total > avail && total > 0 ? avail / total : 1.0;
  final fontSize = (8.5 * scale).clamp(4.5, 8.5).toDouble();
  final border = pw.TableBorder.all(color: PdfColor.fromInt(0xFFBDBDBD), width: 0.4);

  pw.Widget cell(SheetCell? c) {
    if (c == null || c.text.isEmpty) return pw.SizedBox(height: fontSize + 4);
    final color = c.color;
    return pw.Container(
      color: c.fill == null ? null : PdfColor.fromInt(_argb(c.fill!)),
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
      alignment: c.alignCenter
          ? pw.Alignment.center
          : (c.alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
      child: pw.Text(
        c.text,
        maxLines: 3,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: c.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color == null ? null : PdfColor.fromInt(_argb(color)),
        ),
      ),
    );
  }

  doc.addPage(pw.MultiPage(
    pageFormat: format,
    margin: const pw.EdgeInsets.all(margin),
    maxPages: 5000,
    header: (c) => _header('$title — ${s.name}', c),
    footer: _footer,
    build: (_) => [
      if (cols.isEmpty || s.rows.isEmpty)
        pw.Text('Sheet kosong.')
      else
        pw.Table(
          border: border,
          columnWidths: {for (var i = 0; i < cols.length; i++) i: pw.FixedColumnWidth(widths[i] * scale)},
          children: [
            for (final row in s.rows)
              pw.TableRow(children: [for (final c in cols) cell(c < row.length ? row[c] : null)]),
          ],
        ),
    ],
  ));
  return _save(doc);
}

pw.Widget _header(String title, pw.Context c) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(title, maxLines: 1, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF666666))),
    );

pw.Widget _footer(pw.Context c) => pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 6),
      child: pw.Text('Halaman ${c.pageNumber} / ${c.pagesCount}', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF888888))),
    );

Future<Uint8List> _save(pw.Document doc) => doc.save();

// ignore: deprecated_member_use
int _argb(Color c) => c.value; // .value ada di semua versi Flutter (versi baru: toARGB32)
