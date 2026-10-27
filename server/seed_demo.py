"""Isi data contoh secara manual: 9 proyek, akun staf (budi/sari), dan 50 dokumen
(PDF, Word, Excel, TXT, foto) tahun 2000-2026, sebagian saling berhubungan.

    D:\\python3.12\\python.exe seed_demo.py

Aman dijalankan berulang: data yang sudah ada dilewati.
(Server juga mengisinya otomatis saat database kosong bila SEED_DEMO=1 di .env.)
"""
from app.db import init_db
from app.demo_data import seed

if __name__ == "__main__":
    init_db()
    seed()
    print("Selesai.")
