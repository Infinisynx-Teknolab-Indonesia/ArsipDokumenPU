# Struktur File — Server API Arsip Dokumen PU (FastAPI + MySQL)

Peta semua file server, apa fungsinya, dan **file mana yang diubah kalau mau mengganti sesuatu**.

---

## Mau ubah apa? → buka file ini

| Mau mengubah... | Buka file | Cari / ubah bagian |
|---|---|---|
| Koneksi MySQL (user, password, nama database, host) | `.env` | `DATABASE_URL` |
| Akun root MySQL untuk membuat database otomatis | `.env` | `MYSQL_ADMIN_URL` (XAMPP: `mysql+pymysql://root:@localhost:3306`) |
| Isi / tidak isi 50 dokumen contoh saat database kosong | `.env` | `SEED_DEMO=1` / `0` |
| Isi data contoh (judul, tahun, isi file, relasi) | `app/demo_data.py` | `PROJECTS`, `USERS`, `DOCS` |
| Cara database dibuat otomatis | `app/db.py` | `ensure_database()` |
| Kunci rahasia token login & lama sesi (12 jam) | `.env` | `JWT_SECRET`, `JWT_HOURS` |
| Nama instansi yang tampil di aplikasi | `.env` | `AGENCY_NAME` |
| Admin pertama (dibuat otomatis saat database kosong) | `.env` | `FIRST_ADMIN_USERNAME`, `FIRST_ADMIN_PASSWORD`, `FIRST_ADMIN_NAME` |
| Folder penyimpanan file dokumen | `.env` | `STORAGE_DIR` |
| Batas ukuran upload (MB) | `.env` | `MAX_UPLOAD_MB` (samakan dengan aplikasi `lib/core/format.dart`) |
| Jenis file yang boleh diunggah | `app/config.py` | `ALLOWED_EXTENSIONS` |
| Daftar kode kategori dokumen | `app/config.py` | `CATEGORIES` (samakan dengan aplikasi `lib/core/categories.dart`) |
| Kekuatan hash password | `app/config.py` | `LOGIN_ITERATIONS`, `OFFLINE_ITERATIONS` |
| Kamus pencarian awal (mis. pengeluaran = 544) | `app/main.py` | `DEFAULT_TERMS` (hanya dipakai saat tabel kamus kosong; selanjutnya ubah lewat aplikasi) |
| Tambah kolom di tabel | `app/db.py` | class tabel + `_auto_migrate()` → `wanted` (supaya database lama ikut bertambah kolom) |
| Cara membaca isi PDF/Word/Excel, kata yang diabaikan | `app/extract.py` | `extract_text()`, `STOPWORDS`, `MAX_TOKENS_CHARS` |
| Persetujuan PC: login staf ditolak di PC yang belum disetujui | `app/main.py` | `login()`, `_device_block_reason()`, `device_approval_on()` |
| Isi & tampilan email dokumen | `app/main.py` | `email_document()`, `_send_email()` |
| Pengaturan bawaan (port SMTP 587, persetujuan PC aktif, lampiran 20 MB) | `app/main.py` | `SETTING_DEFAULTS` |
| Aturan siapa boleh apa (admin/staf) | `app/main.py` | `CurrentUser` (semua yang login) / `AdminUser` (khusus admin) di parameter endpoint |
| Tambah/ubah endpoint API | `app/main.py` | `@app.get/post/...("/api/...")` (lalu catat di `API.md`) |
| Alamat & port server (8000) | `.env` | `HOST`, `PORT` |
| Cara server dijalankan | `run.py` | `uvicorn.run(...)` |

---

## Isi folder

```
ArsipDokumenPU_Server/
├── app/
│   ├── __init__.py      penanda folder paket Python (kosong)
│   ├── config.py        pengaturan (dibaca dari .env)
│   ├── db.py            koneksi MySQL + definisi tabel + migrasi otomatis
│   ├── security.py      hash password & token login (JWT)
│   ├── extract.py       membaca isi file untuk pencarian pintar
│   ├── demo_data.py     data contoh: 9 proyek, 2 staf, 50 dokumen (file asli)
│   └── main.py          semua endpoint API
├── run.py               JALANKAN SERVER: python run.py
├── .env.example         contoh pengaturan (salin jadi .env)
├── requirements.txt     daftar library Python
├── setup_mysql.sql      (cadangan) membuat database & user MySQL secara manual
├── seed_demo.py         isi data contoh (proyek & akun staf)
├── reset_admin.py       atur ulang / buat akun admin (lupa password)
├── API.md               kontrak API lengkap (acuan backend C# .NET)
├── README.md            cara instal & menjalankan
└── STRUKTUR_FILE.md     file ini
```
Dibuat otomatis saat berjalan: `.env` (salinan dari .env.example) dan `storage/` (file dokumen).

