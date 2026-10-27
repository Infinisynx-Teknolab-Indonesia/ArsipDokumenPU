import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Pembaca Excel (.xlsx) dan CSV menjadi tabel untuk ditampilkan di aplikasi
/// tanpa Microsoft Excel / WPS. Murni Dart, berjalan di isolate.
/// Mendukung: banyak sheet, teks, angka (format ribuan Indonesia, persen,
/// Rupiah), tanggal, rumus (hasil terakhir yang tersimpan), sel gabung
/// (mendatar), huruf tebal, warna isi sel, lebar kolom.

const maxSheetRows = 20000;
const maxSheetCols = 200;

class SheetCell {
  final String text;
  final bool bold;
  final bool alignRight;
  final bool alignCenter;
  final Color? fill;
  final Color? color;
  final int colSpan; // > 1 bila sel digabung ke kanan
  const SheetCell(this.text, {this.bold = false, this.alignRight = false, this.alignCenter = false, this.fill, this.color, this.colSpan = 1});
}

class SheetData {
  final String name;
  final List<List<SheetCell?>> rows; // baris -> kolom
  final int colCount;
  final List<double> colWidths; // px pada zoom 100%
  final Set<int> covered; // sel yang tertutup sel gabung: r * 100000 + c
  final bool truncated;
  SheetData({required this.name, required this.rows, required this.colCount, required this.colWidths, required this.covered, required this.truncated});
}

class WorkbookData {
  final List<SheetData> sheets;
  WorkbookData(this.sheets);
}

String? _attr(XmlElement? e, String local) {
  if (e == null) return null;
  for (final a in e.attributes) {
    if (a.name.local == local) return a.value;
  }
  return null;
}

XmlElement? _child(XmlElement? e, String local) {
  if (e == null) return null;
  for (final c in e.childElements) {
    if (c.name.local == local) return c;
  }
  return null;
}

Iterable<XmlElement> _children(XmlElement? e, String local) =>
    e == null ? const <XmlElement>[] : e.childElements.where((c) => c.name.local == local);

List<int> _fileBytes(ArchiveFile f) => (f.content as List).cast<int>();

Color? _argb(String? v) {
  if (v == null) return null;
  var h = v.trim();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final n = int.tryParse(h, radix: 16);
  if (n == null) return null;
  final c = Color(n | 0xFF000000);
  // putih / hitam pekat sebagai isi sel biasanya bawaan, abaikan isi putih
  if ((n & 0xFFFFFF) == 0xFFFFFF) return null;
  return c;
}

/// "B12" -> (11, 1)
(int, int) cellRef(String ref) {
  var col = 0;
  var i = 0;
  while (i < ref.length) {
    final ch = ref.codeUnitAt(i);
    if (ch >= 65 && ch <= 90) {
      col = col * 26 + (ch - 64);
    } else if (ch >= 97 && ch <= 122) {
      col = col * 26 + (ch - 96);
    } else {
      break;
    }
    i++;
  }
  final row = int.tryParse(ref.substring(i)) ?? 1;
  return (row - 1, col - 1);
}

/// 0 -> "A", 27 -> "AB"
String colName(int c) {
  final b = StringBuffer();
  var x = c + 1;
  while (x > 0) {
    x--;
    b.write(String.fromCharCode(65 + x % 26));
    x ~/= 26;
  }
  return b.toString().split('').reversed.join();
}

class _Xf {
  final int numFmt;
  final int font;
  final int fill;
  final String? hAlign;
  _Xf(this.numFmt, this.font, this.fill, this.hAlign);
}

