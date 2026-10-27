// Tes sederhana logika non-UI (jalankan: flutter test).
import 'package:flutter_test/flutter_test.dart';
import 'package:arsip_dokumen/core/format.dart';
import 'package:arsip_dokumen/core/pbkdf2.dart';

void main() {
  test('format rupiah', () {
    expect(formatRupiah(4850000000), 'Rp 4.850.000.000');
  });

  test('PBKDF2 sama dengan Python hashlib', () {
    // python: hashlib.pbkdf2_hmac('sha256', b'Rahasia#1', b'a1b2c3', 2000, 32).hex()
    expect(pbkdf2Sha256Hex('Rahasia#1', 'a1b2c3', 2000), 'c227f356cd95e0da91e154e0189155783e2d96ab22746438d83a1b111ad84f59');
  });
}