---

## app/config.py
Membaca `.env` dan menyediakan pengaturan: `HOST`/`PORT` (alamat server), `DATABASE_URL`, `JWT_SECRET`, `JWT_HOURS`, `STORAGE_DIR` (dibuat otomatis), `AGENCY_NAME`, admin pertama, `MAX_UPLOAD_BYTES`, `APP_VERSION`, **`ALLOWED_EXTENSIONS`** (jenis file), **`CATEGORIES`** (kode kategori), **`LOGIN_ITERATIONS` / `OFFLINE_ITERATIONS`** (iterasi hash).

## app/db.py
Koneksi database (SQLAlchemy), **instalasi database otomatis**, dan **tabel-tabel**.

`ensure_database()` dijalankan setiap kali server start:
1. Konek dengan user aplikasi (`DATABASE_URL`). Kalau berhasil, selesai.
2. Kalau database belum ada, dibuat dengan user aplikasi.
3. Kalau user belum ada atau tidak berhak, server login memakai `MYSQL_ADMIN_URL` (root) lalu membuat **database + user + hak akses**.
4. Kalau MySQL mati, muncul pesan jelas *"Pastikan MySQL/MariaDB (mis. XAMPP) sudah berjalan"*.

| Tabel (class) | Isi |
|---|---|
| `users` (`User`) | akun: username, nama, NIP, jabatan, role admin/staff, aktif, **hash login** + **hash offline** terpisah, login terakhir |
| `projects` (`Project`) | proyek/paket: kode, nama, jenis, lokasi, tahun, sumber dana, nilai kontrak, kontraktor, konsultan, PPK, no. kontrak, jadwal, status, progres |
| `documents` (`Document`) | dokumen: client_id (anti-duplikat), judul, nomor, tanggal, kategori, proyek, keterangan, tag, **seri**, file (nama, path, ukuran, sha256), pengunggah, waktu; **content_text / content_tokens / content_status** untuk pencarian isi file |
| `document_versions` (`DocumentVersion`) | file lama yang diganti lewat permintaan edit yang disetujui (riwayat versi) |
| `edit_requests` (`EditRequest`) | permintaan perubahan dari staf: usulan data, data lama, file usulan, alasan, status, peninjau, catatan |
| `search_terms` (`SearchTerm`) | kamus pencarian: istilah ↔ kata/kode terkait |
| `audit_logs` (`AuditLog`) | log aktivitas: waktu, user, aksi, detail, IP |
| `devices` (`Device`) | **PC terdaftar**: nama PC, hash kunci PC, didaftarkan oleh, terakhir sinkron, IP, aktif/dicabut, **status persetujuan** (pending/approved/rejected), disetujui oleh, OS, versi aplikasi, login terakhir |
| `settings` (`Setting`) | **Pengaturan dari Admin Server** (key/value): SMTP email, persetujuan PC, batas lampiran, catatan kaki email |

- `init_db()`: membuat tabel yang belum ada.
- `_auto_migrate()`: **menambah kolom baru ke database lama** tanpa menghapus data (dipakai saat upgrade versi).

## app/security.py
- `pbkdf2_hex()`: hash PBKDF2-SHA256 (rumus sama persis dengan aplikasi).
- `make_password_fields()`: membuat **dua hash** setiap kali password dibuat/diubah (login server 210.000 iterasi + offline 20.000 iterasi, salt berbeda).
- `verify_password()`: cek password.
- `create_token()` / `decode_token()`: token login **JWT** (HS256, berlaku `JWT_HOURS`).

## app/demo_data.py
**Data contoh** untuk testing (dipakai otomatis bila `SEED_DEMO=1` dan tabel dokumen kosong, atau lewat `seed_demo.py`):
- `PROJECTS`: 9 proyek (2000–2026), `USERS`: staf `budi` & `sari`.
- `DOCS`: **50 dokumen** dalam bentuk `(judul, nomor, tanggal, kategori, kode proyek, tag, seri, jenis file, isi)`. Kelompoknya: seri Dokumen 1 Formula A/B/C, kontrak 2100, kode rekening 544, seri AHSP, Jembatan Sei Ladi BM-0458, Gedung Kecamatan 3307, Drainase DR-1120, proyek Simpang Kara, dan 10 dokumen tanpa relasi.
- `make_pdf()`, `make_docx()`, `make_xlsx()`, `make_png()`: membuat file asli tanpa aplikasi Office.
- `seed()`: menyimpan file ke `storage/`, mengisi tabel, lalu langsung membaca isi file (supaya pencarian isi jalan). Aman diulang.

