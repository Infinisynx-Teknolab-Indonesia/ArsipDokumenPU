import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Error dari server (pesan sudah dalam Bahasa Indonesia).
class AdminApiException implements Exception {
  final int status;
  final String message;
  AdminApiException(this.status, this.message);
  bool get unauthorized => status == 401;
  @override
  String toString() => message;
}

/// Klien REST untuk aplikasi Admin Server. Semua endpoint ada di API.md
/// (bagian "Admin Server", "Kunci PC", "Users").
class AdminApi {
  final String baseUrl;
  String? token;
  AdminApi(String url) : baseUrl = normalize(url);

  static String normalize(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.isNotEmpty && !u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    if (u.isNotEmpty && !u.endsWith('/api')) u = '$u/api';
    return u;
  }

  Map<String, String> get _h => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _req(String method, String path, {Object? body, Map<String, String>? query}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    http.Response res;
    try {
      final b = body == null ? null : jsonEncode(body);
      final Future<http.Response> call;
      switch (method) {
        case 'GET':
          call = http.get(uri, headers: _h);
        case 'POST':
          call = http.post(uri, headers: _h, body: b);
        case 'PUT':
          call = http.put(uri, headers: _h, body: b);
        case 'PATCH':
          call = http.patch(uri, headers: _h, body: b);
        default:
          call = http.delete(uri, headers: _h);
      }
      res = await call.timeout(const Duration(seconds: 40));
    } on TimeoutException {
      throw AdminApiException(0, 'Server tidak menjawab (timeout). Pastikan server menyala.');
    } on SocketException catch (e) {
      throw AdminApiException(0, 'Tidak bisa terhubung ke server: ${e.message}');
    } on http.ClientException catch (e) {
      throw AdminApiException(0, 'Koneksi gagal: ${e.message}');
    }
    dynamic data;
    if (res.bodyBytes.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        if (res.statusCode < 400) throw AdminApiException(res.statusCode, 'Jawaban server bukan JSON. Alamat API benar?');
      }
    }
    if (res.statusCode >= 400) {
      var msg = 'Permintaan ditolak (${res.statusCode}).';
      if (data is Map && data['detail'] != null) {
        final d = data['detail'];
        msg = d is String ? d : (d is List && d.isNotEmpty && d.first is Map ? '${(d.first as Map)['msg']}' : d.toString());
      }
      throw AdminApiException(res.statusCode, msg);
    }
    return data;
  }

  // ---- auth
  Future<Map<String, dynamic>> health() async => Map<String, dynamic>.from(await _req('GET', '/health') as Map);

  Future<Map<String, dynamic>> login(String username, String password) async {
    final j = Map<String, dynamic>.from(await _req('POST', '/auth/login', body: {'username': username, 'password': password}) as Map);
    final user = Map<String, dynamic>.from(j['user'] as Map);
    if (user['role'] != 'admin') throw AdminApiException(403, 'Akun "${user['username']}" bukan admin. Aplikasi ini khusus admin server.');
    token = j['token'] as String;
    return user;
  }

  // ---- dashboard
  Future<Map<String, dynamic>> overview() async => Map<String, dynamic>.from(await _req('GET', '/admin/overview') as Map);

  // ---- perangkat (PC)
  Future<List<Map<String, dynamic>>> devices() async {
    final j = await _req('GET', '/devices') as Map;
    return (j['devices'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> approveDevice(int id) => _req('POST', '/devices/$id/approve');
  Future<void> rejectDevice(int id) => _req('POST', '/devices/$id/reject');
  Future<void> revokeDevice(int id) => _req('DELETE', '/devices/$id');
  Future<void> renameDevice(int id, String name) => _req('PATCH', '/devices/$id', body: {'name': name});

  // ---- member
  Future<List<Map<String, dynamic>>> users() async {
    final j = await _req('GET', '/users') as Map;
    return (j['users'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> createUser(Map<String, Object?> data) => _req('POST', '/users', body: data);
  Future<void> updateUser(String username, Map<String, Object?> data) => _req('PATCH', '/users/${Uri.encodeComponent(username)}', body: data);
  Future<void> deleteUser(String username) => _req('DELETE', '/users/${Uri.encodeComponent(username)}');

  // ---- pengaturan
  Future<Map<String, dynamic>> settings() async => Map<String, dynamic>.from(await _req('GET', '/admin/settings') as Map);
  Future<Map<String, dynamic>> saveSettings(Map<String, Object?> data) async =>
      Map<String, dynamic>.from(await _req('PUT', '/admin/settings', body: data) as Map);
  Future<void> testEmail(String to) => _req('POST', '/admin/email/test', body: {'to': to});

  // ---- log
  Future<List<Map<String, dynamic>>> audit({String q = '', int limit = 500}) async {
    final j = await _req('GET', '/audit', query: {'q': q, 'limit': '$limit'}) as Map;
    return (j['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
