import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256, hasil 32 byte dalam hex huruf kecil.
/// Salt dipakai sebagai teks UTF-8 (bukan didekode dari hex), sama dengan:
///   Python : hashlib.pbkdf2_hmac('sha256', pw.encode(), salt.encode(), iter, 32).hex()
///   C#     : Convert.ToHexString(Rfc2898DeriveBytes.Pbkdf2(
///              Encoding.UTF8.GetBytes(pw), Encoding.UTF8.GetBytes(salt),
///              iter, HashAlgorithmName.SHA256, 32)).ToLowerInvariant()
String pbkdf2Sha256Hex(String password, String salt, int iterations, {int length = 32}) {
  final hmac = Hmac(sha256, utf8.encode(password));
  final saltBytes = utf8.encode(salt);
  final out = <int>[];
  var block = 1;
  while (out.length < length) {
    final first = <int>[
      ...saltBytes,
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ];
    var u = hmac.convert(first).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.addAll(t);
    block++;
  }
  return out.take(length).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Versi async di isolate terpisah supaya UI tidak macet saat menghitung.
Future<String> pbkdf2Async(String password, String salt, int iterations) =>
    Isolate.run(() => pbkdf2Sha256Hex(password, salt, iterations));

/// Perbandingan waktu-konstan.
bool constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

String randomHex(int bytes) {
  final r = Random.secure();
  return List.generate(bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
