# Kontrak API — Arsip Dokumen PU

Aplikasi desktop memanggil endpoint di bawah ini. Server contoh ada di folder `server/`
(Python FastAPI + MySQL). Kalau nanti backend dibuat ulang dengan **C# .NET (ASP.NET Core)**,
cukup ikuti kontrak ini. Aplikasi tidak perlu diubah.

- Alamat dasar yang diisi di aplikasi: `http://HOST:PORT/api`
- Semua body & jawaban berformat JSON UTF-8, kecuali upload/unduh file.
- Endpoint yang butuh login memakai header `Authorization: Bearer <token>`.
- Format error: `{"detail": "pesan untuk ditampilkan"}`.
  - `401`: belum login / token kedaluwarsa / password salah. Aplikasi otomatis login ulang memakai sesi.
  - `403`: tidak berhak (mis. staf mengakses fitur admin, atau akun nonaktif saat login).
  - `409`: konflik (username/kode paket sudah ada, admin terakhir, dll.).
  - `413`/`415`/`422`: file terlalu besar / jenis file ditolak / data tidak valid. Dokumen ditandai **Gagal** dan tidak diulang otomatis.
  - `5xx` / timeout: dianggap **offline**. Data tetap di antrian dan dicoba lagi.
- Waktu (`*_at`) dikirim sebagai ISO 8601 UTC, contoh `2026-10-26T03:15:00Z`. Tanggal memakai format `YYYY-MM-DD`.

## Hash password

Ada 2 hash per akun:

| Kegunaan | Algoritma | Catatan |
|---|---|---|
| Login di server | PBKDF2-HMAC-SHA256, 210.000 iterasi | Hanya disimpan di server |
| Login offline di aplikasi | PBKDF2-HMAC-SHA256, 20.000 iterasi, **salt berbeda** | Dikirim ke aplikasi lewat `/auth/offline-users` |

Rumus hash offline (harus sama persis, salt dipakai sebagai teks UTF-8, hasil 32 byte dalam hex huruf kecil):

```python
# Python
hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), iterasi, 32).hex()
```
```csharp
// C#
Convert.ToHexString(Rfc2898DeriveBytes.Pbkdf2(
    Encoding.UTF8.GetBytes(password), Encoding.UTF8.GetBytes(salt),
    iterasi, HashAlgorithmName.SHA256, 32)).ToLowerInvariant();
```

Buat ulang **kedua** hash setiap kali password dibuat atau di-reset.

---

## Health

`GET /health` (tanpa login)
```json
{"status":"ok","app":"arsip-dokumen-pu","server":"FastAPI","version":"1.0.0","agency":"Dinas PUPR ...","time":"..."}
```
`status` wajib `"ok"`. Untuk backend C#, isi `server` dengan `"ASP.NET Core"`.

## Auth

`POST /auth/login`, body `{"username":"budi","password":"..."}`
```json
{"token":"<JWT>","expires_in":43200,
 "user":{"username":"budi","full_name":"Budi Santoso","role":"staff","active":true,"nip":"...","jabatan":"...","last_login":"...","created_at":"..."}}
```
`role`: `admin` | `staff`. Akun nonaktif mendapat jawaban `403`.

`GET /auth/me` → objek `user`.

`POST /auth/change-password`, body `{"old_password":"...","new_password":"... (min 8)"}` → `{"ok":true}`. Buat ulang kedua hash (login & offline). Jawab `401` kalau password lama salah.

`GET /auth/offline-users` (semua user yang login)
```json
{"users":[{"username":"budi","full_name":"Budi Santoso","role":"staff","active":true,
           "offline_salt":"9f..","offline_hash":"4c..","offline_iter":20000},
          {"username":"lama","full_name":"Staf Lama","role":"staff","active":false}]}
```
Akun nonaktif dikirim **tanpa** hash. Akun yang dihapus tidak dikirim, jadi akun itu ikut terhapus dari semua PC saat sinkron.

