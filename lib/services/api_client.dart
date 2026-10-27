import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/models.dart';

/// Server tidak bisa dihubungi (internet mati, server mati, timeout).
class ApiOfflineException implements Exception {
  final String message;
  ApiOfflineException(this.message);
  @override
  String toString() => message;
}

/// 401 — token kedaluwarsa atau username/password salah.
class ApiAuthException implements Exception {
  final String message;
  ApiAuthException(this.message);
  @override
  String toString() => message;
}

/// Server menjawab tapi menolak (4xx/5xx selain 401).
class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class LoginResult {
  final String token;
  final String username;
  final String fullName;
  final String role;
  LoginResult(this.token, this.username, this.fullName, this.role);
}

/// Klien REST. Kontrak lengkapnya ada di API.md — backend FastAPI maupun
/// C# .NET cukup mengikuti kontrak itu, aplikasi tidak perlu diubah.
class ApiClient {
  final String baseUrl;

  /// Kunci PC ini (dikirim di setiap permintaan sebagai X-Device-Key). Server
  /// memakainya untuk menolak login staf di PC yang belum disetujui admin.
  final String deviceKey;
  ApiClient(String url, {this.deviceKey = ''}) : baseUrl = normalizeUrl(url);

  static const _shortTimeout = Duration(seconds: 6);
  static const _uploadTimeout = Duration(minutes: 10);