## app/extract.py
**Membaca isi file** untuk pencarian pintar:
- `extract_text()`: PDF (pypdf), Word .docx, Excel .xlsx (openpyxl), TXT/CSV, foto (OCR, opsional bila pytesseract terpasang).
- `build_tokens()`: daftar kata/kode unik dari isi file (kode bertitik juga disimpan versi rapat: 5.2.2.01 → 52201). Daftar ini disalin ke aplikasi untuk pencarian offline.
- `snippet()`: potongan kalimat di sekitar kata yang cocok.
- `STOPWORDS`: kata umum yang diabaikan (dan, yang, di, ...).

## app/main.py
**Semua endpoint API** (`/api/...`). Blok `if __name__ == "__main__"` di bagian atas membuat file ini bisa dijalankan langsung (`python app\main.py`). Endpoint dikelompokkan:

| Bagian | Endpoint | Fungsi |
|---|---|---|
| Startup | `_startup()` | buat database/tabel otomatis, buat admin pertama, isi kamus awal (`DEFAULT_TERMS`), isi 50 dokumen contoh (bila `SEED_DEMO=1` & kosong), baca isi file yang belum terbaca |
| Health | `GET /health`, `GET /meta` | cek server hidup, info kategori & batas file |
| Login | `POST /auth/login`, `GET /auth/me`, `POST /auth/change-password`, `GET /auth/offline-users` | login, profil, ganti password, daftar hash untuk login offline |
| Akun | `GET/POST /users`, `PATCH/DELETE /users/{username}` | kelola staf/admin (khusus admin) |
| Kunci PC | `POST /devices`, `GET /devices/me`, `GET /devices/offline-users` (header `X-Device-Key`), `GET /devices`, `POST /devices/{id}/approve` · `/reject`, `PATCH`/`DELETE /devices/{id}` | daftarkan PC, status PC, salin akun tanpa login, persetujuan/tolak/cabut (admin) |
| Admin Server | `GET /admin/overview`, `GET/PUT /admin/settings`, `POST /admin/email/test` | dashboard, pengaturan SMTP & keamanan, tes email |
| Email | `POST /documents/{id}/email` | kirim dokumen (lampiran) ke email lewat SMTP |
| Proyek | `GET/POST /projects`, `PUT/DELETE /projects/{id}` | kelola proyek (tambah/ubah/hapus khusus admin) |
| Dokumen | `POST /documents` (upload), `GET /documents`, `GET/PATCH/DELETE /documents/{id}`, `GET /documents/{id}/file` | upload anti-duplikat, daftar, ubah (admin), unduh, hapus (admin) |
| Pencarian | `GET /search`, `GET /search-index`, `GET/POST/PUT/DELETE /search-terms`, `POST /admin/reindex`, `GET /series` | pencarian isi file + kamus, token untuk offline, kamus, baca ulang isi file, daftar seri |
| Permintaan edit | `POST /documents/{id}/edit-requests`, `GET /edit-requests`, `.../approve`, `.../reject`, `.../cancel`, `.../file` | alur staf → admin |
| Versi | `GET /documents/{id}/versions`, `.../versions/{vid}/file` | riwayat file lama |
| Log & statistik | `GET /audit`, `GET /stats` | log aktivitas (admin), ringkasan jumlah |

Fungsi bantu penting: `current_user` / `admin_user` (cek token & hak akses), `audit()` (catat log), `doc_json()` / `project_json()` / `user_json()` (bentuk jawaban JSON), `_apply_doc_changes()` (terapkan perubahan dokumen), `index_document()` (baca isi file di latar belakang), `expand_query()` (perluas kata kunci lewat kamus).

---

## File lain

| File | Fungsi |
|---|---|
| `run.py` | **Menjalankan server** (`python run.py`): membaca `HOST`/`PORT` dari `.env` lalu menyalakan uvicorn. Bisa dijalankan dari folder mana saja. |
| `.env.example` | Contoh pengaturan. Salin menjadi `.env` lalu isi. |
| `requirements.txt` | Library Python: fastapi, uvicorn, sqlalchemy, pymysql, cryptography, python-multipart, pyjwt, pypdf, openpyxl, python-dotenv. |
| `setup_mysql.sql` | **Cadangan**: membuat database `arsip_pu` dan user `arsip` secara manual (tidak perlu, server membuatnya otomatis). |
| `reset_admin.py` | **Lupa password admin**: `python reset_admin.py` → admin / Admin@12345, atau `python reset_admin.py <username> <password>`. Akun dibuat bila belum ada, diaktifkan lagi, dan dijadikan admin. |
| `seed_demo.py` | Mengisi data contoh secara manual: 9 proyek, akun staf `budi` & `sari`, 50 dokumen (aman diulang). |
| `API.md` | Kontrak API lengkap, acuan kalau backend dibuat ulang dengan C# .NET. |
| `storage/` *(otomatis)* | File dokumen: `storage/<tahun>/<bulan>/...`, file usulan edit di `storage/_requests/`. **Ikut di-backup** bersama database. |
