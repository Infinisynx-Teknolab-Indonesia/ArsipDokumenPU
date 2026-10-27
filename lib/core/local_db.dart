import 'dart:io';
import 'package:sembast/sembast_io.dart';

/// Database NoSQL lokal (Sembast, murni Dart — tidak butuh DLL/SQLite).
/// File: %APPDATA%\ArsipDokumenPU\arsip.db
///
/// Store (koleksi):
///   settings   -> 1 dokumen 'app' (alamat API, status terhubung)
///   users      -> cache akun untuk login offline (hash PBKDF2, bukan password)
///   projects   -> cache daftar proyek / paket pekerjaan dari server
///   documents  -> semua dokumen: antrian upload PC ini + cache dari server
///
/// File dokumen disimpan di folder files\<client_id>\ supaya tetap ada walau
/// file aslinya dipindah sebelum terupload.
class LocalDb {
  LocalDb._();

  static Directory? _base;
  static Database? _db;

  static final settings = stringMapStoreFactory.store('settings');
  static final users = stringMapStoreFactory.store('users');
  static final projects = stringMapStoreFactory.store('projects');
  static final documents = stringMapStoreFactory.store('documents');

  /// Token isi file per dokumen (key = client_id) untuk pencarian isi file offline.
  static final tokens = stringMapStoreFactory.store('search_tokens');

  /// Kamus pencarian (istilah <-> kata/kode terkait).
  static final terms = stringMapStoreFactory.store('search_terms');

  static Directory get baseDir {
    final existing = _base;
    if (existing != null) return existing;
    final String appData;
    if (Platform.isMacOS) {
      // macOS: ~/Library/Application Support/ArsipDokumenPU
      appData = '${Platform.environment['HOME'] ?? Directory.current.path}/Library/Application Support';
    } else {
      appData = Platform.environment['APPDATA'] ?? Platform.environment['HOME'] ?? Directory.current.path;
    }
    final dir = Directory('$appData${Platform.pathSeparator}ArsipDokumenPU');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _base = dir;
    return dir;
  }

  static String get dbPath => '${baseDir.path}${Platform.pathSeparator}arsip.db';

  static Database get db {
    final d = _db;
    if (d == null) throw StateError('LocalDb.open() belum dipanggil');
    return d;
  }

  static Future<void> open() async {
    _db ??= await databaseFactoryIo.openDatabase(dbPath);
  }

  /// Folder sementara untuk file versi lama / file permintaan edit yang dibuka.
  static Directory tempDir(String name) {
    final dir = Directory('${baseDir.path}${Platform.pathSeparator}temp${Platform.pathSeparator}$name');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Folder salinan file untuk satu dokumen.
  static Directory filesDir(String clientId) {
    final safe = clientId.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final dir = Directory('${baseDir.path}${Platform.pathSeparator}files${Platform.pathSeparator}$safe');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Total ukuran folder files (untuk halaman Pengaturan).
  static Future<int> filesSize() async {
    final dir = Directory('${baseDir.path}${Platform.pathSeparator}files');
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is File) {
        try {
          total += await e.length();
        } catch (_) {}
      }
    }
    return total;
  }
}
