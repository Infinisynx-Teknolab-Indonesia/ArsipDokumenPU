import 'dart:io';
import 'dart:typed_data';
import 'package:pdfrx/pdfrx.dart';
import 'win_printer.dart';

/// Cetak PDF ke printer — dipakai untuk SEMUA jenis dokumen (Word/Excel/teks/
/// foto diubah dulu jadi PDF oleh pdf_builder.dart).
///  - Windows : halaman dirender pdfrx lalu dikirim ke printer lewat API Windows.
///  - macOS   : lewat sistem cetak bawaan (CUPS, perintah `lp`).
class PrintService {
  PrintService._();

  /// (daftar printer, printer default)
  static Future<(List<String>, String?)> printers() async {
    if (Platform.isWindows) return winListPrinters();
    // macOS / Linux: CUPS
    final names = <String>[];
    String? def;
    try {
      final r = await Process.run('lpstat', ['-p']);
      for (final line in r.stdout.toString().split('\n')) {
        final m = RegExp(r'^printer\s+(\S+)').firstMatch(line.trim());
        if (m != null) names.add(m.group(1)!);
      }
      final d = await Process.run('lpstat', ['-d']);
      final m = RegExp(r':\s*(\S+)\s*$').firstMatch(d.stdout.toString().trim());
      if (m != null && m.group(1) != 'destination') def = m.group(1);
    } catch (_) {}
    if (def != null && !names.contains(def)) names.insert(0, def);
    return (names, def);
  }

  /// Jumlah halaman PDF (untuk dialog cetak).
  static Future<int> pageCount(String pdfPath) async {
    final doc = await PdfDocument.openFile(pdfPath);
    try {
      return doc.pages.length;
    } finally {
      await doc.dispose();
    }
  }

  /// "1-3, 5" -> {1,2,3,5}. Kosong = semua halaman (null).
  static Set<int>? parseRanges(String text, int pageCount) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final out = <int>{};
    for (final part in t.split(RegExp(r'[,;\s]+'))) {
      if (part.isEmpty) continue;
      final m = RegExp(r'^(\d+)(?:-(\d+))?$').firstMatch(part);
      if (m == null) throw FormatException('Format halaman salah: "$part". Contoh: 1-3, 5');
      final a = int.parse(m.group(1)!);
      final b = m.group(2) == null ? a : int.parse(m.group(2)!);
      for (var i = a <= b ? a : b; i <= (a <= b ? b : a); i++) {
        if (i >= 1 && i <= pageCount) out.add(i);
      }
    }
    if (out.isEmpty) throw FormatException('Halaman di luar jangkauan (1–$pageCount).');
    return out;
  }

  /// Cetak [pdfPath] ke [printer]. [onProgress] dipanggil (halaman ke-n, total).
  static Future<void> printPdf({
    required String pdfPath,
    required String printer,
    required String jobName,
    int copies = 1,
    Set<int>? pages,
    void Function(int done, int total)? onProgress,
  }) async {
    if (Platform.isWindows) {
      await _printWindows(pdfPath, printer, jobName, copies, pages, onProgress);
    } else {
      await _printCups(pdfPath, printer, jobName, copies, pages);
    }
  }

  static Future<void> _printCups(String path, String printer, String jobName, int copies, Set<int>? pages) async {
    final args = ['-d', printer, '-n', '$copies', '-t', jobName];
    if (pages != null) {
      final sorted = pages.toList()..sort();
      args.addAll(['-o', 'page-ranges=${sorted.join(',')}']);
    }
    args.add(path);
    final r = await Process.run('lp', args);
    if (r.exitCode != 0) throw Exception('Gagal mencetak: ${r.stderr.toString().trim()}');
  }

  static Future<void> _printWindows(
      String path, String printer, String jobName, int copies, Set<int>? pages, void Function(int, int)? onProgress) async {
    final doc = await PdfDocument.openFile(path);
    WinPrintJob? job;
    try {
      final list = [for (var i = 1; i <= doc.pages.length; i++) if (pages == null || pages.contains(i)) i];
      final total = list.length * copies;
      job = WinPrintJob.start(printer, jobName);
      final paperLandscape = job.width > job.height;
      var done = 0;
      for (var c = 0; c < copies; c++) {
        for (final n in list) {
          final page = doc.pages[n - 1];
          final pageLandscape = page.width > page.height;
          final rotate = pageLandscape != paperLandscape;
          // resolusi render: sesuai area cetak (maks ~2600 px sisi terpanjang supaya hemat memori)
          final targetW = rotate ? job.height : job.width;
          final targetH = rotate ? job.width : job.height;
          var scale = targetW / page.width < targetH / page.height ? targetW / page.width : targetH / page.height;
          final longest = (page.width > page.height ? page.width : page.height) * scale;
          if (longest > 2600) scale *= 2600 / longest;
          final w = (page.width * scale).round();
          final h = (page.height * scale).round();
          final img = await page.render(fullWidth: w.toDouble(), fullHeight: h.toDouble(), width: w, height: h, backgroundColor: 0xFFFFFFFF);
          if (img == null) throw Exception('Halaman $n tidak bisa dirender.');
          try {
            if (rotate) {
              final (px, rw, rh) = _rotate90(img.pixels, img.width, img.height);
              job.printPage(px, rw, rh);
            } else {
              job.printPage(img.pixels, img.width, img.height);
            }
          } finally {
            img.dispose();
          }
          done++;
          onProgress?.call(done, total);
          await Future<void>.delayed(Duration.zero); // beri kesempatan UI menggambar progres
        }
      }
      job.finish();
      job = null;
    } catch (e) {
      job?.abort();
      rethrow;
    } finally {
      await doc.dispose();
    }
  }

  /// Putar gambar BGRA 90° searah jarum jam (halaman mendatar di kertas tegak).
  static (Uint8List, int, int) _rotate90(Uint8List src, int w, int h) {
    final aligned = src.offsetInBytes % 4 == 0 ? src : Uint8List.fromList(src);
    final dst = Uint8List(w * h * 4);
    final s32 = aligned.buffer.asUint32List(aligned.offsetInBytes, w * h);
    final d32 = dst.buffer.asUint32List(0, w * h);
    // (x, y) -> (h - 1 - y, x) pada gambar baru berukuran h x w
    for (var y = 0; y < h; y++) {
      final row = y * w;
      final nx = h - 1 - y;
      for (var x = 0; x < w; x++) {
        d32[x * h + nx] = s32[row + x];
      }
    }
    return (dst, h, w);
  }
}