## Kunci PC (login offline tanpa menunggu ada yang login)

Setiap PC didaftarkan sekali, lalu memakai kuncinya untuk menyalin daftar akun **tiap 5 menit, juga saat masih di layar login**. Dengan begitu admin dan staf (termasuk staf yang baru ditambahkan) tetap bisa login di PC itu ketika server mati.

| Method | Path | Akses | Keterangan |
|---|---|---|---|
| POST | `/devices` | semua user yang login | body `{"name":"NAMA-PC","os":"windows","app_version":"1.1.0"}` → `{"device_id":1,"device_key":"<64 hex>","status":"pending"}`. Kunci hanya dikirim sekali; server menyimpan `sha256(kunci)` |
| GET | `/devices/me` | header `X-Device-Key` (tanpa token) | status PC ini: `{"id","name","status","approval_required","message",...}` — ditampilkan di layar login |
| POST | `/devices/{id}/approve` · `/devices/{id}/reject` | admin | setujui / tolak PC |
| PATCH | `/devices/{id}` | admin | `{"name":"Laptop Pak Budi"}` |
| GET | `/devices/offline-users` | header `X-Device-Key: <kunci>` (**tanpa** token) | jawaban sama dengan `/auth/offline-users`. Kunci salah/dicabut → `401` (aplikasi lalu menghapus akun yang tersimpan di PC itu) |
| GET | `/devices` | admin | `{"devices":[{"id","name","registered_by","created_at","last_seen","last_ip","active"}]}` |
| DELETE | `/devices/{id}` | admin | cabut kunci PC (laptop hilang, PC tidak dipakai) |

Tabel: `devices(id, name, key_hash UNIQUE, registered_by, created_at, last_seen, last_ip, active, status, approved_by, approved_at, os, app_version, last_user)`.

### Persetujuan PC (pengaturan `device_approval`, default AKTIF)
- Aplikasi mengirim header **`X-Device-Key`** di SEMUA permintaan.
- `POST /auth/login` untuk akun **staf**: ditolak `403` (pesan jelas) bila PC belum terdaftar, **menunggu**, ditolak, atau dicabut. Akun **admin** dikecualikan (untuk menghubungkan PC baru & aplikasi Admin Server).
- `GET /auth/offline-users` dari PC yang belum disetujui hanya berisi akun peminta sendiri; `GET /devices/offline-users` menjawab `403` saat menunggu dan `401` saat ditolak/dicabut (aplikasi lalu menghapus akun yang tersimpan).
- PC yang terdaftar sebelum fitur ini ada otomatis dianggap **disetujui**.

## Admin Server (khusus admin — dipakai aplikasi `admin_app`)

| Method | Path | Keterangan |
|---|---|---|
| GET | `/admin/overview` | ringkasan dashboard: member, PC per status, dokumen, proyek, permintaan edit, status email |
| GET | `/admin/settings` | `{device_approval, smtp_host, smtp_port, smtp_security, smtp_user, smtp_password_set, smtp_from_email, smtp_from_name, email_max_mb, email_footer}` (password tidak pernah dikirim) |
| PUT | `/admin/settings` | sebagian dari field di atas + `smtp_password` (kosong = tidak diubah). `smtp_security`: `starttls` / `ssl` / `none` |
| POST | `/admin/email/test` | `{"to":"email@contoh.go.id"}` — kirim email percobaan |

Tabel: `settings(key PRIMARY KEY, value)`.

## Kirim dokumen ke email

`POST /documents/{id}/email` (semua user yang login), body:
```json
{"to":["ppk@pu.go.id"],"cc":["arsip@pu.go.id"],"subject":"(opsional)","message":"(opsional)"}
```
Server melampirkan file asli, menambahkan data dokumen (judul, nomor, tanggal, proyek) di isi email, mengirim lewat SMTP dari `/admin/settings`, dan mencatat `document.email` di log. Jawaban `{"ok":true,"sent_to":[...]}`. Error: `400` (alamat salah / email belum diatur / file terlalu besar), `502` (server SMTP menolak).

