# Arsip Dokumen PU — Server API (Python FastAPI + MySQL)

Server untuk aplikasi desktop **Arsip Dokumen PU** (paket terpisah: *ArsipDokumenPU_Desktop*).
Menyimpan akun, proyek, metadata dokumen (MySQL), dan file dokumen (folder `storage`).
Server juga membaca isi PDF/Word/Excel/TXT untuk pencarian pintar, mengelola permintaan edit dan riwayat versi, serta mencatat log aktivitas.

> 📁 Daftar lengkap semua file, fungsinya, dan file mana yang diubah untuk mengganti sesuatu ada di **[STRUKTUR_FILE.md](STRUKTUR_FILE.md)**.

```
ArsipDokumenPU_Server/
├── app/               kode server (main.py, db.py, extract.py, security.py, config.py)
├── requirements.txt   library Python
├── .env.example       contoh pengaturan (salin jadi .env)
├── setup_mysql.sql    (cadangan) membuat database + user MySQL secara manual
├── seed_demo.py       isi data contoh secara manual (otomatis juga saat database kosong)
├── API.md             kontrak API — acuan kalau backend dibuat ulang dengan C# .NET
└── STRUKTUR_FILE.md   peta semua file + fungsinya
```

## Instalasi (testing / server kantor)

Kebutuhan: **MySQL 8 / MariaDB** (XAMPP, Laragon, atau MySQL Installer) yang sedang **berjalan**, dan **Python 3.12** di `D:\python3.12\python.exe` (tanpa venv).
Semua perintah diketik di **PowerShell / CMD** dari dalam folder `ArsipDokumenPU_Server`.

> **Database dibuat otomatis.** Saat server pertama kali jalan, server membuat database `arsip_pu`, user `arsip`, semua tabel, admin pertama, kamus pencarian, dan (bila `SEED_DEMO=1`) **50 dokumen contoh**. Tidak perlu membuka phpMyAdmin.
> Untuk ini server memakai akun admin MySQL dari `MYSQL_ADMIN_URL` (bawaan: `root` tanpa password, seperti XAMPP).

**1. Pasang library Python**
```
D:\python3.12\python.exe -m pip install -r requirements.txt
```

**2. Buat file pengaturan**
```
copy .env.example .env
```
Edit `.env` di Notepad bila perlu:
- `MYSQL_ADMIN_URL`: kalau root MySQL Anda memakai password → `mysql+pymysql://root:PASSWORDANDA@localhost:3306`
- `JWT_SECRET`: ganti dengan teks acak yang panjang
- `AGENCY_NAME`: nama instansi
- `SEED_DEMO=1`: isi 50 dokumen contoh saat database masih kosong (`0` = database kosong)

**3. (Lewati)** setup database manual tidak diperlukan. `setup_mysql.sql` hanya cadangan kalau tidak boleh memakai akun root.

**4. Jalankan server** (dari dalam folder `ArsipDokumenPU_Server`)
```
cd D:\ArsipDokumenPU_Server
D:\python3.12\python.exe run.py
```
Cara lain yang juga bisa:
- `D:\python3.12\python.exe app\main.py`
- `D:\python3.12\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000`

Alamat dan port diatur di `.env` (`HOST=0.0.0.0`, `PORT=8000`).

> Dulu muncul error `ImportError: attempted relative import with no known parent package` kalau `app\main.py` dijalankan langsung. Versi ini sudah memperbaikinya, dan semua cara di atas sekarang bisa dipakai.
Saat pertama kali jalan akan muncul:
```
[arsip] Database 'arsip_pu' dan user 'arsip' dibuat otomatis memakai akun admin MySQL.
[arsip] Admin pertama dibuat: admin / Admin@12345 — SEGERA GANTI PASSWORD!
[arsip] Database kosong -> mengisi 50 dokumen contoh (SEED_DEMO=1)...
[demo] data contoh ditambahkan: 9 proyek, 2 akun staf, 50 dokumen
```
Cek di browser: http://localhost:8000/api/health. Dokumentasi interaktif ada di http://localhost:8000/docs.

**5. Data contoh** sudah terisi otomatis (lihat bagian *Data contoh* di bawah). Kalau `SEED_DEMO=0` dan ingin mengisinya belakangan:
```
D:\python3.12\python.exe seed_demo.py
```

**6. Supaya PC staf bisa terhubung**, buka port 8000 di firewall. Jalankan PowerShell sebagai Administrator:
```
netsh advfirewall firewall add rule name="Arsip Dokumen PU API" dir=in action=allow protocol=TCP localport=8000
ipconfig
```
Alamat untuk aplikasi: `http://<IPv4 PC server>:8000/api`

## Email & persetujuan PC (diatur di menu Admin Server pada aplikasi)
- **Email (SMTP)** untuk tombol *Kirim Email* diatur di aplikasi Arsip Dokumen (login admin) → menu **Admin Server → Email (SMTP)**, lalu cek dengan **Kirim tes**. Untuk Gmail gunakan *App Password*. Pengaturan disimpan di tabel `settings`.
- **PC baru wajib disetujui** (bawaan aktif): staf hanya bisa login di PC yang sudah disetujui di menu **Admin Server → Perangkat (PC)** pada aplikasi. PC yang sudah terdaftar sebelum versi ini otomatis dianggap disetujui.
- Aplikasi Arsip Dokumen **versi lama** (sebelum 1.1.0) tidak mengirim kunci PC, sehingga staf yang memakainya akan ditolak. Pasang versi terbaru di semua PC.

