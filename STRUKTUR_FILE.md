# Struktur File — Aplikasi Desktop Arsip Dokumen PU

Peta semua file di aplikasi desktop, apa fungsinya, dan **file mana yang diubah kalau mau mengganti sesuatu**.

> Cara cepat: cari dulu di bagian **"Mau ubah apa? → buka file ini"** di bawah.

---

## Mau ubah apa? → buka file ini

| Mau mengubah... | Buka file | Cari / ubah bagian |
|---|---|---|
| Title bar atas (tombol full screen, minimize, maximize, tutup, tinggi bar, warna) | `lib/widgets/app_title_bar.dart` | `height: 34`, `_TitleBarButton(...)` |
| Title bar disembunyikan saat full screen & muncul saat mouse ke tepi atas | `lib/widgets/app_title_bar.dart` | `class WindowFrame` (`height: 6` = tebal zona sensor) |
| Cara masuk/keluar full screen, ukuran jendela normal (1366×768) | `lib/services/window_ctl.dart` | `defaultSize`, `enterFullScreen()`, `exitFullScreen()` |
| Aplikasi mulai full screen atau tidak, ukuran minimum jendela | `lib/main.dart` | `WindowOptions(...)`, `WindowCtl.enterFullScreen()` |
| Menu klik kanan system tray (Buka / Logout / Keluar), ikon tray | `lib/services/tray_service.dart` | `Menu(items: [...])` |
| Warna, font, animasi, tema Material | `lib/theme/ym_theme.dart` | `YmColors`, `YmTextStyles`, `buildAppTheme()`, `kMotion` |
| Tombol pintasan Ctrl+F (pencarian di mana saja) | `lib/services/find_shortcut.dart` + `lib/main.dart` | `FindShortcut.run()`, `PageSearchField` |
| Daftar menu di sidebar kiri (urutan, nama, ikon, khusus admin) | `lib/screens/shell_screen.dart` | `const _nav = [...]` |
| Header halaman (jam, status server, tombol tray) | `lib/screens/shell_screen.dart` | `class _Header` |
| Kartu status sinkron di sidebar bawah | `lib/screens/shell_screen.dart` | `class _SyncCard` |
| Tampilan halaman login (judul, tulisan, kotak login) | `lib/screens/login_screen.dart` | `build()` |
| Gambar latar login (langit, gedung, jembatan) | `lib/widgets/login_hero_background.dart` | `_SkylinePainter` |
| Akun default sebelum terhubung server (`administrator/administrator`) | `lib/services/app_state.dart` | `defaultAdminUser`, `defaultAdminPass` |
| Login offline: kunci PC, salin akun admin & staf (juga di layar login) | `lib/services/app_state.dart` | `_ensureDeviceKey()`, `_syncUsers()`, `_offlineLogin()` |
| Daftar PC terdaftar & tombol Cabut (admin) | `lib/pages/server_page.dart` | `_DevicesPanel` |
| Seberapa sering cek server (10 detik), tarik data (2 menit), sinkron akun (5 menit) | `lib/services/app_state.dart` | `Timer.periodic(Duration(seconds: 10))`, `pullFromServer`, `_syncUsers` |
| Kategori dokumen PU (Kontrak, RAB, Laporan, Foto, BA, dst.) | `lib/core/categories.dart` | `docCategories` |
| Jenis proyek, status proyek, sumber dana | `lib/core/categories.dart` | `projectTypes`, `projectStatuses`, `fundingSources` |
| Jenis file yang boleh diunggah, batas ukuran file (100 MB) | `lib/core/format.dart` | `allowedExtensions`, `maxUploadBytes` (samakan dengan server `.env` `MAX_UPLOAD_MB`) |
| Format tanggal, Rupiah, ukuran file | `lib/core/format.dart` | `formatDateTime`, `formatRupiah`, `formatBytes` |
| Isian form unggah/edit dokumen (judul, nomor, seri, tag...) | `lib/pages/doc_form.dart` | `DocMetaFields` |
| Halaman Unggah Dokumen (area pilih file, tombol simpan) | `lib/pages/upload_page.dart` | `build()`, `_save()` |
| Tabel Arsip/Dokumen Saya: kolom, filter, lebar kolom | `lib/pages/documents_page.dart` | `_colProject`, `_colCategory` ..., `FilterDropdown` |
| Bobot / aturan pencarian pintar | `lib/core/smart_search.dart` | `search()` → daftar `fields` (judul 10, nomor 8, ...) |
| Aturan "satu seri" (Formula A/B/C) & dokumen terkait | `lib/core/smart_search.dart` | `baseTitle()`, `sameSeries()`, `related()` (bobot: seri 20, kode sama 5–8, satu proyek 5, tag 3) |
| Angka yang TIDAK dianggap kode penghubung (001, 600, 100, tahun) | `lib/core/smart_search.dart` | `_weakNumber()`, `_isYear()` |
| Isi popup detail dokumen (tab Info / Terkait / Riwayat Versi, tombol draf) | `lib/pages/doc_detail.dart` | `_DocDetailDialogState._build()` |
| Dialog cetak (printer, salinan, halaman, Simpan PDF) | `lib/print/print_dialog.dart` | `_PrintDialog` |
| Cara mencetak ke printer Windows / macOS | `lib/print/print_service.dart` (+ `win_printer.dart` untuk API Windows) | `printPdf()`, resolusi maks `2600` px |
| Tampilan PDF hasil cetak Excel/teks/foto (ukuran huruf, margin, A4 mendatar) | `lib/print/pdf_builder.dart` | `pdfFromSheet()`, `pdfFromText()`, `pdfFromImageFile()` |
| Isi dialog Kirim Email | `lib/pages/email_dialog.dart` | `_EmailDialog` |
| Jenis file yang dibuka di dalam aplikasi | `lib/viewer/document_viewer.dart` | `canViewInApp()`, `DocumentViewer.build()` |
| Tampilan halaman layar penuh penampil (header, tombol simpan/folder/aplikasi lain) | `lib/viewer/document_viewer.dart` | `DocumentViewerPage` |
| Toolbar penampil, warna sorotan hasil cari, langkah zoom | `lib/viewer/viewer_common.dart` | `ViewerToolbar`, `kMatchColor`, `zoomSteps` |
| Cara kode dicari di isi file (544 = 5.4.4) | `lib/viewer/viewer_common.dart` | `buildSearchPattern()` |
| Tampilan PDF (warna latar, jarak halaman) | `lib/viewer/pdf_view.dart` | `PdfViewerParams(...)` |
| Cara Word dibaca (tabel, daftar bernomor, gambar, ukuran halaman) | `lib/viewer/docx_parser.dart` | `_para()`, `_table()`, `_drawing()`, `_numberLabel()` |
| Tampilan halaman Word (bayangan kertas, garis tabel) | `lib/viewer/docx_view.dart` | `_body()`, `_table()` |
| Format angka/tanggal Excel, batas baris (20.000) | `lib/viewer/sheet_parser.dart` | `_formatNumber()`, `maxSheetRows` |
| Tampilan tabel Excel (tinggi baris, warna kepala kolom, tab sheet) | `lib/viewer/sheet_view.dart` | `_baseRowH`, `_body()`, `_tabs()` |
| Layar "Periksa sebelum disimpan" & tombol Simpan draf | `lib/pages/upload_page.dart` | `_ReviewDialog`, `_save(draft:)` |
| Kirim draf / tahan jadi draf / ganti file sebelum terkirim | `lib/services/app_state.dart` | `submitDrafts()`, `holdAsDraft()`, `replaceUnsentFile()` |
| Kotak "Ajukan Perubahan" untuk staf | `lib/pages/edit_request_dialog.dart` | `_EditRequestDialog` |
| Kartu statistik di Dashboard | `lib/pages/dashboard_page.dart` | `StatCard(...)` |
| Teks panduan untuk staf/admin | `lib/pages/help_page.dart` | `sections` |
| Kolom export Excel (CSV) | `lib/core/file_tools.dart` | `exportDocsCsv()`, `exportProjectsCsv()` |
| Alamat endpoint API (kalau backend C# beda path) | `lib/services/api_client.dart` | `_u('/...')` di tiap fungsi |
| Batas waktu koneksi (timeout) | `lib/services/api_client.dart` | `_shortTimeout`, `_uploadTimeout` |
| Lokasi data offline (`%APPDATA%\ArsipDokumenPU`) | `lib/core/local_db.dart` | `baseDir` |
| Iterasi hash login offline | `lib/core/pbkdf2.dart` + `lib/services/app_state.dart` (`_localIterations`) | harus sama dengan server |
| Ikon aplikasi | `installer/app_icon.ico` (exe & installer) + `assets/icons/app_icon.ico` (tray & jendela) | ganti kedua file |
| Ikon aplikasi **macOS** (Dock, Finder) & ikon menu bar | `installer/macos/make_icons.py` → membuat `installer/macos/AppIcon.appiconset/` + `assets/icons/tray_icon_mac.png` | ubah gambar di `make_icons.py`, jalankan ulang |
| Nama aplikasi & bundle id macOS | `installer/macos/AppInfo.xcconfig` | `PRODUCT_NAME`, `PRODUCT_BUNDLE_IDENTIFIER` |
| Izin aplikasi macOS (jaringan, file) | `installer/macos/Release.entitlements` | `com.apple.security.*` |
| Klik Dock membuka jendela lagi, tutup jendela ≠ keluar (macOS) | `installer/macos/AppDelegate.swift` | `applicationShouldHandleReopen`, `applicationShouldTerminateAfterLastWindowClosed` |
| Build installer otomatis Windows + macOS, tanda tangan Apple | `.github/workflows/build-installers.yml` | job `windows`, `macos`, `release` |
| Nama aplikasi, versi, penerbit di installer | `installer/windows/setup.iss` | `MyAppName`, `MyAppVersion`, `MyAppPublisher` |
| Versi aplikasi | `pubspec.yaml` (`version`) **dan** `installer/windows/setup.iss` (`MyAppVersion`) | |
| Library yang dipakai | `pubspec.yaml` | `dependencies` |

---

## Isi folder

```
ArsipDokumenPU_Desktop/
├── lib/                  source code aplikasi (Dart/Flutter)
│   ├── main.dart         titik awal aplikasi
│   ├── core/             logika dasar: model data, database lokal, format, pencarian
│   ├── services/         "otak" aplikasi: login, sinkron, API, tray, jendela, navigasi
│   ├── screens/          layar besar: Login dan kerangka utama (sidebar + header)
│   ├── pages/            halaman-halaman menu (Dashboard, Unggah, Arsip, ...)
│   ├── viewer/           PENAMPIL DOKUMEN di dalam aplikasi: PDF, Word, Excel/CSV, TXT, foto
│   ├── print/            CETAK & simpan PDF (printer Windows/macOS langsung)
│   ├── widgets/          komponen tampilan yang dipakai berulang
│   └── theme/            warna & gaya teks
├── assets/icons/         ikon yang dibundel di dalam aplikasi (tray & jendela)
├── installer/            bahan installer: windows/ (Inno Setup + VC++ Runtime), macos/ (ikon, izin, AppDelegate)
├── test/                 tes otomatis kecil
├── .github/workflows/    build installer Windows (.exe) + macOS (.dmg) otomatis di GitHub
├── pubspec.yaml          daftar library + versi aplikasi + aset
├── analysis_options.yaml aturan pengecekan kode (lint)
├── API.md                kontrak API dengan server
├── README.md             cara build, install, dan pakai
└── STRUKTUR_FILE.md      file ini
```

---

## lib/main.dart
**Titik awal aplikasi.** Menyiapkan jendela (ukuran, title bar disembunyikan, mulai full screen), memuat data offline (`AppState.load`), memasang system tray, lalu menjalankan aplikasi.
- `WindowOptions`: ukuran awal 1366×768, ukuran minimum 1100×680, title bar bawaan Windows disembunyikan.
- `MaterialApp`: tema global, shortcut **F11**, dan menempelkan `AppTitleBar` di atas semua layar.
- `RootGate`: menampilkan **Login** kalau belum login, **Shell** (aplikasi utama) kalau sudah.

---

## lib/core/ — logika dasar

| File | Fungsi |
|---|---|
| `models.dart` | **Bentuk data**: `AppSettings` (alamat API), `CachedUser` (akun untuk login offline), `ServerUser`, `Project` (proyek/paket), `DocRecord` (dokumen + status: **draf** / menunggu upload / sedang diunggah / tersimpan / gagal + seri), `SearchTerm` (kamus), `EditRequest` (permintaan edit), `DocVersion`, `AuditEntry`, `Session` (sesi login). Ubah di sini kalau menambah kolom data baru. |
| `local_db.dart` | **Database NoSQL offline (Sembast)** di `%APPDATA%\ArsipDokumenPU\arsip.db`. Koleksi: settings, users, projects, documents, search_tokens, search_terms. Juga folder salinan file (`files\`) dan folder sementara (`temp\`). |
| `categories.dart` | Daftar **kategori dokumen PU** (kode, nama, ikon, warna), **jenis proyek**, **status proyek**, **sumber dana**. |
| `format.dart` | Fungsi format: tanggal Indonesia, Rupiah, ukuran file, nama file, jenis file. Juga **daftar ekstensi yang boleh diunggah** dan **batas ukuran file**. |
| `file_tools.dart` | Alat file Windows: buka file dengan aplikasi bawaan, tampilkan di Explorer, simpan salinan, **export CSV** (dokumen & proyek), label status upload. |
| `pbkdf2.dart` | Hash password **PBKDF2-SHA256** untuk login offline (rumusnya sama dengan server). |
| `smart_search.dart` | **Pencarian pintar**: cari di metadata + isi file + kamus, kode bertitik (5.2.2.01 = 52201), skor & alasan cocok. Juga **dokumen terkait** lintas tahun dan **deteksi seri** (Formula A → B → C). |

---

## lib/services/ — otak aplikasi

| File | Fungsi |
|---|---|
| `app_state.dart` | **Pusat logika** (paling penting). Memuat & menyimpan data lokal, **login online/offline**, akun default `administrator`, **hubungkan/putuskan server**, **antrian upload otomatis** (cek tiap 10 detik), tarik data dari server, sinkron akun/proyek/kamus/token isi file, simpan/edit/hapus dokumen, **draf** (`submitDrafts`, `holdAsDraft`, `replaceUnsentFile`), permintaan edit, kelola proyek & kamus. Semua halaman membaca data dari sini. |
| `api_client.dart` | **Komunikasi dengan server** (REST). Satu fungsi per endpoint: login, users, projects, documents (upload multipart, unduh), search-index, search-terms, edit-requests, versions, audit. Juga membedakan error: offline / 401 / ditolak. |
| `tray_service.dart` | **System tray** (sama seperti Batam ChitChat): ikon di pojok kanan bawah, klik kiri = buka, klik kanan = **Buka / Logout / Keluar**, tombol X = sembunyikan ke tray, `quit()` = tutup total. |
| `window_ctl.dart` | **Kontrol jendela**: masuk/keluar **full screen**, **pengawas jendela** (`init()` / `sync()`) yang menyamakan status full screen dengan kondisi nyata, jadi title bar selalu muncul lagi walau jendela dikecilkan lewat Windows (Win+↓, snap), mengembalikan ukuran jendela setelah keluar full screen, memastikan **tombol taskbar** tetap muncul, menampilkan jendela dari tray. |
| `find_shortcut.dart` | **Ctrl+F / ⌘F di mana saja**: fokus ke kotak cari halaman yang sedang dibuka (Arsip, Dokumen Saya, Proyek, Kamus, Log); halaman tanpa kotak cari → pindah ke Arsip Dokumen. Halaman baru cukup memakai mixin `PageSearchField`. |
| `nav.dart` | **Navigasi antar halaman** di dalam aplikasi (mis. dari Dashboard ke Arsip dengan filter proyek, dari Kamus ke Arsip dengan kata kunci, ke Dokumen Saya tab "Gagal"). |

---

## lib/screens/ — layar besar

| File | Fungsi |
|---|---|
| `login_screen.dart` | **Halaman login**: latar langit/jembatan, kotak login kaca, status server, petunjuk mode awal/offline, tombol tray & full screen & keluar di pojok kanan atas. |
| `shell_screen.dart` | **Kerangka aplikasi setelah login**: **sidebar kiri** (logo, kartu user, daftar menu `_nav`, kartu sinkron, Logout, Keluar), **header** (judul halaman, instansi, status server, jam, tombol tray & full screen), banner peringatan, dan wadah semua halaman (`IndexedStack`, jadi isian form tidak hilang saat pindah menu). |

---

## lib/pages/ — halaman menu

| File | Menu / fungsi |
|---|---|
| `dashboard_page.dart` | **Dashboard**: sapaan, kartu statistik (total dokumen, proyek, nilai kontrak TA, antrian), grafik per kategori, proyek berjalan, dokumen terbaru. |
| `upload_page.dart` | **Unggah Dokumen**: isi data dokumen, pilih satu/banyak file, **Lihat isi** tiap file, **Periksa & Simpan** (`_ReviewDialog`) → kirim sekarang atau **simpan draf**, offline pun bisa, daftar "baru disimpan". |
| `doc_form.dart` | **Form isian dokumen** yang dipakai bersama (proyek, kategori, tanggal, judul, nomor, **seri** dengan saran otomatis, tag, keterangan) + dialog **Edit Info** (admin / dokumen yang belum terupload). |
| `documents_page.dart` | **Arsip Dokumen** dan **Dokumen Saya** (file yang sama, mode `mineOnly`): pencarian pintar, filter, urutan, tabel, alasan cocok, **relasi/seri di bawah hasil**, export CSV, tab ringkasan (Hari ini / **Draf** / Menunggu / Gagal / Tersimpan), pengingat draf + **Kirim semua** (`_DraftBanner`). |
| `doc_detail.dart` | **Popup detail dokumen**: **penampil dokumen** di panel kiri (PDF/Word/Excel/TXT/foto, kata yang dicari tersorot; file dari server diunduh otomatis ≤ 25 MB), kotak **Draf** (kirim ke server / ganti file / tahan), info, tombol buka/simpan/lihat di folder, edit/ajukan perubahan, hapus. Tab **Terkait** (linimasa seri + relasi per tahun) dan **Riwayat Versi**. |
| `edit_request_dialog.dart` | **Ajukan Perubahan** (staf): ubah data dan/atau ganti file + alasan, lalu kirim ke admin. |
| `requests_page.dart` | **Permintaan Edit**: admin melihat lama vs usulan, membuka file usulan, **Setujui & Terapkan / Tolak**. Staf melihat status & catatan admin, bisa membatalkan. |
| `projects_page.dart` | **Proyek / Paket**: daftar kartu proyek, filter, export, tambah/edit/hapus (admin), lihat & unggah dokumen per proyek. |
| `terms_page.dart` | **Kamus Pencarian**: istilah ↔ kata/kode terkait (mis. pengeluaran = 544), uji kata kunci, baca ulang isi file (admin). |
| `users_page.dart` | **Staf & Admin** (admin): tambah, edit, reset password, aktif/nonaktif, hapus akun. |
| `audit_page.dart` | **Log Aktivitas** (admin): riwayat login, unggah, unduh, ubah, hapus beserta IP. |
| `server_page.dart` | **Server API** (admin): isi alamat API, tes koneksi, hubungkan dengan akun admin server, ganti/putuskan server. |
| `profile_page.dart` | **Profil Saya**: info akun, statistik input, ganti password, Logout & Keluar. |
| `settings_page.dart` | **Penyimpanan & Info**: lokasi database & ukuran file lokal, bersihkan cache unduhan, pintasan, versi aplikasi (`appVersion`). |
| `help_page.dart` | **Panduan** langkah-langkah untuk staf (dan bagian admin). |

---

## lib/print/ — cetak & simpan PDF (tanpa WPS / Office)

| File | Fungsi |
|---|---|
| `print_dialog.dart` | **Dialog Cetak**: menyiapkan PDF dari penampil yang sedang terbuka, memilih printer, jumlah salinan, halaman tertentu, **Simpan PDF**. `PrintController` menghubungkan tombol Cetak dengan penampil. |
| `print_service.dart` | Daftar printer & kirim ke printer. **Windows**: halaman PDF dirender PDFium (pdfrx) lalu dicetak lewat API Windows; halaman mendatar diputar otomatis. **macOS**: perintah `lp` (CUPS). |
| `win_printer.dart` | Pemanggilan API printer Windows langsung (`winspool.drv`, `gdi32.dll`) memakai `dart:ffi`: EnumPrinters, CreateDC, StartDoc, StretchDIBits, dst. |
| `pdf_builder.dart` | Membuat PDF dari halaman Word (gambar), tabel Excel/CSV, teks, dan foto memakai paket `pdf` (murni Dart). Memakai font Arial/Segoe dari sistem bila ada. |

Catatan: paket `printing` sengaja **tidak** dipakai karena membawa `pdfium.dll` lain yang bentrok dengan pdfrx.

---

## lib/viewer/ — penampil dokumen di dalam aplikasi (tanpa WPS / Office)

| File | Fungsi |
|---|---|
| `document_viewer.dart` | **Pintu masuk penampil.** `DocumentViewer` memilih penampil sesuai jenis file (PDF / Word / Excel / CSV / TXT / foto) dan menampilkan pesan + tombol "Buka dengan aplikasi lain" untuk format yang tidak didukung (.doc, .xls, DWG, ZIP). `openDocumentViewer()` membuka **layar penuh** (header ungu + Simpan salinan / Lihat di folder / Aplikasi lain, Esc = kembali). `canViewInApp()` = daftar jenis yang bisa dibuka. |
| `viewer_common.dart` | Bagian bersama: **toolbar** (otomatis 2 baris kalau sempit), kotak **cari di dokumen** (Enter = berikutnya, Shift+Enter = sebelumnya, Ctrl+F), tombol zoom, pintasan keyboard (Ctrl +/−/0), pesan error, **pola pencarian** (kode 544 juga cocok dengan 5.4.4), warna sorotan. |
| `pdf_view.dart` | **PDF** memakai library `pdfrx` (mesin PDFium): halaman, zoom, lompat halaman, cari + sorot teks, pilih & salin teks. |
| `docx_parser.dart` | **Membaca file Word (.docx)** tanpa Office: style & heading, huruf (tebal, miring, ukuran, jenis, warna, stabilo), perataan, indentasi, spasi, daftar bernomor/berpoin, tabel (gabung kolom/baris, warna sel, tabel bersarang), gambar, kotak teks, rumus, pemisah halaman, ukuran & margin kertas. Berjalan di latar (isolate) supaya aplikasi tidak macet. |
| `docx_view.dart` | **Menampilkan Word** sebagai halaman kertas putih: zoom / sesuaikan lebar, cari dengan sorotan + lompat ke hasil, pilih & salin teks. |
| `sheet_parser.dart` | **Membaca Excel (.xlsx) dan CSV**: sheet, teks, angka (format Indonesia, Rp, %), tanggal, hasil rumus, sel gabung, huruf tebal, warna sel, lebar kolom. CSV: pemisah `;` `,` tab otomatis. Maks 20.000 baris × 200 kolom. |
| `sheet_view.dart` | **Menampilkan tabel** seperti Excel: kepala kolom A B C, nomor baris, tab sheet di bawah, zoom, cari isi sel (pindah sheet otomatis ke yang cocok). |
| `text_view.dart` | **File teks** (.txt, .log, .md, .json, .xml): huruf Consolas, zoom, potong baris, cari. Maks 5 MB pertama. |
| `image_view.dart` | **Foto**: zoom roda mouse / tombol, geser, putar kiri/kanan. |

Dipakai di: panel kiri **detail dokumen** (`pages/doc_detail.dart`), tombol **Buka dokumen (layar penuh)**, **Riwayat Versi**, file usulan di **Permintaan Edit** (`pages/requests_page.dart`), dan **Lihat isi** sebelum upload (`pages/upload_page.dart`).

---

## lib/widgets/ — komponen tampilan

| File | Fungsi |
|---|---|
| `app_title_bar.dart` | **Title bar atas** pengganti title bar Windows: seret untuk menggeser jendela, tombol **Full screen / Minimize / Maximize / Tutup ke tray**. Ubah di sini untuk tinggi bar, warna, tombol. |
| `common.dart` | Komponen umum: `Panel` (kartu putih berjudul), `fieldDecoration` (gaya kotak isian), gaya tombol, `showSnack` (notifikasi bawah), `confirmDialog`, `NetStatusPill` (status server), `ArsipLogo`, `confirmExit` (dialog keluar: Batal / Kecilkan ke tray / Keluar), `toggleFullScreen`. |
| `ui.dart` | Komponen halaman: `StatCard`, `CategoryBadge`, `DocStatusChip`, `FileTypeIcon` (ikon PDF/Word/Excel/foto), `EmptyState`, `PageBody` (padding halaman), `FilterDropdown`. |
| `login_hero_background.dart` | Gambar latar login (langit, gedung, jembatan), digambar dengan kode tanpa file gambar. |

## assets/fonts/

Plus Jakarta Sans (Regular, Italic, Medium, SemiBold, Bold, ExtraBold) + lisensi OFL. Didaftarkan di `pubspec.yaml` bagian `fonts`.

## lib/theme/
| File | Fungsi |
|---|---|
| `ym_theme.dart` | Token desain "gambar kerja PU": **warna** (`YmColors`: ink, paper, line, puBlue, marka; nama lama seperti accentPurple tetap ada dan dipetakan ke warna baru), **gaya teks** (`YmTextStyles`, font Plus Jakarta Sans), **durasi animasi** (`kMotion`, `motion()` mengikuti setelan kurangi-animasi OS), `buildAppTheme()` untuk tombol, isian, dialog, tab, dan snackbar, serta transisi halaman geser+pudar. Ganti di sini, dan seluruh aplikasi ikut berubah. |

---

## File lain

| File | Fungsi |
|---|---|
| `pubspec.yaml` | Nama & **versi** aplikasi, **library** (window_manager, tray_manager, http, crypto, file_picker, sembast), aset ikon. |
| `analysis_options.yaml` | Aturan lint (`flutter analyze`). |
| `test/widget_test.dart` | Tes: format Rupiah & PBKDF2 harus sama dengan Python (`flutter test`). |
| `assets/icons/app_icon.ico` | Ikon untuk **system tray & jendela** (dibaca saat aplikasi berjalan). |
| `installer/app_icon.ico` | Ikon untuk **file exe** (salin ke `windows\runner\resources\`) dan **installer**. |
| `installer/windows/setup.iss` | Skrip **Inno Setup**: nama/versi, folder install, shortcut, VC++ Runtime, opsi jalan otomatis saat Windows menyala, uninstall. |
| `installer/windows/vc_redist.x64.exe` | Microsoft Visual C++ Runtime (wajib untuk aplikasi Flutter), dibundel supaya instalasi bisa offline. |
| `.github/workflows/build-installers.yml` | Build installer **Windows (.exe) dan macOS (.dmg)** otomatis di GitHub Actions; lampirkan ke Releases saat push tag `v*`; tanda tangan | `.github/workflows/build-windows-installer.yml` | Build installer otomatis di GitHub Actions. | notarisasi Apple opsional lewat secrets. |
| `API.md` | Kontrak API: semua endpoint server yang dipanggil aplikasi. |
| `windows/` *(dibuat oleh `flutter create`)* | Proyek native Windows. `windows\runner\resources\app_icon.ico` = ikon exe; `windows\runner\Runner.rc` = nama produk di properti exe. |
