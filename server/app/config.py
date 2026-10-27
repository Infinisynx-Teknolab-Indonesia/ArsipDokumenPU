"""Pengaturan server dari file .env (lihat .env.example)."""
import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "mysql+pymysql://arsip:arsip_pu_2026@localhost:3306/arsip_pu?charset=utf8mb4",
)
# Akun ADMIN MySQL (mis. root XAMPP, password kosong) — dipakai SEKALI untuk membuat
# database & user aplikasi secara otomatis kalau belum ada. Kosongkan kalau tidak perlu.
MYSQL_ADMIN_URL = os.getenv("MYSQL_ADMIN_URL", "mysql+pymysql://root:@localhost:3306")

# 1 = isi 9 proyek, 2 akun staf, dan 50 dokumen contoh saat database masih kosong.
SEED_DEMO = os.getenv("SEED_DEMO", "1").strip().lower() in ("1", "true", "ya", "yes")

JWT_SECRET = os.getenv("JWT_SECRET", "ganti-dengan-teks-acak-yang-panjang-sekali-1234567890")
JWT_HOURS = int(os.getenv("JWT_HOURS", "12"))

_storage = Path(os.getenv("STORAGE_DIR", "./storage"))
STORAGE_DIR = _storage if _storage.is_absolute() else (BASE_DIR / _storage).resolve()
STORAGE_DIR.mkdir(parents=True, exist_ok=True)

AGENCY_NAME = os.getenv("AGENCY_NAME", "Dinas Pekerjaan Umum dan Penataan Ruang")
FIRST_ADMIN_USERNAME = os.getenv("FIRST_ADMIN_USERNAME", "admin")
FIRST_ADMIN_PASSWORD = os.getenv("FIRST_ADMIN_PASSWORD", "Admin@12345")
FIRST_ADMIN_NAME = os.getenv("FIRST_ADMIN_NAME", "Admin Arsip")
MAX_UPLOAD_BYTES = int(os.getenv("MAX_UPLOAD_MB", "100")) * 1024 * 1024

APP_VERSION = "1.0.0"

# Alamat & port server (dipakai saat dijalankan dengan  python run.py  /  python app\main.py)
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))

ALLOWED_EXTENSIONS = {
    "pdf", "doc", "docx", "xls", "xlsx", "csv", "txt",
    "jpg", "jpeg", "png", "bmp", "gif", "webp", "dwg", "zip", "rar",
}

CATEGORIES = [
    "KONTRAK", "SPMK", "RAB", "GAMBAR", "ASBUILT", "LAP_HARIAN", "LAP_MINGGUAN", "LAP_BULANAN",
    "MC", "FOTO", "BA", "UJI_MUTU", "SURAT", "IZIN", "KEUANGAN", "K3", "LAINNYA",
]

# Iterasi PBKDF2: login di server (kuat) & hash offline untuk aplikasi (lebih ringan,
# dihitung di PC staf saat login offline).
LOGIN_ITERATIONS = 210_000
OFFLINE_ITERATIONS = 20_000