## Lupa password admin / tidak bisa login
Akun **administrator / administrator** hanya berlaku di aplikasi **sebelum** terhubung ke server. Setelah terhubung, login memakai akun di server. Admin bawaan server: **admin / Admin@12345**.

Kalau lupa password admin, jalankan dari folder ini (MySQL harus menyala):
```
D:\python3.12\python.exe reset_admin.py
```
Perintah ini membuat atau mereset **admin / Admin@12345**. Bisa juga memakai nama dan password sendiri:
```
D:\python3.12\python.exe reset_admin.py administrator administrator
```

## Data contoh (50 dokumen, tahun 2000–2026)

Akun: **admin / Admin@12345** (admin), **budi / budi12345** dan **sari / sari12345** (staf).
Semua file asli bisa dibuka: **PDF, Word (.docx), Excel (.xlsx), TXT, dan foto (PNG)**. Isi PDF/Word/Excel/TXT sudah terbaca untuk pencarian.

| Kelompok | Dokumen | Coba di aplikasi |
|---|---|---|
| **Seri "Dokumen 1"** | Formula A (2000) → Formula B (2002) → Formula C (2026) | Cari `formula c`: A dan B muncul sebagai **Seri** di bawah hasil |
| **Kontrak 2100** Jalan Lingkar Sekupang | Kontrak, SPMK, Addendum I (2000), BA PHO (2000), BA FHO (2001), Kontrak Tahap II (2002) | Cari `2100`, atau buka Kontrak Tahap II lalu tab **Terkait** |
| **Kode rekening 544** (pengeluaran) | SPJ 2010, Rekap 2015, LRA 2019 (ditulis `5.4.4`), Nota Dinas 2025, SP2D 2026 | Cari `pengeluaran`: ikut menemukan isi file berkode 544 (lewat Kamus) |
| **Seri "AHSP Bidang Jalan"** | 2015 → Revisi 1 2019 → 2025 (Excel) | Buka salah satunya, lalu lihat linimasa seri |
| **Jembatan Sei Ladi** BM-0458 | Uji beton, BA PHO (2010), As-Built (2011) → Kontrak, Shop Drawing, PDA test, SP2D (2026) | Cari `0458`, atau buka Kontrak Jembatan 2026 lalu tab **Terkait** |
| **Gedung Kecamatan Sekupang** kontrak 3307 | Kontrak (2015), As-Built (2016) → Kontrak Rehabilitasi, Foto 100% (2025) | Cari `3307` |
| **Drainase Ahmad Yani** DR-1120 | Gambar Rencana, Laporan Akhir (2019) → HPS, Izin Lingkungan (2026) | Cari `dr-1120` |
| **Proyek berjalan Simpang Kara** 2026 | Kontrak, MC-0, MC-50, Laporan Mingguan ke-1..4, Foto 0% & 50% | Menu Proyek → **Lihat dokumen** |
| **Tanpa relasi** (10) | Undangan rapat 2005, Pedoman arsip 2008, SOP K3 2012, Inventaris alat berat 2017, Kalibrasi theodolit 2018, Peta banjir 2020, Notulen 2021, Laporan tahunan 2022, SE jam kerja 2023, Renstra 2024 | Tab **Terkait** kosong |

Ingin mulai dari database kosong? Set `SEED_DEMO=0`, lalu hapus database: `DROP DATABASE arsip_pu;` (folder `storage` juga dikosongkan), kemudian jalankan server lagi.

## Upgrade dari versi sebelumnya
Ganti folder `app` dengan yang baru, ulangi langkah 2 untuk library baru, lalu jalankan server.
Kolom/tabel baru ditambahkan **otomatis** tanpa menghapus data, dan isi dokumen lama dibaca ulang otomatis untuk pencarian.

## Menjalankan terus-menerus (server kantor)
Supaya server otomatis hidup setelah PC/server restart, buat tugas di **Task Scheduler**:
- Trigger: *At startup*, lalu centang *Run whether user is logged on or not*
- Action → Program: `D:\python3.12\python.exe`
- Arguments: `run.py`
- Start in: folder `ArsipDokumenPU_Server` (contoh `D:\ArsipDokumenPU_Server`)

## Catatan keamanan untuk produksi

- Gunakan HTTPS (reverse proxy Nginx/IIS dengan sertifikat) bila server diakses lewat internet.
- Ganti `JWT_SECRET` dan password admin pertama.
- Backup rutin database MySQL **dan** folder `server\storage`.
- Hash offline disimpan di setiap PC. Gunakan password yang kuat, dan nonaktifkan akun staf yang keluar supaya terhapus dari semua PC saat sinkron.
- Backup rutin: database MySQL (`mysqldump arsip_pu`) **dan** folder `storage`.
