"""Jalankan server Arsip Dokumen PU.

    D:\\python3.12\\python.exe run.py

Sama dengan:  python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
(HOST dan PORT bisa diubah di file .env)
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import uvicorn  # noqa: E402

from app.config import HOST, PORT  # noqa: E402

if __name__ == "__main__":
    print(f"Server Arsip Dokumen PU: http://localhost:{PORT}/api  (dokumentasi: http://localhost:{PORT}/docs)")
    uvicorn.run("app.main:app", host=HOST, port=PORT)
