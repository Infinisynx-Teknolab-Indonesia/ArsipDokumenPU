/// ===========================================================================
///  ALAMAT SERVER BAWAAN (HARDCODE)
///
///  Aplikasi langsung memakai alamat ini — PC baru tidak perlu mengetik alamat
///  server. Admin tetap bisa memilih "Server lain" di menu
///  Admin Server → Koneksi Server bila perlu.
///
///  Cara mengganti (pilih salah satu):
///   1. Ubah teks di bawah, lalu build ulang installer, ATAU
///   2. Tanpa mengubah kode, saat build:
///        flutter build windows --dart-define=ARSIP_SERVER=http://192.168.1.10:8000/api
///        flutter build macos   --dart-define=ARSIP_SERVER=http://192.168.1.10:8000/api
///
///  Kosongkan ('') bila tidak ingin memakai server bawaan sama sekali
///  (aplikasi kembali ke mode awal: login administrator/administrator lalu
///  isi alamat server secara manual).
/// ===========================================================================
const kDefaultServerUrl = String.fromEnvironment('ARSIP_SERVER', defaultValue: 'http://localhost:8000/api');

/// true bila ada alamat server bawaan.
bool get hasDefaultServer => kDefaultServerUrl.trim().isNotEmpty;