class SheetParser {
  static WorkbookData parseXlsx(Uint8List bytes) {
    final zip = ZipDecoder().decodeBytes(bytes);
    XmlDocument? xml(String p) {
      final f = zip.findFile(p);
      if (f == null) return null;
      try {
        return XmlDocument.parse(utf8.decode(_fileBytes(f), allowMalformed: true));
      } catch (_) {
        return null;
      }
    }

    final wb = xml('xl/workbook.xml');
    if (wb == null) throw const FormatException('Bukan file Excel (.xlsx) yang valid.');

    // relasi workbook -> file sheet
    final rels = <String, String>{};
    final relX = xml('xl/_rels/workbook.xml.rels');
    if (relX != null) {
      for (final r in relX.rootElement.childElements) {
        final id = _attr(r, 'Id'), t = _attr(r, 'Target');
        if (id == null || t == null) continue;
        rels[id] = t.startsWith('/') ? t.substring(1) : 'xl/${t.replaceFirst(RegExp(r'^\./'), '')}';
      }
    }

    // teks bersama
    final shared = <String>[];
    final ss = xml('xl/sharedStrings.xml');
    if (ss != null) {
      for (final si in _children(ss.rootElement, 'si')) {
        final b = StringBuffer();
        void collect(XmlElement e) {
          for (final c in e.childElements) {
            if (c.name.local == 'rPh' || c.name.local == 'phoneticPr') continue;
            if (c.name.local == 't') {
              b.write(c.innerText);
            } else {
              collect(c);
            }
          }
        }

        collect(si);
        shared.add(b.toString());
      }
    }

    // style: format angka, huruf tebal, warna isi
    final fmts = <int, String>{};
    final fontsBold = <bool>[];
    final fontsColor = <Color?>[];
    final fills = <Color?>[];
    final xfs = <_Xf>[];
    final st = xml('xl/styles.xml');
    if (st != null) {
      final root = st.rootElement;
      for (final f in _children(_child(root, 'numFmts'), 'numFmt')) {
        final id = int.tryParse(_attr(f, 'numFmtId') ?? '');
        if (id != null) fmts[id] = _attr(f, 'formatCode') ?? '';
      }
      for (final f in _children(_child(root, 'fonts'), 'font')) {
        final b = _child(f, 'b');
        fontsBold.add(b != null && _attr(b, 'val') != '0' && _attr(b, 'val') != 'false');
        fontsColor.add(_argb(_attr(_child(f, 'color'), 'rgb')));
      }
      for (final f in _children(_child(root, 'fills'), 'fill')) {
        final pf = _child(f, 'patternFill');
        final type = _attr(pf, 'patternType');
        fills.add(type == null || type == 'none' ? null : _argb(_attr(_child(pf, 'fgColor'), 'rgb')));
      }
      for (final x in _children(_child(root, 'cellXfs'), 'xf')) {
        xfs.add(_Xf(
          int.tryParse(_attr(x, 'numFmtId') ?? '') ?? 0,
          int.tryParse(_attr(x, 'fontId') ?? '') ?? 0,
          int.tryParse(_attr(x, 'fillId') ?? '') ?? 0,
          _attr(_child(x, 'alignment'), 'horizontal'),
        ));
      }
    }
    final date1904 = _attr(_child(wb.rootElement, 'workbookPr'), 'date1904') == '1';

    final sheets = <SheetData>[];
    for (final s in _children(_child(wb.rootElement, 'sheets'), 'sheet')) {
      final name = _attr(s, 'name') ?? 'Sheet${sheets.length + 1}';
      if (_attr(s, 'state') == 'hidden' || _attr(s, 'state') == 'veryHidden') continue;
      final rid = _attr(s, 'id');
      final path = rid == null ? null : rels[rid];
      final sx = path == null ? null : xml(path);
      if (sx == null) {
        sheets.add(SheetData(name: name, rows: const [], colCount: 0, colWidths: const [], covered: const {}, truncated: false));
        continue;
      }
      sheets.add(_sheet(name, sx.rootElement, shared, fmts, fontsBold, fontsColor, fills, xfs, date1904));
    }
    if (sheets.isEmpty) throw const FormatException('Workbook tidak berisi sheet.');
    return WorkbookData(sheets);
  }

