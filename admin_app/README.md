# Arsip PU — Admin Server (aplikasi admin, Windows & macOS)

Aplikasi **khusus admin** untuk mengendalikan server Arsip Dokumen PU. Dipasang di PC admin atau PC server, terpisah dari aplikasi Arsip Dokumen yang dipakai staf.

| Menu | Isi |
|---|---|
| **Dashboard** | Jumlah PC menunggu persetujuan, PC disetujui, member, dokumen, proyek, permintaan edit, dan status email/keamanan |
| **Perangkat (PC)** | Semua PC yang dihubungkan ke server: **Setujui / Tolak / Cabut**, ganti nama, siapa yang menghubungkan, login terakhir, IP, OS, versi aplikasi. Diperbarui otomatis tiap 15 detik, dengan badge merah untuk PC yang menunggu |
| **Member** | Tambah, ubah, reset password, aktif/nonaktif, dan hapus staf/admin (NIP, jabatan), plus daftar PC yang dipakai tiap member |
| **Email (SMTP)** | Server email untuk tombol **Kirim Email** di aplikasi: host, port, keamanan, akun, pengirim, catatan kaki, batas lampiran. Ada contoh pengaturan Gmail, Outlook, dan Yahoo, serta tombol **Kirim tes** |
| **Keamanan** | Saklar **PC baru wajib disetujui admin** (bawaan: aktif) |
| **Log Aktivitas** | Login, login gagal, PC, email, dokumen, member, dan perubahan pengaturan, dengan filter cepat |

## Alur persetujuan PC
1. Pasang aplikasi Arsip Dokumen di PC staf.
2. Di PC itu: login `administrator / administrator` → **Server API** → isi alamat server dan akun admin → **Simpan & Hubungkan**.
3. PC muncul di **Perangkat (PC)** dengan status **MENUNGGU**. Staf belum bisa login, dan layar login menampilkan *"PC ini menunggu persetujuan admin"*. Akun admin tetap bisa login.
4. Klik **Setujui**. Dalam sekitar 10 detik staf bisa login, dan daftar akun tersalin ke PC itu untuk login offline.
5. Laptop hilang atau pegawai pindah: klik **Cabut**. Akun yang tersimpan di laptop itu terhapus otomatis begitu terhubung ke server.

PC yang sudah terhubung sebelum fitur ini ada otomatis dianggap **disetujui**.

## Build installer
Paling mudah lewat GitHub Actions: workflow **Build Installer Windows & macOS** di repo yang sama juga membuat
`ArsipAdminServer_Setup_<versi>.exe` dan `ArsipAdminServer_<versi>_macOS.dmg`.

Manual (dari folder `admin_app`):
```
flutter create --platforms=windows,macos --project-name arsip_admin_server --org id.go.pu .
flutter pub get
flutter build windows --release      # lalu compile installer/windows/setup.iss di Inno Setup
flutter build macos --release        # lalu buat DMG (lihat workflow, job admin-macos)
```
Di Windows, salin `installer\app_icon.ico` ke `windows\runner\resources\app_icon.ico` sebelum build supaya ikonnya ikut berganti.

## Struktur file
```
admin_app/
├── lib/
│   ├── main.dart              titik awal: login ↔ halaman utama
│   ├── api.dart               semua panggilan ke server (endpoint di ../API.md)
│   ├── config_store.dart      menyimpan alamat server & username terakhir (bukan password)
│   ├── ui.dart                warna, panel, tombol, label status, format tanggal
│   └── screens/
│       ├── login.dart         alamat server + login admin (+ tombol Tes)
│       ├── shell.dart         sidebar, badge PC menunggu (cek tiap 15 detik), sesi habis → login
│       ├── common.dart        runApi(): tampilkan error, sesi habis → kembali ke login
│       ├── dashboard.dart     ringkasan
│       ├── devices.dart       Perangkat (PC): setujui/tolak/cabut/ganti nama
│       ├── members.dart       Member: tambah/ubah/reset password/aktif-nonaktif/hapus
│       ├── email_settings.dart Email (SMTP) + kirim tes
│       ├── security.dart      saklar persetujuan PC + cara kerja
│       └── audit.dart         log aktivitas
├── installer/
│   ├── app_icon.ico           ikon Windows (dibuat oleh make_icons.py)
│   ├── make_icons.py          pembuat ikon Windows & macOS
│   ├── windows/setup.iss      installer Inno Setup
│   └── macos/                 ikon, izin (entitlements), nama aplikasi
└── pubspec.yaml               hanya butuh library `http`
```
