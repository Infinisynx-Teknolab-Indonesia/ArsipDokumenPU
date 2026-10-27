"""Atur ulang / buat akun ADMIN di server (kalau lupa password admin).

Cara pakai (dari folder ArsipDokumenPU_Server, MySQL harus menyala):

    D:\\python3.12\\python.exe reset_admin.py
        -> akun admin / Admin@12345 (dibuat kalau belum ada, password direset,
           diaktifkan lagi, dijadikan admin)

    D:\\python3.12\\python.exe reset_admin.py administrator administrator
        -> akun administrator / administrator

Setelah itu login di aplikasi dengan akun tersebut, lalu segera ganti password
di menu Profil Saya.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from sqlalchemy import select  # noqa: E402

from app import config  # noqa: E402
from app.db import SessionLocal, User, init_db  # noqa: E402
from app.security import make_password_fields  # noqa: E402


def main() -> None:
    username = (sys.argv[1] if len(sys.argv) > 1 else config.FIRST_ADMIN_USERNAME).strip().lower()
    password = sys.argv[2] if len(sys.argv) > 2 else config.FIRST_ADMIN_PASSWORD
    if not username or not password:
        raise SystemExit("Username dan password tidak boleh kosong.")
    init_db()
    with SessionLocal() as db:
        user = db.scalar(select(User).where(User.username == username))
        fields = make_password_fields(password)
        if user is None:
            user = User(username=username, full_name=config.FIRST_ADMIN_NAME, role="admin", active=True, **fields)
            db.add(user)
            action = "dibuat"
        else:
            for k, v in fields.items():
                setattr(user, k, v)
            user.role = "admin"
            user.active = True
            action = "direset"
        db.commit()
    print(f"[arsip] Akun admin {action}: {username} / {password}")
    print("[arsip] Login di aplikasi dengan akun ini, lalu segera ganti password di menu Profil Saya.")


if __name__ == "__main__":
    main()