## Users (admin)

| Method | Path | Body |
|---|---|---|
| GET | `/users` | jawaban `{"users":[user, ...]}` |
| POST | `/users` | `{"username","full_name","password"(min 8),"role","nip","jabatan"}` → 201 |
| PATCH | `/users/{username}` | sebagian dari `{"full_name","password","role","active","nip","jabatan"}` |
| DELETE | `/users/{username}` | tidak boleh menghapus diri sendiri / admin aktif terakhir |

## Projects (proyek / paket pekerjaan)

`GET /projects` (semua user) → `{"items":[project, ...]}`

`POST /projects` (admin, 201), `PUT /projects/{id}` (admin), `DELETE /projects/{id}` (admin, `409` kalau masih punya dokumen).

```json
{"id":1,"code":"PU-JLN-2026-001","name":"Peningkatan Jalan ...","type":"Jalan","location":"...","year":2026,
 "funding_source":"APBD Kabupaten/Kota","contract_value":4850000000.0,"contractor":"PT ...","supervisor":"CV ...",
 "ppk":"Ir. ...","contract_number":"600/KTR/...","start_date":"2026-03-02","end_date":"2026-11-28",
 "status":"Pelaksanaan","progress":62,"description":""}
```

## Documents

`POST /documents` → **multipart/form-data**, 201

| Field | Keterangan |
|---|---|
| `file` | isi file |
| `client_id` | ID unik buatan aplikasi. **Wajib idempoten**: kalau `client_id` sudah ada, kembalikan dokumen lama + `"duplicate": true` (jangan simpan dua kali) |
| `title`, `doc_number`, `doc_date` (YYYY-MM-DD), `category`, `project_id` ('' = tanpa proyek), `description`, `tags` | metadata |
| `uploaded_by` | username pembuat asli (dokumen dari antrian offline bisa terkirim saat user lain login di PC yang sama). Pakai nilai ini hanya kalau akunnya ada; kalau tidak, pakai user dari token |
| `created_at` | waktu input di PC (ISO UTC) |

Jenis file yang diizinkan: pdf, doc, docx, xls, xlsx, csv, txt, jpg, jpeg, png, bmp, gif, webp, dwg, zip, rar. Batas ukuran default 100 MB.

Kode kategori: `KONTRAK, SPMK, RAB, GAMBAR, ASBUILT, LAP_HARIAN, LAP_MINGGUAN, LAP_BULANAN, MC, FOTO, BA, UJI_MUTU, SURAT, IZIN, KEUANGAN, K3, LAINNYA`.

Objek dokumen:
```json
{"id":15,"client_id":"m2x9k1-a1b2c3d4e5f6","title":"Laporan Mingguan ke-12","doc_number":"...","doc_date":"2026-10-20",
 "category":"LAP_MINGGUAN","project_id":1,"project_code":"PU-JLN-2026-001","project_name":"...",
 "description":"","tags":"aspal, minggu 12","file_name":"lap_mg12.pdf","file_size":482113,"mime":"application/pdf",
 "sha256":"...","uploaded_by":"budi","uploaded_by_name":"Budi Santoso",
 "created_at":"...","uploaded_at":"...","updated_at":"..."}
```

| Method | Path | Keterangan |
|---|---|---|
| GET | `/documents?limit=5000&offset=0&q=&project_id=&category=&year=` | `{"total":N,"items":[doc, ...]}`. Aplikasi mengambil semua metadata lalu menyimpannya di NoSQL lokal untuk pencarian offline |
| GET | `/documents/{id}` | satu dokumen |
| PATCH | `/documents/{id}` | ubah metadata (admin atau pengunggah) |
| GET | `/documents/{id}/file` | unduh isi file |
| DELETE | `/documents/{id}` | admin saja |

