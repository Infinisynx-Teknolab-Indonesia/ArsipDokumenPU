# Arsip Dokumen PU — Aplikasi Desktop (Windows & macOS)

Aplikasi arsip dokumen proyek Pekerjaan Umum (jalan, jembatan, gedung, irigasi, drainase).
Berjalan layar penuh dengan tampilan gaya Batam ChitChat. Bisa dipakai offline dan mengunggah otomatis saat internet kembali.

Repo ini berisi tiga bagian:
- **Aplikasi Arsip Dokumen** (folder utama), untuk staf & admin, beserta pembuat installer Windows/macOS.
- **Server API** FastAPI + MySQL, di folder [`server/`](server/README.md).
- **Aplikasi Admin Server**, untuk persetujuan PC, member, email SMTP, keamanan, dan log, di folder [`admin_app/`](admin_app/README.md).

**Unduh installer jadi:** tab **Actions** → run terbaru *Build Installer Windows & macOS* → bagian **Artifacts**, atau halaman **Releases** untuk versi bertag.

> 📁 Daftar lengkap semua file, fungsinya, dan file mana yang diubah untuk mengganti sesuatu ada di **[STRUKTUR_FILE.md](STRUKTUR_FILE.md)**.

```
ArsipDokumenPU_Desktop/
├── lib/                       source aplikasi Flutter
├── installer/
│   ├── app_icon.ico           ikon aplikasi
│   ├── windows/
│   │   ├── setup.iss          skrip installer Windows (Inno Setup)
│   │   └── vc_redist.x64.exe  Microsoft Visual C++ Runtime (ikut dibundel)
│   └── macos/                 bahan aplikasi macOS: ikon, izin, pengaturan jendela & Dock
├── .github/workflows/         build installer Windows (.exe) + macOS (.dmg) otomatis di GitHub
├── API.md                     kontrak API (acuan backend FastAPI / C# .NET)
└── STRUKTUR_FILE.md           peta semua file + fungsinya
```

## A. Membuat installer (sekali, di satu PC developer)

### Cara 1 — di PC sendiri
Kebutuhan (sekali saja):
- **Flutter SDK** (stable) dan **Visual Studio 2022** dengan workload *Desktop development with C++*
- **Inno Setup 6.3+**: https://jrsoftware.org/isdl.php
- **Developer Mode Windows aktif** (Settings → System → For developers → Developer Mode = On). Wajib untuk build plugin Flutter, termasuk penampil PDF. Biasanya sudah aktif kalau Anda pernah build aplikasi Flutter Windows. Saat build pertama, mesin PDF (PDFium) diunduh otomatis dari GitHub, jadi perlu internet.

Langkah (PowerShell, dari dalam folder `ArsipDokumenPU_Desktop`):

**1. Buat folder platform Windows** (hanya pertama kali, kalau folder `windows` belum ada)
```
flutter create --platforms=windows --project-name arsip_dokumen --org id.go.pu .
```

**2. Pasang ikon aplikasi**: salin `installer\app_icon.ico` ke `windows\runner\resources\app_icon.ico` (timpa file yang ada).
```
copy installer\app_icon.ico windows\runner\resources\app_icon.ico
```
Opsional: buka `windows\runner\Runner.rc` di Notepad, lalu ganti teks `"arsip_dokumen"` pada baris `FileDescription` dan `ProductName` menjadi `"Arsip Dokumen PU"`.

**3. Build aplikasi**
```
flutter pub get
flutter build windows --release
```

**4. Buat installer**: buka **Inno Setup**, pilih *File → Open* `installer\windows\setup.iss`, lalu klik **Build → Compile**.
Hasilnya:
```
installer\windows\output\ArsipDokumenPU_Setup_1.0.0.exe
```

### Cara 2 — Windows + macOS sekaligus, tanpa memasang apa pun (GitHub Actions) ✅ disarankan
Installer macOS **hanya bisa dibuat di komputer Mac**. GitHub menyediakan mesin Windows dan Mac secara gratis, jadi kedua installer bisa dibuat dari sini:

1. Upload folder ini ke repo GitHub (boleh private, misalnya di organisasi Infinisynx-Teknolab-Indonesia).
2. Buka tab **Actions**, pilih **Build Installer Windows & macOS**, lalu klik **Run workflow**.
3. Setelah selesai (sekitar 15 menit), unduh dari bagian **Artifacts**:
   - **ArsipDokumenPU_Windows** → `ArsipDokumenPU_Setup_<versi>.exe`
   - **ArsipDokumenPU_macOS** → `ArsipDokumenPU_<versi>_macOS.dmg` (Universal: Mac Intel + Apple Silicon M1/M2/M3/M4)