  static SheetData _sheet(String name, XmlElement root, List<String> shared, Map<int, String> fmts, List<bool> fontsBold,
      List<Color?> fontsColor, List<Color?> fills, List<_Xf> xfs, bool date1904) {
    final cells = <int, Map<int, SheetCell>>{};
    var maxRow = -1, maxCol = -1;
    var truncated = false;
    final data = _child(root, 'sheetData');
    var autoRow = -1;
    for (final row in _children(data, 'row')) {
      final rAttr = int.tryParse(_attr(row, 'r') ?? '');
      final r = rAttr != null ? rAttr - 1 : autoRow + 1;
      autoRow = r;
      if (r >= maxSheetRows) {
        truncated = true;
        break;
      }
      var autoCol = -1;
      for (final c in _children(row, 'c')) {
        final ref = _attr(c, 'r');
        final int col;
        if (ref != null) {
          col = cellRef(ref).$2;
        } else {
          col = autoCol + 1;
        }
        autoCol = col;
        if (col >= maxSheetCols) {
          truncated = true;
          continue;
        }
        final t = _attr(c, 't');
        final s = int.tryParse(_attr(c, 's') ?? '') ?? 0;
        final xf = s < xfs.length ? xfs[s] : null;
        final v = _child(c, 'v')?.innerText;
        String text;
        var isNum = false;
        switch (t) {
          case 's':
            final i = int.tryParse(v ?? '');
            text = i != null && i < shared.length ? shared[i] : '';
          case 'inlineStr':
            text = _child(c, 'is')?.descendants.whereType<XmlElement>().where((e) => e.name.local == 't').map((e) => e.innerText).join() ?? '';
          case 'str':
            text = v ?? '';
          case 'b':
            text = v == '1' ? 'TRUE' : 'FALSE';
            isNum = true;
          case 'e':
            text = v ?? '#ERROR';
          default:
            if (v == null || v.isEmpty) {
              text = '';
            } else {
              final n = double.tryParse(v);
              if (n == null) {
                text = v;
              } else {
                isNum = true;
                text = _formatNumber(n, xf?.numFmt ?? 0, fmts, date1904);
              }
            }
        }
        final fill = xf != null && xf.fill < fills.length ? fills[xf.fill] : null;
        if (text.isEmpty && fill == null) continue;
        final h = xf?.hAlign;
        cells.putIfAbsent(r, () => {})[col] = SheetCell(
          text,
          bold: xf != null && xf.font < fontsBold.length && fontsBold[xf.font],
          color: xf != null && xf.font < fontsColor.length ? fontsColor[xf.font] : null,
          fill: fill,
          alignRight: h == 'right' || (h == null && isNum),
          alignCenter: h == 'center' || h == 'centerContinuous',
        );
        if (r > maxRow) maxRow = r;
        if (col > maxCol) maxCol = col;
      }
    }

    // sel gabung
    final covered = <int>{};
    for (final mc in _children(_child(root, 'mergeCells'), 'mergeCell')) {
      final ref = _attr(mc, 'ref');
      if (ref == null || !ref.contains(':')) continue;
      final a = cellRef(ref.split(':')[0]), b = cellRef(ref.split(':')[1]);
      if (a.$1 >= maxSheetRows || a.$2 >= maxSheetCols) continue;
      final span = (b.$2 - a.$2 + 1).clamp(1, maxSheetCols).toInt();
      final origin = cells[a.$1]?[a.$2];
      if (origin != null && span > 1) {
        cells[a.$1]![a.$2] = SheetCell(origin.text,
            bold: origin.bold, alignRight: origin.alignRight, alignCenter: true, fill: origin.fill, color: origin.color, colSpan: span);
      }
      for (var r = a.$1; r <= b.$1 && r < maxSheetRows; r++) {
        for (var c = a.$2; c <= b.$2 && c < maxSheetCols; c++) {
          if (r == a.$1 && c == a.$2) continue;
          if (r == a.$1) covered.add(r * 100000 + c);
        }
      }
      if (b.$2 > maxCol) maxCol = b.$2.clamp(0, maxSheetCols - 1).toInt();
    }

    final colCount = maxCol + 1;
    // lebar kolom (satuan karakter Excel -> px)
    final widths = List<double>.filled(colCount < 0 ? 0 : colCount, 72);
    final dfw = double.tryParse(_attr(_child(root, 'sheetFormatPr'), 'defaultColWidth') ?? '');
    if (dfw != null) {
      for (var i = 0; i < widths.length; i++) {
        widths[i] = (dfw * 7 + 5).clamp(24, 600).toDouble();
      }
    }
    for (final col in _children(_child(root, 'cols'), 'col')) {
      final min = int.tryParse(_attr(col, 'min') ?? '') ?? 1;
      final max = int.tryParse(_attr(col, 'max') ?? '') ?? min;
      final w = double.tryParse(_attr(col, 'width') ?? '');
      final hidden = _attr(col, 'hidden') == '1';
      for (var i = min - 1; i < max && i < widths.length; i++) {
        if (i < 0) continue;
        if (hidden) {
          widths[i] = 0;
        } else if (w != null) {
          widths[i] = (w * 7 + 5).clamp(24, 600).toDouble();
        }
      }
    }

    final rows = <List<SheetCell?>>[];
    for (var r = 0; r <= maxRow; r++) {
      final m = cells[r];
      rows.add(List<SheetCell?>.generate(colCount, (c) => m?[c]));
    }
    return SheetData(name: name, rows: rows, colCount: colCount < 0 ? 0 : colCount, colWidths: widths, covered: covered, truncated: truncated);
  }

  static const _builtinDate = {14, 15, 16, 17, 22, 27, 30, 36, 50, 57};
  static const _builtinTime = {18, 19, 20, 21, 45, 46, 47};

