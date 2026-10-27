import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'categories.dart';
import 'format.dart';
import 'models.dart';

/// Alat bantu file di Windows: buka dengan aplikasi bawaan, tampilkan di
/// Explorer, simpan salinan, dan export CSV (bisa dibuka di Excel).
class FileTools {
  /// Buka file dengan aplikasi default Windows (PDF reader, Word, Excel, Foto...).
  static Future<void> open(String path) async {
    if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', path], runInShell: false, mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      await Process.start('open', [path], mode: ProcessStartMode.detached);
    } else {
      await Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
    }
  }

  /// Buka Explorer dengan file terpilih.
  static Future<void> showInFolder(String path) async {
    if (Platform.isWindows) {
      await Process.start('explorer.exe', ['/select,', path], mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      await Process.start('open', ['-R', path], mode: ProcessStartMode.detached); // tampilkan di Finder
    } else {
      await open(File(path).parent.path);
    }
  }

  /// Simpan salinan file ke lokasi pilihan user. Mengembalikan path tujuan
  /// atau null kalau dibatalkan.
  static Future<String?> saveCopy(String sourcePath, String suggestedName) async {
    final target = await FilePicker.platform.saveFile(dialogTitle: 'Simpan salinan dokumen', fileName: suggestedName);
    if (target == null) return null;
    await File(sourcePath).copy(target);
    return target;
  }

  static String _csv(Object? v) {
    final s = (v ?? '').toString().replaceAll('"', '""');
    return '"$s"';
  }

  /// Export daftar dokumen ke CSV (pemisah ';' + BOM UTF-8 supaya langsung
  /// rapi saat dibuka di Excel versi Indonesia).
  static Future<String?> exportDocsCsv(List<DocRecord> docs, {String fileName = 'daftar_dokumen.csv'}) async {
    final target = await FilePicker.platform.saveFile(
      dialogTitle: 'Export daftar dokumen',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (target == null) return null;
    final path = target.toLowerCase().endsWith('.csv') ? target : '$target.csv';
    final b = StringBuffer()
      ..writeln(['No', 'Judul', 'Nomor Dokumen', 'Tanggal Dokumen', 'Kategori', 'Kode Paket', 'Nama Paket', 'Nama File', 'Ukuran',
              'Tag', 'Seri', 'Keterangan', 'Diunggah Oleh', 'Tanggal Input', 'Status']
          .map(_csv)
          .join(';'));
    var i = 1;
    for (final d in docs) {
      b.writeln([
        i++,
        d.title,
        d.docNumber,
        d.docDate,
        categoryOf(d.category).label,
        d.projectCode,
        d.projectName,
        d.fileName,
        formatBytes(d.fileSize),
        d.tags,
        d.series,
        d.description,
        d.createdByName,
        formatDateTime(d.createdAt),
        statusLabel(d.status),
      ].map(_csv).join(';'));
    }
    await File(path).writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(b.toString())], flush: true);
    return path;
  }

  static Future<String?> exportProjectsCsv(List<Project> projects, Map<String, int> docCount) async {
    final target = await FilePicker.platform.saveFile(
      dialogTitle: 'Export daftar proyek',
      fileName: 'daftar_proyek.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (target == null) return null;
    final path = target.toLowerCase().endsWith('.csv') ? target : '$target.csv';
    final b = StringBuffer()
      ..writeln(['Kode Paket', 'Nama Paket', 'Jenis', 'Lokasi', 'Tahun', 'Sumber Dana', 'Nilai Kontrak', 'No. Kontrak', 'Kontraktor',
              'Konsultan Pengawas', 'PPK', 'Mulai', 'Selesai', 'Status', 'Progres (%)', 'Jumlah Dokumen']
          .map(_csv)
          .join(';'));
    for (final p in projects) {
      b.writeln([
        p.code, p.name, p.type, p.location, p.year, p.fundingSource, p.contractValue.round(), p.contractNumber,
        p.contractor, p.supervisor, p.ppk, p.startDate, p.endDate, p.status, p.progress, docCount[p.id] ?? 0,
      ].map(_csv).join(';'));
    }
    await File(path).writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(b.toString())], flush: true);
    return path;
  }
}

String statusLabel(DocStatus s) => switch (s) {
      DocStatus.draft => 'Draf (belum dikirim)',
      DocStatus.pending => 'Menunggu upload',
      DocStatus.uploading => 'Sedang diunggah',
      DocStatus.uploaded => 'Tersimpan di server',
      DocStatus.failed => 'Gagal',
    };