4. Push tag versi (misalnya `v1.0.1`), dan kedua file otomatis dilampirkan ke halaman **Releases**.

Versi installer diambil dari `version:` di `pubspec.yaml`.

### Cara 3 — installer macOS di Mac sendiri
Kebutuhan: **Xcode** (dari App Store), **Flutter SDK**, dan **CocoaPods** (`brew install cocoapods`). Jalankan di Terminal dari dalam folder `ArsipDokumenPU_Desktop`:
```
flutter create --platforms=macos --project-name arsip_dokumen --org id.go.pu .
cp installer/macos/AppDelegate.swift installer/macos/MainFlutterWindow.swift macos/Runner/
cp installer/macos/Release.entitlements installer/macos/DebugProfile.entitlements macos/Runner/
cp installer/macos/AppInfo.xcconfig macos/Runner/Configs/AppInfo.xcconfig
rm -rf macos/Runner/Assets.xcassets/AppIcon.appiconset
cp -R installer/macos/AppIcon.appiconset macos/Runner/Assets.xcassets/
plutil -replace CFBundleName -string "Arsip Dokumen PU" macos/Runner/Info.plist
plutil -replace CFBundleDisplayName -string "Arsip Dokumen PU" macos/Runner/Info.plist
flutter pub get
flutter build macos --release
mkdir -p dmg && cp -R build/macos/Build/Products/Release/ArsipDokumenPU.app "dmg/Arsip Dokumen PU.app"
codesign --force --deep --sign - "dmg/Arsip Dokumen PU.app"
ln -s /Applications dmg/Applications
hdiutil create -volname "Arsip Dokumen PU" -srcfolder dmg -ov -format UDZO ArsipDokumenPU_macOS.dmg
```
Langkah `flutter create` sampai `plutil` cukup dilakukan sekali. Selama pengembangan di Mac: `flutter run -d macos`.

## B. Memasang di PC mana saja

### Windows
1. Salin **`ArsipDokumenPU_Setup_1.0.0.exe`** ke PC tujuan (Windows 10/11 64-bit), lalu jalankan.
2. Installer otomatis:
   - memasang aplikasi ke `C:\Program Files\Arsip Dokumen PU`
   - memasang Microsoft Visual C++ Runtime bila belum ada (tidak butuh internet)
   - membuat shortcut di Desktop dan Start Menu
   - menyediakan opsi *jalankan otomatis saat Windows menyala*, supaya antrian upload tetap terkirim
3. Uninstall lewat *Settings → Apps*. Data di `%APPDATA%\ArsipDokumenPU` (database offline + antrian) **tidak ikut terhapus**.
4. Update versi: jalankan installer versi baru di atas versi lama. Data tetap aman.

PC tujuan **tidak perlu** Flutter, Python, ataupun MySQL. Cukup bisa menjangkau alamat server di jaringan kantor/internet.

### macOS (macOS 10.15 Catalina atau lebih baru, Intel & Apple Silicon)
1. Buka **`ArsipDokumenPU_<versi>_macOS.dmg`**, lalu seret **Arsip Dokumen PU** ke folder **Applications**.
2. **Pertama kali dibuka**: karena aplikasi belum ditandatangani sertifikat Apple berbayar, macOS akan memperingatkan *"tidak dapat diverifikasi"*.
   - **macOS 15 Sequoia / 26 dan lebih baru**: klik *Done*, lalu buka **System Settings → Privacy & Security**, gulir ke bawah, dan klik **Open Anyway** di samping *"Arsip Dokumen PU"*. Masukkan password Mac.
   - **macOS 14 dan sebelumnya**: klik kanan aplikasi di Applications → **Open** → **Open**.
   - Ini hanya sekali. Setelah itu aplikasi terbuka seperti biasa.
   - Kalau muncul pesan *"rusak / damaged"*, jalankan di Terminal: `xattr -dr com.apple.quarantine "/Applications/Arsip Dokumen PU.app"`
3. Data offline tersimpan di `~/Library/Application Support/ArsipDokumenPU` dan **tidak hilang** saat aplikasi diganti versi baru.
4. Supaya peringatan di langkah 2 hilang sama sekali, instansi perlu akun **Apple Developer** (USD 99/tahun). Isi *secrets* yang tertulis di bagian atas `.github/workflows/build-installers.yml`, dan GitHub akan menandatangani serta menotarisasi aplikasi secara otomatis.