## Pencarian pintar

Setelah upload, server membaca isi file di latar belakang (PDF: pypdf, DOCX: XML, XLSX: openpyxl, TXT/CSV). Hasilnya:
`content_text` (teks lengkap) dan `content_tokens` (kata/kode unik huruf kecil dipisah spasi; kode bertitik juga disimpan versi rapatnya, `5.2.2.01` → `52201`). `content_status`: `pending | ok | empty | unsupported | error:...`.

| Method | Path | Keterangan |
|---|---|---|
| GET | `/search-index?since=ISO&since_id=0&limit=1000` | `{"items":[{"id","client_id","tokens","status","indexed_at"}],"next_since","next_since_id","more"}`. Urut `indexed_at, id`. Aplikasi menyimpan token ini untuk pencarian offline |
| GET | `/search?q=...&limit=100` | Pencarian di server (metadata + isi + kamus) → `{"expanded":[[...]],"items":[doc + "score","matched","snippet"]}` |
| GET | `/search-terms` | `{"items":[{"id","term","related","note"}]}`. `related` dipisah koma |
| POST/PUT/DELETE | `/search-terms[/{id}]` | admin, body `{"term","related","note"}` |
| POST | `/admin/reindex` | admin, baca ulang isi semua file → `{"queued":N}` |

## Permintaan edit (staf → admin)

`PATCH /documents/{id}` hanya untuk **admin**. Staf mendapat `403`, dan aplikasi menampilkan tombol "Ajukan Perubahan".

| Method | Path | Keterangan |
|---|---|---|
| POST | `/documents/{id}/edit-requests` | multipart: `reason` (wajib), `changes` (JSON string berisi field yang diubah: title, doc_number, doc_date, category, project_id, description, tags), `file` (opsional, file pengganti). `409` kalau user masih punya permintaan pending untuk dokumen itu |
| GET | `/edit-requests?status=pending|approved|rejected|cancelled|all` | admin: semua, staf: miliknya → `{"pending":N,"items":[request]}` |
| GET | `/edit-requests/{id}/file` | unduh file usulan |
| POST | `/edit-requests/{id}/approve` | admin, `{"note"}` → terapkan perubahan; file lama dipindah ke riwayat versi |
| POST | `/edit-requests/{id}/reject` | admin, `{"note"}` wajib |
| POST | `/edit-requests/{id}/cancel` | pengaju, selama masih pending |
| GET | `/documents/{id}/versions` | `{"current_version":N,"items":[{"id","version_no","file_name","file_size","replaced_at","replaced_by","note"}]}` |
| GET | `/documents/{id}/versions/{vid}/file` | unduh versi lama |

Objek request: `{"id","document_id","document_client_id","document_title","document_file_name","requested_by","requested_by_name","requested_at","reason","changes":{...,"project_label"},"old":{...},"new_file_name","new_file_size","status","reviewed_by_name","reviewed_at","review_note"}`.

Objek dokumen juga memuat `series` (seri / kelompok dokumen, bisa diisi saat upload lewat field multipart `series`, diubah lewat PATCH atau permintaan edit). `GET /series` → `{"items":[{"series","count","first","last"}]}`.

Objek dokumen juga memuat `sha256` & `content_status`. Kalau `sha256` berubah, aplikasi membuang salinan file lokal yang lama.

## Audit & statistik

`GET /audit?limit=500&q=` (admin) → `{"items":[{"at","username","action","detail","ip"}]}`.
Contoh nilai `action`: `login`, `login_failed`, `document.upload|update|download|delete`, `user.create|update|delete`, `project.create|update|delete`.

`GET /stats` → `{"documents","total_bytes","projects","users","by_category":{...}}`

`GET /meta` → `{"categories":[...],"allowed_extensions":[...],"max_upload_bytes":N}`