  static String _formatNumber(double n, int fmtId, Map<int, String> fmts, bool date1904) {
    final code = fmts[fmtId] ?? '';
    final lc = code.toLowerCase().replaceAll(RegExp(r'"[^"]*"|\[[^\]]*\]|\\.'), '');
    final isDate = _builtinDate.contains(fmtId) || (code.isNotEmpty && RegExp(r'[dy]').hasMatch(lc) && !lc.contains('#'));
    final isTime = _builtinTime.contains(fmtId) || (code.isNotEmpty && RegExp(r'h').hasMatch(lc) && RegExp(r'[hs]').hasMatch(lc) && !lc.contains('#'));
    if (isDate || isTime) return _excelDate(n, isDate, isTime || lc.contains('h'), date1904);
    if (fmtId == 9 || fmtId == 10 || code.contains('%')) {
      final dec = fmtId == 10 ? 2 : _decimals(code);
      return '${_group((n * 100), dec)}%';
    }
    final rupiah = code.contains('Rp') || code.contains('IDR');
    final grouped = const {3, 4, 37, 38, 39, 40}.contains(fmtId) || code.contains('#,##') || rupiah;
    int dec;
    if (fmtId == 2 || fmtId == 4 || fmtId == 39 || fmtId == 40) {
      dec = 2;
    } else if (fmtId == 1 || fmtId == 3 || fmtId == 37 || fmtId == 38) {
      dec = 0;
    } else if (code.isNotEmpty) {
      dec = _decimals(code);
    } else {
      dec = -1; // General
    }
    String out;
    if (dec < 0) {
      if (n == n.roundToDouble() && n.abs() < 1e15) {
        out = grouped ? _group(n, 0) : n.toInt().toString();
      } else {
        var s = n.toStringAsPrecision(11);
        if (s.contains('e')) return s;
        if (s.contains('.')) s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
        out = s.replaceAll('.', ',');
      }
    } else {
      out = grouped ? _group(n, dec) : n.toStringAsFixed(dec).replaceAll('.', ',');
    }
    if (rupiah) out = 'Rp ${out.startsWith('-') ? '-${out.substring(1)}' : out}';
    return out;
  }

  static int _decimals(String code) {
    final m = RegExp(r'\.(0+)').firstMatch(code.split(';').first);
    return m == null ? 0 : m.group(1)!.length;
  }

  /// 1250000.5 -> "1.250.000,50" (gaya Indonesia)
  static String _group(double n, int dec) {
    final neg = n < 0;
    final fixed = n.abs().toStringAsFixed(dec);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final b = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) b.write('.');
      b.write(intPart[i]);
    }
    final s = parts.length > 1 ? '$b,${parts[1]}' : b.toString();
    return neg ? '-$s' : s;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _excelDate(double serial, bool withDate, bool withTime, bool date1904) {
    final base = date1904 ? DateTime.utc(1904, 1, 1) : DateTime.utc(1899, 12, 30);
    final ms = (serial * 86400000).round();
    final d = base.add(Duration(milliseconds: ms));
    final date = '${_two(d.day)}/${_two(d.month)}/${d.year}';
    final time = '${_two(d.hour)}:${_two(d.minute)}';
    if (withDate && withTime && (serial % 1) != 0) return '$date $time';
    if (!withDate && withTime) return time;
    return date;
  }

  // ------------------------------------------------------------ CSV

  static WorkbookData parseCsv(Uint8List bytes, String name) {
    var text = _decodeText(bytes);
    if (text.startsWith('﻿')) text = text.substring(1);
    final firstLine = text.split('\n').first;
    final delim = [';', ',', '\t', '|'].reduce((a, b) => a.allMatches(firstLine).length >= b.allMatches(firstLine).length ? a : b);
    final rows = <List<SheetCell?>>[];
    var maxCol = 0;
    var truncated = false;
    final cur = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    void endRow() {
      cur.add(field.toString());
      field.clear();
      if (rows.length < maxSheetRows) {
        final list = cur.take(maxSheetCols).map((v) {
          final t = v.trim();
          final isNum = RegExp(r'^-?[\d.,]+$').hasMatch(t) && t.isNotEmpty;
          return t.isEmpty ? null : SheetCell(v, alignRight: isNum);
        }).toList();
        if (cur.length > maxSheetCols) truncated = true;
        if (list.length > maxCol) maxCol = list.length;
        rows.add(list);
      } else {
        truncated = true;
      }
      cur.clear();
    }

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == delim) {
        cur.add(field.toString());
        field.clear();
      } else if (ch == '\n') {
        endRow();
      } else if (ch != '\r') {
        field.write(ch);
      }
      if (rows.length >= maxSheetRows) {
        truncated = true;
        break;
      }
    }
    if (field.isNotEmpty || cur.isNotEmpty) endRow();
    for (final r in rows) {
      while (r.length < maxCol) {
        r.add(null);
      }
    }
    // lebar kolom dari isi terpanjang (maks 40 karakter)
    final widths = List<double>.filled(maxCol, 64);
    for (final r in rows.take(500)) {
      for (var c = 0; c < r.length; c++) {
        final len = r[c]?.text.length ?? 0;
        final w = (len.clamp(4, 40) * 7.5 + 14).toDouble();
        if (w > widths[c]) widths[c] = w;
      }
    }
    return WorkbookData([SheetData(name: name, rows: rows, colCount: maxCol, colWidths: widths, covered: const {}, truncated: truncated)]);
  }

  /// UTF-8; kalau gagal anggap Windows-1252/Latin-1 (file lama dari Notepad).
  static String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  static String decodeText(Uint8List bytes) => _decodeText(bytes);
}