**Bedanya dengan Windows:**
| | Windows | macOS |
|---|---|---|
| Ikon tray | pojok kanan bawah (system tray) | **menu bar** kanan atas |
| Tombol jendela | tombol sendiri di title bar ungu | tombol bulat **merah/kuning/hijau** bawaan Mac |
| Tutup jendela (X / merah) | sembunyi ke tray | sembunyi ke menu bar (klik ikon Dock untuk membuka lagi) |
| Keluar total | tray → Keluar | menu bar → Keluar, atau **⌘Q** |
| Layar penuh | **F11** | **F11** atau **⌃⌘F** |
| Cari di dokumen / zoom | Ctrl+F, Ctrl +/− | ⌘F, ⌘ +/− |

## Ikon & system tray (sama seperti Batam ChitChat)
- Ikon aplikasi tampil di taskbar dan di **system tray** (pojok kanan bawah).
- **Klik kiri** ikon tray: buka aplikasi.
- **Klik kanan** ikon tray: menu **Buka Arsip Dokumen PU** | **Logout** | **Keluar**. *Keluar* langsung menutup aplikasi.
- Tombol **X** jendela atau tombol **Kecilkan ke tray** menyembunyikan aplikasi ke tray. Aplikasi tetap berjalan, jadi antrian upload tetap terkirim.
- Saat `flutter run` (tanpa installer), salin `installer\app_icon.ico` ke `windows\runner\resources\app_icon.ico` sekali, lalu `flutter clean` dan `flutter run -d windows`, supaya ikon di file exe ikut berganti.

## C. Pertama kali dipakai