  static String normalizeUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.isNotEmpty && !u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    return u;
  }

  Uri _u(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  Map<String, String> _headers(String? token, {bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (deviceKey.isNotEmpty) 'X-Device-Key': deviceKey,
      };

  Future<http.Response> _send(Future<http.Response> Function() call, {Duration? timeout}) async {
    try {
      return await call().timeout(timeout ?? _shortTimeout);
    } on TimeoutException {
      throw ApiOfflineException('Server tidak menjawab (timeout).');
    } on SocketException catch (e) {
      throw ApiOfflineException('Tidak bisa terhubung ke server: ${e.message}');
    } on http.ClientException catch (e) {
      throw ApiOfflineException('Koneksi gagal: ${e.message}');
    } on HandshakeException catch (e) {
      throw ApiOfflineException('Sertifikat HTTPS bermasalah: ${e.message}');
    }
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode == 401) {
      throw ApiAuthException(_detail(res) ?? 'Sesi berakhir atau password salah.');
    }
    if (res.statusCode >= 500) {
      // 5xx biasanya server sedang bermasalah -> perlakukan seperti offline
      // supaya data tetap diantrikan dan dicoba lagi nanti.
      throw ApiOfflineException('Server error ${res.statusCode}: ${_detail(res) ?? 'coba lagi nanti'}');
    }
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, _detail(res) ?? 'Permintaan ditolak (${res.statusCode}).');
    }
    if (res.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw ApiException(res.statusCode, 'Jawaban server bukan JSON. Pastikan alamat API benar (biasanya diakhiri /api).');
    }
  }

  String? _detail(http.Response res) {
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is Map) {
        final d = j['detail'] ?? j['message'] ?? j['title'] ?? j['error'];
        if (d is String) return d;
        if (d != null) return d.toString();
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------- health

  /// GET /health -> {"status":"ok","app":"arsip-dokumen-pu","server":"FastAPI","agency":"..."}
  Future<Map<String, dynamic>> health() async {
    final res = await _send(() => http.get(_u('/health'), headers: _headers(null)), timeout: const Duration(seconds: 4));
    final j = _decode(res);
    if (j is! Map || j['status'] != 'ok') {
      throw ApiException(res.statusCode, 'Alamat ini bukan server Arsip Dokumen.');
    }
    return Map<String, dynamic>.from(j);
  }

  // ------------------------------------------------------------------ auth

  Future<LoginResult> login(String username, String password) async {
    final res = await _send(() => http.post(
          _u('/auth/login'),
          headers: _headers(null),
          body: jsonEncode({'username': username, 'password': password}),
        ));
    final j = _decode(res) as Map;
    final user = Map<String, dynamic>.from(j['user'] as Map);
    return LoginResult(
      j['token'] as String,
      (user['username'] ?? username).toString(),
      (user['full_name'] ?? username).toString(),
      (user['role'] ?? 'staff').toString(),
    );
  }

  /// Ganti password akun sendiri.
  Future<void> changePassword(String token, String oldPassword, String newPassword) async {
    final res = await _send(() => http.post(
          _u('/auth/change-password'),
          headers: _headers(token),
          body: jsonEncode({'old_password': oldPassword, 'new_password': newPassword}),
        ));
    _decode(res);
  }

  /// Daftar akun aktif + hash offline, untuk login saat internet mati.
  Future<List<CachedUser>> offlineUsers(String token) async {
    final res = await _send(() => http.get(_u('/auth/offline-users'), headers: _headers(token)));
    final j = _decode(res) as Map;
    return (j['users'] as List).map((e) => CachedUser.fromJson(Map<String, Object?>.from(e as Map))).toList();
  }

  // ----------------------------------------------------------------- kunci PC

  /// Daftarkan PC ini ke server -> (id, kunci). Kunci hanya dikirim sekali.
  /// Daftarkan PC ini ke server -> (id, kunci, status). Kunci hanya dikirim sekali.
  Future<(int, String, String)> registerDevice(String token, String name, {String os = '', String appVersion = ''}) async {
    final res = await _send(() => http.post(_u('/devices'),
        headers: _headers(token), body: jsonEncode({'name': name, 'os': os, 'app_version': appVersion})));
    final j = _decode(res) as Map;
    return ((j['device_id'] as num).toInt(), j['device_key'].toString(), (j['status'] ?? 'approved').toString());
  }

  /// Status PC ini (pending / approved / rejected / revoked) — tanpa login.
  Future<Map<String, dynamic>> deviceMe() async {
    final res = await _send(() => http.get(_u('/devices/me'), headers: _headers(null)));
    return Map<String, dynamic>.from(_decode(res) as Map);
  }

  /// Kirim dokumen (file asli sebagai lampiran) ke email lewat server.
  Future<List<String>> emailDocument(String token, String docId,
      {required List<String> to, List<String> cc = const [], String subject = '', String message = ''}) async {
    final res = await _send(
      () => http.post(_u('/documents/$docId/email'),
          headers: _headers(token), body: jsonEncode({'to': to, 'cc': cc, 'subject': subject, 'message': message})),
      timeout: const Duration(seconds: 90),
    );
    final j = _decode(res) as Map;
    return ((j['sent_to'] as List?) ?? const []).map((e) => e.toString()).toList();
  }

  /// Daftar akun (hash offline) memakai kunci PC — tanpa login.
  Future<List<CachedUser>> deviceOfflineUsers(String deviceKey) async {
    final res = await _send(() => http.get(_u('/devices/offline-users'), headers: {..._headers(null), 'X-Device-Key': deviceKey}));
    final j = _decode(res) as Map;
    return (j['users'] as List).map((e) => CachedUser.fromJson(Map<String, Object?>.from(e as Map))).toList();
  }

  Future<List<Map<String, dynamic>>> listDevices(String token) async {
    final res = await _send(() => http.get(_u('/devices'), headers: _headers(token)));
    final j = _decode(res) as Map;
    return (j['devices'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> revokeDevice(String token, int id) async {
    final res = await _send(() => http.delete(_u('/devices/$id'), headers: _headers(token)));
    _decode(res);
  }

  // ----------------------------------------------------------------- users

  Future<List<ServerUser>> listUsers(String token) async {
    final res = await _send(() => http.get(_u('/users'), headers: _headers(token)));
    final j = _decode(res) as Map;
    return (j['users'] as List).map((e) => ServerUser.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> createUser(String token, Map<String, Object?> data) async {
    final res = await _send(() => http.post(_u('/users'), headers: _headers(token), body: jsonEncode(data)));
    _decode(res);
  }

  Future<void> updateUser(String token, String username, Map<String, dynamic> changes) async {
    final res = await _send(() => http.patch(
          _u('/users/${Uri.encodeComponent(username)}'),
          headers: _headers(token),
          body: jsonEncode(changes),
        ));
    _decode(res);
  }

  Future<void> deleteUser(String token, String username) async {
    final res = await _send(() => http.delete(_u('/users/${Uri.encodeComponent(username)}'), headers: _headers(token)));
    _decode(res);
  }

  // -------------------------------------------------------------- projects

  Future<List<Project>> listProjects(String token) async {
    final res = await _send(() => http.get(_u('/projects'), headers: _headers(token)));
    final j = _decode(res) as Map;
    return (j['items'] as List).map((e) => Project.fromJson(Map<String, Object?>.from(e as Map))).toList();
  }

  Future<Project> saveProject(String token, Project p) async {
    final body = jsonEncode(p.toJson()..remove('id'));
    final res = p.id.isEmpty
        ? await _send(() => http.post(_u('/projects'), headers: _headers(token), body: body))
        : await _send(() => http.put(_u('/projects/${Uri.encodeComponent(p.id)}'), headers: _headers(token), body: body));
    return Project.fromJson(Map<String, Object?>.from(_decode(res) as Map));
  }

  Future<void> deleteProject(String token, String id) async {
    final res = await _send(() => http.delete(_u('/projects/${Uri.encodeComponent(id)}'), headers: _headers(token)));
    _decode(res);
  }

  // ------------------------------------------------------------- documents

  /// POST /documents (multipart). client_id membuat upload aman diulang:
  /// kalau server sudah punya client_id itu, ia mengembalikan dokumen lama.
  Future<String> uploadDocument(String token, DocRecord doc) async {
    final req = http.MultipartRequest('POST', _u('/documents'))
      ..headers.addAll(_headers(token, json: false))
      ..fields.addAll({
        'client_id': doc.clientId,
        'title': doc.title,
        'doc_number': doc.docNumber,
        'doc_date': doc.docDate,
        'category': doc.category,
        'project_id': doc.projectId,
        'description': doc.description,
        'tags': doc.tags,
        'series': doc.series,
        'uploaded_by': doc.createdBy,
        'created_at': doc.createdAt.toUtc().toIso8601String(),
      })
      ..files.add(await http.MultipartFile.fromPath('file', doc.localPath, filename: doc.fileName));
    final res = await _send(() async => http.Response.fromStream(await req.send()), timeout: _uploadTimeout);
    final j = _decode(res) as Map;
    return j['id'].toString();
  }

  /// Semua metadata dokumen yang boleh dilihat user ini (admin: semua,
  /// staf: semua juga — arsip bersifat bersama; atur di server bila perlu).
  Future<List<DocRecord>> listDocuments(String token, {int limit = 5000}) async {
    final res = await _send(
      () => http.get(_u('/documents', {'limit': '$limit'}), headers: _headers(token)),
      timeout: const Duration(seconds: 30),
    );
    final j = _decode(res) as Map;
    return (j['items'] as List).map((e) => DocRecord.fromServer(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> updateDocument(String token, String id, Map<String, Object?> changes) async {
    final res = await _send(() => http.patch(
          _u('/documents/${Uri.encodeComponent(id)}'),
          headers: _headers(token),
          body: jsonEncode(changes),
        ));
    _decode(res);
  }

  Future<void> downloadDocument(String token, String id, File target) async {
    final res = await _send(
      () => http.get(_u('/documents/${Uri.encodeComponent(id)}/file'), headers: _headers(token, json: false)),
      timeout: _uploadTimeout,
    );
    if (res.statusCode != 200) _decode(res);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(res.bodyBytes, flush: true);
  }

  Future<void> deleteDocument(String token, String id) async {
    final res = await _send(() => http.delete(_u('/documents/${Uri.encodeComponent(id)}'), headers: _headers(token)));
    _decode(res);
  }

  // ----------------------------------------------------------------- audit

  Future<List<AuditEntry>> auditLog(String token, {int limit = 500, String query = ''}) async {
    final res = await _send(() => http.get(_u('/audit', {'limit': '$limit', 'q': query}), headers: _headers(token)));
    final j = _decode(res) as Map;
    return (j['items'] as List).map((e) => AuditEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  // ------------------------------------------------------- pencarian pintar

  /// Token isi file (bertahap). -> (items, nextSince, nextSinceId, more)
  Future<(List<Map<String, dynamic>>, String, int, bool)> searchIndex(String token, String since, int sinceId) async {
    final res = await _send(
      () => http.get(_u('/search-index', {'since': since, 'since_id': '$sinceId', 'limit': '1000'}), headers: _headers(token)),
      timeout: const Duration(seconds: 60),
    );
    final j = _decode(res) as Map;
    final items = (j['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return (items, (j['next_since'] ?? since).toString(), (j['next_since_id'] as num?)?.toInt() ?? sinceId, j['more'] == true);
  }

  Future<List<SearchTerm>> listTerms(String token) async {
    final res = await _send(() => http.get(_u('/search-terms'), headers: _headers(token)));
    final j = _decode(res) as Map;
    return (j['items'] as List).map((e) => SearchTerm.fromJson(Map<String, Object?>.from(e as Map))).toList();
  }

  Future<void> saveTerm(String token, SearchTerm t) async {
    final body = jsonEncode({'term': t.term, 'related': t.related, 'note': t.note});
    final res = t.id.isEmpty
        ? await _send(() => http.post(_u('/search-terms'), headers: _headers(token), body: body))
        : await _send(() => http.put(_u('/search-terms/${t.id}'), headers: _headers(token), body: body));
    _decode(res);
  }

  Future<void> deleteTerm(String token, String id) async {
    final res = await _send(() => http.delete(_u('/search-terms/$id'), headers: _headers(token)));
    _decode(res);
  }

  Future<int> reindexAll(String token) async {
    final res = await _send(() => http.post(_u('/admin/reindex'), headers: _headers(token)));
    final j = _decode(res) as Map;
    return (j['queued'] as num?)?.toInt() ?? 0;
  }

  // ------------------------------------------------------ permintaan edit

  Future<void> createEditRequest(String token, String docId, {required String reason, required Map<String, String> changes, String? filePath}) async {
    final req = http.MultipartRequest('POST', _u('/documents/${Uri.encodeComponent(docId)}/edit-requests'))
      ..headers.addAll(_headers(token, json: false))
      ..fields['reason'] = reason
      ..fields['changes'] = jsonEncode(changes);
    if (filePath != null) req.files.add(await http.MultipartFile.fromPath('file', filePath));
    final res = await _send(() async => http.Response.fromStream(await req.send()), timeout: _uploadTimeout);
    _decode(res);
  }

  /// -> (jumlah pending, daftar)
  Future<(int, List<EditRequest>)> listEditRequests(String token, {String status = 'all'}) async {
    final res = await _send(() => http.get(_u('/edit-requests', {'status': status}), headers: _headers(token)));
    final j = _decode(res) as Map;
    return (
      (j['pending'] as num?)?.toInt() ?? 0,
      (j['items'] as List).map((e) => EditRequest.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }

  Future<void> reviewEditRequest(String token, String id, {required bool approve, String note = ''}) async {
    final res = await _send(() => http.post(
          _u('/edit-requests/$id/${approve ? 'approve' : 'reject'}'),
          headers: _headers(token),
          body: jsonEncode({'note': note}),
        ));
    _decode(res);
  }

  Future<void> cancelEditRequest(String token, String id) async {
    final res = await _send(() => http.post(_u('/edit-requests/$id/cancel'), headers: _headers(token)));
    _decode(res);
  }

  Future<void> downloadTo(String token, String path, File target) async {
    final res = await _send(() => http.get(_u(path), headers: _headers(token, json: false)), timeout: _uploadTimeout);
    if (res.statusCode != 200) _decode(res);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(res.bodyBytes, flush: true);
  }

  Future<(int, List<DocVersion>)> listVersions(String token, String docId) async {
    final res = await _send(() => http.get(_u('/documents/${Uri.encodeComponent(docId)}/versions'), headers: _headers(token)));
    final j = _decode(res) as Map;
    return (
      (j['current_version'] as num?)?.toInt() ?? 1,
      (j['items'] as List).map((e) => DocVersion.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}
