import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart'; // extension get/find/put/delete pada StoreRef & RecordRef
import '../core/local_db.dart';
import '../core/models.dart';
import '../core/pbkdf2.dart';
import '../core/format.dart';
import '../core/smart_search.dart';
import 'api_client.dart';

enum NetStatus { notConfigured, checking, online, offline }

/// Akun bawaan sebelum aplikasi terhubung ke server.
const defaultAdminUser = 'administrator';
const defaultAdminPass = 'administrator';

/// Iterasi PBKDF2 untuk hash offline yang dibuat di PC ini sendiri.
const _localIterations = 20000;

/// Pusat logika aplikasi: pengaturan, login online/offline, cache akun &
/// proyek, arsip dokumen (NoSQL lokal), dan sinkronisasi otomatis.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  AppSettings settings = const AppSettings();
  List<CachedUser> users = [];
  List<Project> projects = [];

  /// Semua dokumen, key = clientId.
  final Map<String, DocRecord> _docs = {};

  /// Token isi file (dari server, atau dibaca lokal untuk TXT/CSV), key = clientId.
  final Map<String, String> tokens = {};

  /// Kamus pencarian.
  List<SearchTerm> terms = [];

  /// Jumlah permintaan edit yang menunggu (admin: semua, staf: miliknya).
  int pendingRequests = 0;

  String _indexSince = '';
  int _indexSinceId = 0;

  SmartSearch get searcher => SmartSearch(terms, tokens);
  Session? session;

  NetStatus net = NetStatus.notConfigured;
  bool syncing = false;
  DateTime? lastSyncAt;
  DateTime? lastPullAt;
  String? syncMessage;

  Timer? _timer;
  bool _tickRunning = false;
  DateTime? _lastUserSync;
  DateTime? _lastPull;

  ApiClient? get api => settings.hasApi ? ApiClient(settings.apiUrl, deviceKey: settings.deviceKey) : null;

  /// Status persetujuan PC ini dari server: pending | approved | rejected | revoked | '' (belum tahu).
  String deviceStatus = '';
  String deviceMessage = '';
  bool get deviceApproved => deviceStatus == 'approved';
  bool get setupMode => !settings.connected;
  bool get isOnline => net == NetStatus.online;
  bool get canUseServer => isOnline && !setupMode && session != null && !session!.isSetupAdmin;
  String get agencyName => settings.agencyName.isEmpty ? 'Dinas Pekerjaan Umum' : settings.agencyName;

  Iterable<DocRecord> get allDocs => _docs.values;

  /// Semua dokumen terurut terbaru. Arsip bersifat bersama (semua user bisa
  /// melihat), kecuali dokumen yang BELUM terupload: hanya pembuatnya & admin.
  List<DocRecord> get visibleDocs {
    final s = session;
    if (s == null) return const [];
    final me = s.username.toLowerCase();
    final list = _docs.values.where((d) => !d.isUnsynced || s.isAdmin || d.createdBy.toLowerCase() == me).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int get pendingCount => visibleDocs.where((d) => d.status == DocStatus.pending || d.status == DocStatus.uploading).length;
  int get failedCount => visibleDocs.where((d) => d.status == DocStatus.failed).length;

  /// Draf milik user yang sedang login (diperiksa dulu sebelum dikirim).
  List<DocRecord> get myDrafts => visibleDocs
      .where((d) => d.status == DocStatus.draft && d.createdBy.toLowerCase() == (session?.username ?? '').toLowerCase())
      .toList();
  int get draftCount => myDrafts.length;

  /// Dokumen milik user ini yang belum terupload (menunggu + gagal) — badge "Dokumen Saya".
  int get myUnsyncedCount {
    final me = session?.username.toLowerCase();
    if (me == null) return 0;
    return _docs.values.where((d) => d.isUnsynced && d.createdBy.toLowerCase() == me).length;
  }

  Project? projectById(String id) => projects.where((p) => p.id == id).firstOrNull;

  /// Semua nama seri yang sudah dipakai (untuk isian otomatis), urut abjad.
  List<String> get allSeries {
    final set = <String>{};
    for (final d in _docs.values) {
      if (d.series.trim().isNotEmpty) set.add(d.series.trim());
    }
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  // ------------------------------------------------------------------ load

  Future<void> load() async {
    await LocalDb.open();
    final db = LocalDb.db;
    final cfg = await LocalDb.settings.record('app').get(db);
    settings = cfg == null ? const AppSettings() : AppSettings.fromJson(cfg);
    users = (await LocalDb.users.find(db)).map((r) => CachedUser.fromJson(r.value)).toList();
    projects = (await LocalDb.projects.find(db)).map((r) => Project.fromJson(r.value)).toList()
      ..sort((a, b) => b.year != a.year ? b.year.compareTo(a.year) : a.code.compareTo(b.code));
    tokens.clear();
    for (final r in await LocalDb.tokens.find(db)) {
      tokens[r.key] = (r.value['t'] ?? '').toString();
    }
    terms = (await LocalDb.terms.find(db)).map((r) => SearchTerm.fromJson(r.value)).toList();
    final cur = await LocalDb.settings.record('index_cursor').get(db);
    _indexSince = (cur?['since'] ?? '').toString();
    _indexSinceId = (cur?['since_id'] as num?)?.toInt() ?? 0;
    _docs.clear();
    for (final r in await LocalDb.documents.find(db)) {
      try {
        final d = DocRecord.fromJson(r.value);
        _docs[d.clientId] = d;
      } catch (_) {}
    }
    net = settings.hasApi ? NetStatus.checking : NetStatus.notConfigured;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => tick());
    unawaited(tick());
  }

  Future<void> _saveSettings() => LocalDb.settings.record('app').put(LocalDb.db, settings.toJson());

  Future<void> _saveUsers() async {
    final db = LocalDb.db;
    await db.transaction((txn) async {
      await LocalDb.users.delete(txn);
      for (final u in users) {
        await LocalDb.users.record(u.username.toLowerCase()).put(txn, u.toJson());
      }
    });
  }

  Future<void> _saveProjects() async {
    final db = LocalDb.db;
    await db.transaction((txn) async {
      await LocalDb.projects.delete(txn);
      for (final p in projects) {
        await LocalDb.projects.record(p.id).put(txn, p.toJson());
      }
    });
  }

  Future<void> _saveDoc(DocRecord d) => LocalDb.documents.record(d.clientId).put(LocalDb.db, d.toJson());
  Future<void> _deleteDocRecord(String clientId) => LocalDb.documents.record(clientId).delete(LocalDb.db);

  // ----------------------------------------------------------------- login

  /// null = berhasil, selain itu pesan error untuk ditampilkan.
  Future<String?> login(String username, String password) async {
    username = username.trim();
    if (username.isEmpty || password.isEmpty) return 'Isi username dan password.';

    if (setupMode) {
      if (username.toLowerCase() == defaultAdminUser && password == defaultAdminPass) {
        session = Session(
          username: defaultAdminUser,
          fullName: 'Administrator (sementara)',
          role: 'admin',
          password: password,
          isSetupAdmin: true,
        );
        notifyListeners();
        return null;
      }
      return 'Aplikasi belum terhubung ke server.\nGunakan akun default administrator / administrator, '
          'lalu hubungkan ke API di menu "Server API".';
    }

    final client = api!;
    try {
      final r = await client.login(username, password);
      session = Session(username: r.username, fullName: r.fullName, role: r.role, password: password, token: r.token);
      net = NetStatus.online;
      syncMessage = null;
      await _rememberLocally(r.username, r.fullName, r.role, password);
      notifyListeners();
      unawaited(_afterOnlineLogin());
      return null;
    } on ApiAuthException {
      if (username.toLowerCase() == defaultAdminUser) {
        return 'Akun administrator / administrator hanya untuk mode awal (sebelum terhubung ke server).\n'
            'Aplikasi sudah terhubung ke server, jadi masuk dengan akun admin dari server.\n'
            'Admin bawaan server: admin / Admin@12345 (lupa password: di folder server jalankan '
            'python reset_admin.py).';
      }
      return 'Username atau password salah.';
    } on ApiException catch (e) {
      return e.message; // mis. akun dinonaktifkan (403)
    } on ApiOfflineException {
      net = NetStatus.offline;
      notifyListeners();
      return _offlineLogin(username, password);
    }
  }

  Future<void> _afterOnlineLogin() async {
    // PC lama (terhubung sebelum ada fitur kunci PC) ikut didaftarkan.
    final t = session?.token;
    if (t != null) await _ensureDeviceKey(t);
    await refreshDeviceStatus();
    await _syncUsers(force: true);
    await pullFromServer(force: true);
    await tick();
  }

  Future<String?> _offlineLogin(String username, String password) async {
    final u = users.where((e) => e.username.toLowerCase() == username.toLowerCase()).firstOrNull;
    if (u == null || u.hash.isEmpty) {
      return 'Server tidak bisa dihubungi dan akun ini belum tersimpan di PC ini.\n'
          'Login offline hanya untuk akun yang sudah pernah disinkronkan saat online.';
    }
    if (!u.active) return 'Akun ini dinonaktifkan oleh admin.';
    final h = await pbkdf2Async(password, u.salt, u.iterations);
    if (!constantTimeEquals(h, u.hash.toLowerCase())) return 'Username atau password salah (mode offline).';
    session = Session(username: u.username, fullName: u.fullName, role: u.role, password: password, offline: true);
    syncMessage = null;
    notifyListeners();
    return null;
  }

  /// Setelah login online berhasil, simpan hash milik PC ini juga — jadi
  /// tetap bisa login offline walau server belum mengirim hash offline.
  Future<void> _rememberLocally(String username, String fullName, String role, String password) async {
    final existing = users.where((e) => e.username.toLowerCase() == username.toLowerCase()).firstOrNull;
    if (existing != null && existing.hash.isNotEmpty) {
      final h = await pbkdf2Async(password, existing.salt, existing.iterations);
      if (constantTimeEquals(h, existing.hash.toLowerCase())) return;
    }
    final salt = randomHex(16);
    final hash = await pbkdf2Async(password, salt, _localIterations);
    users.removeWhere((e) => e.username.toLowerCase() == username.toLowerCase());
    users.add(CachedUser(username: username, fullName: fullName, role: role, active: true, salt: salt, hash: hash, iterations: _localIterations));
    await _saveUsers();
  }

  void logout() {
    session = null;
    syncMessage = null;
    notifyListeners();
  }

  // ------------------------------------------------------------ connect API

  /// Uji alamat. Kalau user lupa menulis "/api", dicoba otomatis.
  Future<(String, Map<String, dynamic>)> probe(String rawUrl) async {
    final url = ApiClient.normalizeUrl(rawUrl);
    if (url.isEmpty) throw ApiException(0, 'Alamat API masih kosong.');
    try {
      return (url, await ApiClient(url).health());
    } catch (_) {
      if (!url.toLowerCase().endsWith('/api')) {
        try {
          final alt = '$url/api';
          return (alt, await ApiClient(alt).health());
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Hubungkan ke server memakai akun ADMIN yang ada di server. null = berhasil.
  Future<String?> connectServer(String rawUrl, String adminUser, String adminPass) async {
    try {
      final (url, info) = await probe(rawUrl);
      final client = ApiClient(url);
      final r = await client.login(adminUser.trim(), adminPass);
      if (r.role != 'admin') return 'Akun "${r.username}" bukan admin di server.';
      settings = AppSettings(
        apiUrl: url,
        connected: true,
        serverName: (info['server'] ?? '').toString(),
        agencyName: (info['agency'] ?? '').toString(),
      );
      await _saveSettings();
      session = Session(username: r.username, fullName: r.fullName, role: r.role, password: adminPass, token: r.token);
      net = NetStatus.online;
      syncMessage = null;
      await _rememberLocally(r.username, r.fullName, r.role, adminPass);
      await _ensureDeviceKey(r.token);
      notifyListeners();
      unawaited(_afterOnlineLogin());
      return null;
    } on ApiAuthException {
      return 'Username/password admin server salah.';
    } catch (e) {
      return e.toString();
    }
  }

  /// Putuskan dari server: akun default administrator aktif lagi, cache akun
  /// & proyek dihapus. Dokumen yang BELUM terupload tetap disimpan.
  Future<void> disconnectServer() async {
    settings = const AppSettings();
    users = [];
    projects = [];
    await _saveSettings();
    await _saveUsers();
    await _saveProjects();
    tokens.clear();
    terms = [];
    pendingRequests = 0;
    _indexSince = '';
    _indexSinceId = 0;
    await LocalDb.tokens.delete(LocalDb.db);
    await LocalDb.terms.delete(LocalDb.db);
    await LocalDb.settings.record('index_cursor').delete(LocalDb.db);
    // buang cache dokumen server yang tidak punya file lokal
    final remove = _docs.values.where((d) => !d.isUnsynced && d.localPath.isEmpty).map((d) => d.clientId).toList();
    for (final id in remove) {
      _docs.remove(id);
      await _deleteDocRecord(id);
    }
    net = NetStatus.notConfigured;
    session = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------ sync

  /// Pastikan sesi punya token (login ulang otomatis memakai password di
  /// memori). Mengembalikan token atau null kalau tidak bisa.
  Future<String?> ensureToken() async {
    final s = session;
    final client = api;
    if (s == null || client == null || s.isSetupAdmin || setupMode) return null;
    if (s.token != null) return s.token;
    try {
      final r = await client.login(s.username, s.password);
      s.token = r.token;
      s.offline = false;
      if (syncMessage != null) {
        syncMessage = null;
        notifyListeners();
      }
      return r.token;
    } on ApiAuthException {
      syncMessage = 'Password akun ini sudah diubah di server. Dokumen tetap tersimpan — silakan logout lalu login lagi untuk melanjutkan upload.';
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      syncMessage = e.message;
      notifyListeners();
      return null;
    } on ApiOfflineException {
      return null;
    }
  }

  /// Token wajib ada — untuk aksi admin (kelola staf/proyek). Melempar pesan
  /// yang jelas kalau sedang offline.
  Future<String> requireToken() async {
    if (setupMode) throw ApiException(0, 'Hubungkan aplikasi ke server dulu di menu Server API.');
    if (!isOnline) throw ApiOfflineException('Server sedang offline. Fitur ini butuh koneksi ke server.');
    final t = await ensureToken();
    if (t == null) throw ApiOfflineException('Tidak bisa mendapatkan sesi dari server.');
    return t;
  }

  /// Jalankan aksi server; kalau token kedaluwarsa, minta token baru sekali.
  Future<T> withToken<T>(Future<T> Function(ApiClient api, String token) action) async {
    var token = await requireToken();
    try {
      return await action(api!, token);
    } on ApiAuthException {
      session?.token = null;
      token = await requireToken();
      return action(api!, token);
    }
  }

  /// Daftarkan PC ini ke server (sekali saja) untuk mendapat kunci PC.
  Future<void> _ensureDeviceKey(String token) async {
    if (settings.deviceKey.isNotEmpty || api == null) return;
    try {
      var name = 'PC';
      try {
        name = Platform.localHostname;
      } catch (_) {}
      final (id, key, status) = await api!.registerDevice(token, name, os: Platform.operatingSystem, appVersion: appVersion);
      settings = settings.copyWith(deviceKey: key, deviceId: id);
      deviceStatus = status;
      deviceMessage = status == 'approved' ? '' : 'PC ini menunggu persetujuan admin server.';
      await _saveSettings();
      notifyListeners();
    } catch (_) {
      // server lama tanpa endpoint /devices -> tetap jalan dengan sinkron saat login
    }
  }

  /// Salin daftar akun admin & staf dari server ke PC ini (tiap 5 menit).
  /// Pakai token login kalau ada; kalau belum ada yang login (layar login),
  /// pakai kunci PC — jadi akun baru dari admin langsung bisa login offline.
  Future<void> _syncUsers({bool force = false}) async {
    final last = _lastUserSync;
    if (!force && last != null && DateTime.now().difference(last) < const Duration(minutes: 5)) return;
    final hasSession = session != null && !session!.isSetupAdmin;
    final token = hasSession ? await ensureToken() : null;
    if (token == null && settings.deviceKey.isEmpty) return;
    try {
      final fresh = token != null ? await api!.offlineUsers(token) : await api!.deviceOfflineUsers(settings.deviceKey);
      // Server = sumber kebenaran: akun yang dihapus/nonaktif di server ikut
      // hilang/nonaktif di PC ini. Hash lokal dipakai kalau server tidak
      // mengirim hash offline untuk akun tersebut.
      final merged = <CachedUser>[];
      for (final f in fresh) {
        if (f.hash.isNotEmpty) {
          merged.add(f);
        } else {
          final local = users.where((e) => e.username.toLowerCase() == f.username.toLowerCase()).firstOrNull;
          merged.add(CachedUser(
            username: f.username,
            fullName: f.fullName,
            role: f.role,
            active: f.active,
            salt: local?.salt ?? '',
            hash: local?.hash ?? '',
            iterations: local?.iterations ?? _localIterations,
          ));
        }
      }
      users = merged;
      _lastUserSync = DateTime.now();
      await _saveUsers();
      settings = settings.copyWith(usersSyncedAt: DateTime.now().toIso8601String());
      await _saveSettings();
      notifyListeners();
    } on ApiAuthException {
      if (token != null) {
        session?.token = null;
      } else {
        // Kunci PC dicabut admin (mis. laptop hilang): hapus akun tersimpan di PC ini.
        users = [];
        await _saveUsers();
        settings = settings.copyWith(deviceKey: '', deviceId: 0, usersSyncedAt: '');
        await _saveSettings();
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Cek status persetujuan PC ini (ditampilkan di layar login).
  Future<void> refreshDeviceStatus() async {
    final client = api;
    if (client == null || settings.deviceKey.isEmpty) return;
    try {
      final j = await client.deviceMe();
      final st = (j['status'] ?? '').toString();
      final msg = (j['message'] ?? '').toString();
      if (st != deviceStatus || msg != deviceMessage) {
        deviceStatus = st;
        deviceMessage = msg;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Kirim dokumen ke email (butuh online; dikirim oleh server lewat SMTP
  /// yang diatur di aplikasi Admin Server).
  Future<List<String>> emailDocument(DocRecord d,
      {required List<String> to, List<String> cc = const [], String subject = '', String message = ''}) async {
    final id = d.serverId;
    if (id == null) throw Exception('Dokumen belum terupload ke server. Kirim email setelah dokumen tersimpan di server.');
    return withToken((a, t) => a.emailDocument(t, id, to: to, cc: cc, subject: subject, message: message));
  }

  /// Daftar PC terdaftar (halaman Server API, khusus admin).
  Future<List<Map<String, dynamic>>> listDevices() => withToken((a, t) => a.listDevices(t));
  Future<void> revokeDevice(int id) => withToken((a, t) => a.revokeDevice(t, id));
  int get thisDeviceId => settings.deviceId;
  DateTime? get usersSyncedAt => DateTime.tryParse(settings.usersSyncedAt);

  /// Ambil daftar proyek + metadata dokumen dari server ke database lokal,
  /// supaya arsip tetap bisa dicari/dilihat saat offline.
  Future<void> pullFromServer({bool force = false}) async {
    final last = _lastPull;
    if (!force && last != null && DateTime.now().difference(last) < const Duration(minutes: 2)) return;
    final token = await ensureToken();
    if (token == null) return;
    try {
      final client = api!;
      final freshProjects = await client.listProjects(token);
      projects = freshProjects..sort((a, b) => b.year != a.year ? b.year.compareTo(a.year) : a.code.compareTo(b.code));
      await _saveProjects();

      final serverDocs = await client.listDocuments(token);
      final seen = <String>{};
      for (final sd in serverDocs) {
        seen.add(sd.clientId);
        final local = _docs[sd.clientId];
        if (local != null) {
          // dokumen buatan PC ini / sudah di-cache: perbarui metadata, file lokal dipertahankan
          sd.localPath = local.localPath;
          sd.attempts = local.attempts;
          // file diganti di server (permintaan edit disetujui) -> buang salinan lama
          if (local.sha256.isNotEmpty && sd.sha256.isNotEmpty && local.sha256 != sd.sha256 && local.localPath.isNotEmpty) {
            _deleteLocalFiles(local);
            sd.localPath = '';
          }
        }
        _docs[sd.clientId] = sd;
        await _saveDoc(sd);
      }
      // dokumen yang sudah terupload tapi tidak ada lagi di server = dihapus admin
      final gone = _docs.values.where((d) => d.status == DocStatus.uploaded && !seen.contains(d.clientId)).toList();
      for (final d in gone) {
        _docs.remove(d.clientId);
        await _deleteDocRecord(d.clientId);
        _deleteLocalFiles(d);
        tokens.remove(d.clientId);
        await LocalDb.tokens.record(d.clientId).delete(LocalDb.db);
      }
      await _pullIndex(token);
      await _pullTerms(token);
      await refreshRequestCount();
      _lastPull = DateTime.now();
      lastPullAt = _lastPull;
      notifyListeners();
    } on ApiAuthException {
      session?.token = null;
    } catch (e) {
      debugPrint('pullFromServer: $e');
    }
  }

  /// Ambil token isi file yang baru di-index server (bertahap, pakai cursor).
  Future<void> _pullIndex(String token) async {
    var more = true;
    var guard = 0;
    while (more && guard++ < 50) {
      final (items, since, sinceId, hasMore) = await api!.searchIndex(token, _indexSince, _indexSinceId);
      await LocalDb.db.transaction((txn) async {
        for (final it in items) {
          final cid = (it['client_id'] ?? '').toString();
          final t = (it['tokens'] ?? '').toString();
          tokens[cid] = t;
          await LocalDb.tokens.record(cid).put(txn, {'t': t});
          final d = _docs[cid];
          if (d != null) d.contentStatus = (it['status'] ?? '').toString();
        }
      });
      _indexSince = since;
      _indexSinceId = sinceId;
      await LocalDb.settings.record('index_cursor').put(LocalDb.db, {'since': since, 'since_id': sinceId});
      more = hasMore;
    }
  }

  Future<void> _pullTerms(String token) async {
    try {
      terms = await api!.listTerms(token);
      await LocalDb.db.transaction((txn) async {
        await LocalDb.terms.delete(txn);
        for (final t in terms) {
          await LocalDb.terms.record(t.id).put(txn, t.toJson());
        }
      });
    } catch (_) {}
  }

  Future<void> refreshRequestCount() async {
    if (!canUseServer) return;
    try {
      final (n, _) = await withToken((a, t) => a.listEditRequests(t, status: 'pending'));
      if (n != pendingRequests) {
        pendingRequests = n;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Dipanggil tiap 10 detik + setelah simpan dokumen + tombol "Sinkronkan".
  Future<void> tick({bool forcePull = false}) async {
    if (_tickRunning) return;
    _tickRunning = true;
    try {
      final client = api;
      if (client == null) {
        net = NetStatus.notConfigured;
        notifyListeners();
        return;
      }
      final wasOffline = net != NetStatus.online;
      try {
        await client.health();
        net = NetStatus.online;
      } catch (_) {
        net = NetStatus.offline;
        notifyListeners();
        return;
      }
      notifyListeners();
      if (session == null || session!.isSetupAdmin) {
        // Di layar login pun daftar akun tetap diperbarui (pakai kunci PC).
        if (session == null && settings.connected) {
          await refreshDeviceStatus();
          await _syncUsers(force: wasOffline);
        }
        return;
      }
      await _syncUsers();
      await _uploadPending();
      await pullFromServer(force: forcePull || wasOffline);
    } finally {
      _tickRunning = false;
    }
  }

  Future<void> _uploadPending() async {
    final queue = _docs.values.where((d) => d.status == DocStatus.pending).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (queue.isEmpty) return;
    final token = await ensureToken();
    if (token == null) return;

    syncing = true;
    notifyListeners();
    try {
      for (final doc in queue) {
        if (!_docs.containsKey(doc.clientId)) continue; // dihapus user saat antri
        if (doc.localPath.isEmpty || !File(doc.localPath).existsSync()) {
          doc.status = DocStatus.failed;
          doc.lastError = 'File lokal hilang: ${doc.localPath}';
          await _saveDoc(doc);
          continue;
        }
        doc.status = DocStatus.uploading;
        doc.attempts++;
        notifyListeners();
        try {
          doc.serverId = await api!.uploadDocument(session?.token ?? token, doc);
          doc.status = DocStatus.uploaded;
          doc.uploadedAt = DateTime.now();
          doc.lastError = null;
        } on ApiAuthException {
          doc.status = DocStatus.pending;
          session?.token = null; // token kedaluwarsa -> minta baru di putaran berikutnya
          await _saveDoc(doc);
          break;
        } on ApiOfflineException catch (e) {
          doc.status = DocStatus.pending;
          doc.lastError = e.message;
          net = NetStatus.offline;
          await _saveDoc(doc);
          break;
        } on ApiException catch (e) {
          doc.status = DocStatus.failed; // ditolak server (mis. terlalu besar) -> tidak diulang otomatis
          doc.lastError = e.message;
        } catch (e) {
          doc.status = DocStatus.failed;
          doc.lastError = e.toString();
        }
        if (_docs.containsKey(doc.clientId)) await _saveDoc(doc);
        notifyListeners();
      }
      lastSyncAt = DateTime.now();
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------- documents

  /// Simpan dokumen: file disalin ke folder aplikasi dulu (aman saat offline),
  /// lalu langsung dicoba upload.
  Future<DocRecord> saveDocument({
    required String sourcePath,
    required String title,
    required String category,
    Project? project,
    String docNumber = '',
    String docDate = '',
    String description = '',
    String tags = '',
    String series = '',
    bool draft = false, // true = simpan sebagai draf, dikirim nanti setelah diperiksa
  }) async {
    final s = session!;
    final src = File(sourcePath);
    final size = await src.length();
    if (size > maxUploadBytes) {
      throw Exception('Ukuran ${baseName(sourcePath)} ${formatBytes(size)} melebihi batas ${formatBytes(maxUploadBytes)}.');
    }
    final clientId = '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${randomHex(6)}';
    final fileName = baseName(sourcePath);
    final dest = File('${LocalDb.filesDir(clientId).path}${Platform.pathSeparator}$fileName');
    await src.copy(dest.path);

    final rec = DocRecord(
      clientId: clientId,
      title: title.trim(),
      docNumber: docNumber.trim(),
      docDate: docDate,
      category: category,
      projectId: project?.id ?? '',
      projectCode: project?.code ?? '',
      projectName: project?.name ?? '',
      description: description.trim(),
      tags: tags.trim(),
      series: series.trim(),
      fileName: fileName,
      fileSize: size,
      localPath: dest.path,
      createdBy: s.username,
      createdByName: s.fullName,
      createdAt: DateTime.now(),
      status: draft ? DocStatus.draft : DocStatus.pending,
    );
    _docs[clientId] = rec;
    await _saveDoc(rec);
    // TXT/CSV bisa langsung dibaca di PC (PDF/Word/Excel dibaca server setelah terupload)
    if (isTextExt(rec.extension)) {
      try {
        final raw = await dest.openRead(0, 2 * 1024 * 1024).fold<List<int>>([], (a, b) => a..addAll(b));
        final words = RegExp(r'[0-9a-zA-Z\u00C0-\u024F./\-]+')
            .allMatches(utf8.decode(raw, allowMalformed: true).toLowerCase())
            .map((m) => m.group(0)!)
            .where((w) => w.length >= 2)
            .toSet();
        final t = words.join(' ');
        tokens[clientId] = t;
        await LocalDb.tokens.record(clientId).put(LocalDb.db, {'t': t});
      } catch (_) {}
    }
    notifyListeners();
    return rec;
  }

  /// Setelah satu batch disimpan, picu upload sekali.
  void kickUpload() => unawaited(tick());

  /// Draf yang sudah diperiksa -> masuk antrian kirim. Kalau server mati,
  /// tetap aman di PC dan terkirim otomatis begitu server bisa dihubungi.
  Future<void> submitDrafts(Iterable<DocRecord> docs) async {
    for (final d in docs.toList()) {
      if (d.status != DocStatus.draft) continue;
      d.status = DocStatus.pending;
      d.lastError = null;
      await _saveDoc(d);
    }
    notifyListeners();
    unawaited(tick());
  }

  /// Kembalikan dokumen yang masih mengantri (belum terkirim) menjadi draf.
  Future<void> holdAsDraft(DocRecord d) async {
    if (d.status != DocStatus.pending && d.status != DocStatus.failed) return;
    d.status = DocStatus.draft;
    await _saveDoc(d);
    notifyListeners();
  }

  /// Ganti file dokumen yang belum terkirim (draf / antrian / gagal).
  Future<void> replaceUnsentFile(DocRecord d, String sourcePath) async {
    if (!d.isUnsynced || d.status == DocStatus.uploading) {
      throw Exception('File hanya bisa diganti selama dokumen belum terkirim ke server.');
    }
    final src = File(sourcePath);
    final size = await src.length();
    if (size > maxUploadBytes) {
      throw Exception('Ukuran ${formatBytes(size)} melebihi batas ${formatBytes(maxUploadBytes)}.');
    }
    final fileName = baseName(sourcePath);
    final dest = File('${LocalDb.filesDir(d.clientId).path}${Platform.pathSeparator}$fileName');
    final old = d.localPath;
    await src.copy(dest.path);
    if (old.isNotEmpty && old != dest.path) {
      try {
        File(old).deleteSync();
      } catch (_) {}
    }
    d.localPath = dest.path;
    d.fileName = fileName;
    d.fileSize = size;
    await _saveDoc(d);
    notifyListeners();
  }

  Future<void> retryDoc(DocRecord d) async {
    d.status = DocStatus.pending;
    d.lastError = null;
    await _saveDoc(d);
    notifyListeners();
    unawaited(tick());
  }

  Future<void> retryAllFailed() async {
    for (final d in visibleDocs.where((d) => d.status == DocStatus.failed)) {
      d.status = DocStatus.pending;
      d.lastError = null;
      await _saveDoc(d);
    }
    notifyListeners();
    unawaited(tick());
  }

  /// Ubah metadata. Belum terupload -> cukup lokal; sudah di server -> PATCH.
  Future<void> updateDocMeta(DocRecord d, Map<String, String> changes) async {
    if (!d.isUnsynced && d.serverId != null) {
      await withToken((a, t) => a.updateDocument(t, d.serverId!, changes));
    }
    d.title = changes['title'] ?? d.title;
    d.docNumber = changes['doc_number'] ?? d.docNumber;
    d.docDate = changes['doc_date'] ?? d.docDate;
    d.category = changes['category'] ?? d.category;
    d.description = changes['description'] ?? d.description;
    d.tags = changes['tags'] ?? d.tags;
    d.series = changes['series'] ?? d.series;
    if (changes.containsKey('project_id')) {
      final p = projectById(changes['project_id']!);
      d.projectId = p?.id ?? '';
      d.projectCode = p?.code ?? '';
      d.projectName = p?.name ?? '';
    }
    await _saveDoc(d);
    notifyListeners();
  }

  /// Pastikan file ada di PC ini (unduh dari server bila perlu). Mengembalikan path.
  Future<String> ensureLocalFile(DocRecord d) async {
    if (d.localPath.isNotEmpty && await File(d.localPath).exists()) return d.localPath;
    if (d.serverId == null) throw Exception('File tidak ditemukan di PC ini.');
    final target = File('${LocalDb.filesDir(d.clientId).path}${Platform.pathSeparator}${d.fileName}');
    await withToken((a, t) => a.downloadDocument(t, d.serverId!, target));
    d.localPath = target.path;
    await _saveDoc(d);
    notifyListeners();
    return target.path;
  }

  /// Hapus dokumen. Sudah di server -> hapus di server (admin). Belum -> hapus antrian.
  Future<void> deleteDoc(DocRecord d) async {
    if (!d.isUnsynced && d.serverId != null) {
      await withToken((a, t) => a.deleteDocument(t, d.serverId!));
    }
    _docs.remove(d.clientId);
    await _deleteDocRecord(d.clientId);
    _deleteLocalFiles(d);
    tokens.remove(d.clientId);
    await LocalDb.tokens.record(d.clientId).delete(LocalDb.db);
    notifyListeners();
  }

  /// Hapus file cache unduhan untuk dokumen yang sudah aman di server.
  Future<int> clearDownloadedCache() async {
    var n = 0;
    for (final d in _docs.values.where((d) => d.status == DocStatus.uploaded && d.localPath.isNotEmpty).toList()) {
      _deleteLocalFiles(d);
      d.localPath = '';
      await _saveDoc(d);
      n++;
    }
    notifyListeners();
    return n;
  }

  void _deleteLocalFiles(DocRecord d) {
    try {
      if (d.localPath.isEmpty) return;
      final dir = File(d.localPath).parent;
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}
  }

  /// Ganti password sendiri (butuh online). Cache login offline ikut diperbarui.
  Future<void> changeOwnPassword(String oldPassword, String newPassword) async {
    final s = session!;
    if (oldPassword != s.password) throw ApiException(0, 'Password lama salah.');
    await withToken((a, t) => a.changePassword(t, oldPassword, newPassword));
    s.updatePassword(newPassword);
    await _rememberLocally(s.username, s.fullName, s.role, newPassword);
    await _syncUsers(force: true);
    notifyListeners();
  }

  // ------------------------------------------------------- permintaan edit

  /// Staf mengajukan perubahan dokumen yang sudah diarsipkan (butuh online).
  Future<void> requestEdit(DocRecord d, {required String reason, required Map<String, String> changes, String? filePath}) async {
    if (d.serverId == null) throw ApiException(0, 'Dokumen belum terupload — edit langsung saja.');
    await withToken((a, t) => a.createEditRequest(t, d.serverId!, reason: reason, changes: changes, filePath: filePath));
    await refreshRequestCount();
  }

  Future<List<EditRequest>> listRequests(String status) async {
    final (n, items) = await withToken((a, t) => a.listEditRequests(t, status: status));
    if (status == 'pending' && n != pendingRequests) {
      pendingRequests = n;
      notifyListeners();
    }
    return items;
  }

  Future<void> reviewRequest(EditRequest r, {required bool approve, String note = ''}) async {
    await withToken((a, t) => a.reviewEditRequest(t, r.id, approve: approve, note: note));
    await refreshRequestCount();
    if (approve) await pullFromServer(force: true);
  }

  Future<void> cancelRequest(EditRequest r) async {
    await withToken((a, t) => a.cancelEditRequest(t, r.id));
    await refreshRequestCount();
  }

  /// Unduh file (versi lama / file usulan) ke folder sementara. Mengembalikan path.
  Future<String> downloadTemp(String apiPath, String folder, String fileName) async {
    final target = File('${LocalDb.tempDir(folder).path}${Platform.pathSeparator}$fileName');
    await withToken((a, t) => a.downloadTo(t, apiPath, target));
    return target.path;
  }

  // ---------------------------------------------------------------- kamus

  Future<void> saveTerm(SearchTerm t) async {
    await withToken((a, tok) => a.saveTerm(tok, t));
    final tok = await requireToken();
    await _pullTerms(tok);
    notifyListeners();
  }

  Future<void> deleteTerm(SearchTerm t) async {
    await withToken((a, tok) => a.deleteTerm(tok, t.id));
    terms.removeWhere((e) => e.id == t.id);
    await LocalDb.terms.record(t.id).delete(LocalDb.db);
    notifyListeners();
  }

  // -------------------------------------------------------------- projects

  Future<void> saveProject(Project p) async {
    final saved = await withToken((a, t) => a.saveProject(t, p));
    projects.removeWhere((e) => e.id == saved.id);
    projects.add(saved);
    projects.sort((a, b) => b.year != a.year ? b.year.compareTo(a.year) : a.code.compareTo(b.code));
    await _saveProjects();
    notifyListeners();
  }

  Future<void> deleteProject(Project p) async {
    await withToken((a, t) => a.deleteProject(t, p.id));
    projects.removeWhere((e) => e.id == p.id);
    await _saveProjects();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