> **Penting soal login:** `administrator / administrator` hanya berlaku **sebelum** aplikasi terhubung ke server. Setelah terhubung (di layar login tertulis *Terhubung ke http://...*), masuk dengan akun server. Admin bawaan server adalah **admin / Admin@12345**. Lupa password admin? Di folder server jalankan `D:\python3.12\python.exe reset_admin.py`.

1. Aplikasi terbuka layar penuh. **F11** untuk keluar/masuk layar penuh, dan tombol **Keluar Aplikasi** ada di sidebar.
2. Login `administrator / administrator`, lalu buka menu **Server API**.
3. Isi alamat server, misalnya `http://192.168.1.10:8000/api`, klik **Tes Koneksi**, lalu login dengan akun **admin server**, kemudian **Simpan & Hubungkan**.
4. Akun `administrator` bawaan otomatis nonaktif. Tambahkan staf di **Staf & Admin**.
5. Lakukan langkah 2–3 sekali di setiap PC (oleh admin). Setelah itu staf cukup login.

## Fitur

| Menu | Isi |
|---|---|
| **Login** | Admin & staf. Sebelum terhubung ke server hanya akun `administrator / administrator` yang bisa masuk. Setelah terhubung, login memakai akun server dan **tetap bisa login offline** |
| **Dashboard** | Total dokumen, proyek berjalan, nilai kontrak TA berjalan, antrian upload, grafik per kategori, dokumen terbaru |
| **Dokumen Saya** | Semua dokumen yang diinput user tersebut, dengan tab Hari ini / **Draf** / Menunggu upload / Gagal / Tersimpan di server, kirim draf, upload ulang, dan export laporan kerja |
| **Unggah Dokumen** | **Lihat isi** tiap file sebelum disimpan, lalu **Periksa & Simpan** (ringkasan data + file) → *Kirim sekarang* atau *Simpan draf*. Isian: proyek, kategori PU (Kontrak, SPMK, RAB/BoQ, Gambar, As-Built, Laporan Harian/Mingguan/Bulanan, MC/Opname, Foto Progres, BA PHO/FHO, Uji Mutu, Surat, Izin, Keuangan, K3), nomor, tanggal, tag, keterangan. Bisa **banyak file sekaligus**. Format: PDF, Word, Excel, TXT, foto, DWG, ZIP/RAR |
| **Arsip Dokumen** | Pencarian + filter (proyek, kategori, tahun, jenis file, status upload), urutan, **membuka dokumen langsung di aplikasi** (PDF, Word, Excel, CSV, TXT, foto; tanpa WPS/Office) dengan kata yang dicari langsung tersorot, buka dengan aplikasi lain bila perlu, simpan salinan, lihat di folder, edit info, hapus, **Export Excel (CSV)** |
| **Permintaan Edit** | Staf tidak bisa mengubah dokumen yang sudah diarsipkan secara langsung. Staf **mengajukan perubahan** (data dan/atau file pengganti + alasan), admin melihat perbandingan lama → baru lalu **Setujui & Terapkan** atau **Tolak** dengan alasan. File lama disimpan di **Riwayat Versi** |
| **Kamus Pencarian** | Hubungkan istilah dengan kata/kode, misalnya `pengeluaran = belanja, biaya, 544`. Berlaku dua arah |
| **Proyek / Paket** | Kode paket, lokasi, TA, sumber dana, nilai kontrak, kontraktor, konsultan, PPK, jadwal, status, progres %. Bisa langsung lihat atau unggah dokumen per proyek. Export CSV |
| **Staf & Admin** (admin) | Tambah, edit, reset password, aktif/nonaktif, hapus akun (NIP, jabatan) |
| **Log Aktivitas** (admin) | Semua login, upload, unduh, ubah, dan hapus, lengkap dengan IP |
| **Server API** (admin) | Alamat API (FastAPI / C#), tes koneksi, hubungkan, ganti server, putuskan koneksi |
| **Profil Saya** | Info akun, statistik input (hari ini, bulan ini, total), ganti password, Logout, Keluar Aplikasi |
| **Panduan** | Langkah pemakaian untuk staf (dan bagian khusus admin) |
| **Penyimpanan & Info** | Lokasi database lokal, ukuran file, bersihkan cache unduhan |

### Pencarian pintar & dokumen terkait

- Server membaca **isi file** PDF, Word (.docx), Excel (.xlsx), dan TXT/CSV. Foto bisa ikut dibaca bila OCR dipasang (opsional: `pip install pytesseract pillow` + Tesseract-OCR bahasa Indonesia).
- Daftar kata/kode isi file disalin ke database lokal, jadi pencarian isi file **tetap jalan saat offline**.
- Kata kunci diperluas lewat Kamus. Contoh: mencari "pengeluaran" juga menemukan PDF yang di dalamnya tertulis "544". Kode bertitik cocok dengan atau tanpa titik (5.2.2.01 = 52201).
- Setiap hasil menunjukkan alasan cocoknya, misalnya *isi file memuat "544"* atau *via kamus: belanja*.
- **Seri dokumen**: dokumen yang sama dari tahun ke tahun (misalnya *Dokumen 1 Formula A* 2000 → *Formula B* 2002 → *Formula C* 2026) dikenali sebagai satu seri. Caranya lewat isian **Seri / Kelompok Dokumen**, atau otomatis kalau judulnya sama dan hanya berbeda huruf/versi (A/B/C, Rev.2, v3, Addendum, tahun). Mencari *Formula C* menampilkan C beserta **Seri: A (2000), B (2002)** tepat di bawah hasilnya, dan detail dokumen menampilkan linimasa seri dari yang paling lama.
- **Tab "Terkait"** di detail dokumen menampilkan dokumen lain yang memuat kode/nomor yang sama (di data atau isi file), satu proyek, tag sama, atau judul mirip, **dikelompokkan per tahun** termasuk tahun-tahun lampau.

### Cetak & kirim email
- Tombol **Cetak** (atau **Ctrl+P / ⌘P**) ada di penampil dokumen, layar penuh, dan detail dokumen. Dialognya berisi pilihan **printer**, **jumlah salinan**, **halaman tertentu** (mis. `1-3, 5`), dan **Simpan PDF**.
  - PDF dicetak langsung. **Word** dicetak persis seperti tampilannya, **Excel/CSV** sebagai tabel A4 mendatar, **teks dan foto** sebagai halaman A4.
  - Windows memakai printer Windows langsung (tanpa WPS/Office). macOS memakai sistem cetak bawaan Mac.
- Tombol **Kirim Email** mengirim dokumen yang sudah tersimpan di server ke satu atau beberapa alamat, dengan CC, subjek, dan pesan. File asli dikirim **oleh server** sebagai lampiran lewat email yang diatur admin di aplikasi **Admin Server**, dan tercatat di Log Aktivitas.

### PC baru wajib disetujui admin
- Aplikasi bisa dipasang di mana saja, tetapi **staf baru bisa login setelah PC itu disetujui** di aplikasi **Admin Server** (folder `admin_app/`). Admin tetap bisa login untuk menghubungkan PC.
- Layar login menampilkan status PC: *menunggu persetujuan* atau *ditolak/dicabut*. Menu **Server API** juga menampilkan status persetujuan PC ini.
- PC yang ditolak atau dicabut otomatis menghapus akun yang tersimpan, sehingga login offline juga tertutup.

### Penampil dokumen di dalam aplikasi (tanpa WPS / Office)

| Jenis | Yang bisa dilakukan |
|---|---|
| **PDF** | Gulir halaman, lompat ke halaman, zoom (tombol, Ctrl + roda mouse, Ctrl +/-), **cari teks dengan sorotan**, pilih & salin teks. Mesin PDFium (sama seperti Chrome) |
| **Word (.docx)** | Halaman putih seperti di Word: judul/heading, tebal/miring/garis bawah, warna, stabilo, rata kiri/tengah/kanan, daftar bernomor & berpoin, **tabel** (gabung sel, warna sel), **gambar**, kotak teks, pemisah halaman. Zoom, cari, salin teks |
| **Excel (.xlsx) / CSV** | Tabel dengan kolom A, B, C dan nomor baris, **tab sheet**, angka format Indonesia (1.250.000,50 / Rp / %), tanggal, sel gabung, huruf tebal, warna sel. Zoom & cari isi sel |
| **TXT** | Teks dengan zoom, potong baris, cari |
| **Foto** | Zoom (roda mouse), geser, **putar 90°** |

- Dari hasil pencarian, misalnya cari `pengeluaran`, PDF yang berisi kode `544` atau `5.4.4` terbuka dengan **kode itu langsung tersorot**.
- File `.doc` / `.xls` (format Office lama), DWG, dan ZIP/RAR tetap bisa dibuka dengan aplikasi lain atau disimpan salinannya.
- Tombol **Layar penuh** membuka dokumen di seluruh layar (Esc = kembali).

### Periksa dulu sebelum dikirim (Draf)

- Di **Unggah Dokumen**, klik **Lihat isi** pada tiap file untuk memastikan filenya benar. **Periksa & Simpan** menampilkan ringkasan data + file, lalu pilih:
  - **Kirim sekarang**: langsung masuk antrian kirim ke server.
  - **Simpan draf**: disimpan di PC saja dan **tidak dikirim** sampai Anda menekan *Kirim*.
- Draf tampil di **Dokumen Saya → Draf** dan di pengingat ungu di atas daftar (**Kirim semua**). Buka draf untuk melihat isi file, **Edit info**, **Ganti file**, lalu **Sudah benar → kirim ke server**.
- Dokumen yang sudah masuk antrian tapi belum terkirim masih bisa **ditahan** kembali menjadi draf.

### Cara kerja offline

- Database lokal adalah NoSQL **Sembast**, murni Dart sehingga tidak perlu DLL tambahan. Lokasinya `%APPDATA%\ArsipDokumenPU\arsip.db`, dan file disalin ke `%APPDATA%\ArsipDokumenPU\files\`.
- Simpan dokumen saat internet **atau server mati**: file disalin ke PC dan masuk antrian. Aplikasi mengecek server **setiap 10 detik**, lalu **mengirim otomatis begitu server hidup lagi**, tanpa perlu menekan apa pun. Kalau server menjawab error 5xx (misalnya MySQL mati), dokumen tetap mengantri dan dicoba lagi. Upload aman diulang karena server memakai `client_id` sebagai anti-duplikat.
- **Login offline (admin & staf)**: semua akun aktif di server disalin ke PC sebagai hash PBKDF2 (bukan password asli). Kalau server mati, login tetap jalan dengan akun yang sama seperti di server.
- Saat pertama kali terhubung, setiap PC mendapat **kunci PC**. Dengan kunci itu, daftar akun diperbarui **tiap 5 menit, juga saat aplikasi masih di layar login**. Staf yang baru ditambahkan admin langsung bisa login di semua PC walau server mati sesudahnya. Jumlah akun yang tersimpan terlihat di layar login.
- Akun yang dinonaktifkan atau dihapus admin ikut terblokir di semua PC pada sinkron berikutnya. **Laptop hilang?** Admin membuka *Server API → PC terdaftar → Cabut*, dan akun yang tersimpan di laptop itu terhapus begitu terhubung lagi.
- Metadata seluruh arsip juga disalin ke PC, jadi pencarian dan filter tetap jalan saat offline. File dari server diunduh saat dibuka, lalu bisa dibuka lagi tanpa internet.

## Untuk developer
- Jalankan tanpa installer: `flutter create --platforms=windows --project-name arsip_dokumen .` (sekali), lalu `flutter run -d windows`
- Tes: `flutter test`
- Versi aplikasi: ubah `version` di `pubspec.yaml` **dan** `MyAppVersion` di `installer\windows\setup.iss`
