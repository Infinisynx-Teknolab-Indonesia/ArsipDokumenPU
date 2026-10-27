"""
Server API Arsip Dokumen PU — FastAPI + MySQL.

Kontrak lengkap ada di ../API.md. Backend C# .NET cukup meniru endpoint & bentuk
JSON yang sama; aplikasi desktop tidak perlu diubah.

Jalankan (tanpa venv):
    D:\\python3.12\\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
Dokumentasi interaktif: http://localhost:8000/docs
"""
# --- Bisa dijalankan langsung:  python app\main.py  (atau  python run.py)
# Import relatif di bawah butuh paket "app", jadi kalau file ini dijalankan langsung,
# folder induknya didaftarkan lalu server dijalankan lewat uvicorn dengan nama paket yang benar.
if __name__ == "__main__":
    import pathlib
    import sys

    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent))
    import uvicorn

    from app.config import HOST, PORT

    uvicorn.run("app.main:app", host=HOST, port=PORT)
    raise SystemExit(0)

import hashlib
import json
import mimetypes
import threading
from contextlib import asynccontextmanager
import re
import secrets
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr, make_msgid
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Annotated

import jwt
from fastapi import BackgroundTasks, Depends, FastAPI, File, Form, Header, HTTPException, Query, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from . import config
from .db import (
    AuditLog, Device, Document, Setting, DocumentVersion, EditRequest, Project, SearchTerm, SessionLocal, User, init_db, utcnow,
)
from .extract import build_tokens, extract_text, snippet
from .security import create_token, decode_token, make_password_fields, verify_password

@asynccontextmanager
async def lifespan(_app: FastAPI):
    _startup()
    yield


app = FastAPI(title="Arsip Dokumen PU API", version=config.APP_VERSION, lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


# --------------------------------------------------------------------------- util


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


DB = Annotated[Session, Depends(get_db)]


def iso(dt: datetime | None) -> str | None:
    """DATETIME (UTC naive) -> ISO 8601 dengan 'Z'."""
    if dt is None:
        return None
    return dt.replace(microsecond=0).isoformat() + "Z"


def iso_date(d: date | None) -> str:
    return d.isoformat() if d else ""


def parse_date(s: str | None) -> date | None:
    if not s:
        return None
    try:
        return date.fromisoformat(s[:10])
    except ValueError:
        raise HTTPException(422, f"Format tanggal salah: {s} (harus YYYY-MM-DD)")


def client_ip(request: Request) -> str:
    fwd = request.headers.get("x-forwarded-for")
    if fwd:
        return fwd.split(",")[0].strip()
    return request.client.host if request.client else ""


def audit(db: Session, request: Request | None, username: str, action: str, detail: str = "") -> None:
    db.add(AuditLog(username=username, action=action, detail=detail[:1000], ip=client_ip(request) if request else ""))


# --------------------------------------------------------------------------- pengaturan server (Admin Server)

SETTING_DEFAULTS = {
    "device_approval": "1",      # 1 = PC baru wajib disetujui admin sebelum staf bisa login
    "smtp_host": "",
    "smtp_port": "587",
    "smtp_security": "starttls",  # starttls | ssl | none
    "smtp_user": "",
    "smtp_password": "",
    "smtp_from_email": "",
    "smtp_from_name": "Arsip Dokumen PU",
    "email_max_mb": "20",
    "email_footer": "",
}


def get_setting(db: Session, key: str) -> str:
    row = db.get(Setting, key)
    return row.value if row is not None else SETTING_DEFAULTS.get(key, "")


def set_setting(db: Session, key: str, value: str) -> None:
    row = db.get(Setting, key)
    if row is None:
        db.add(Setting(key=key, value=value))
    else:
        row.value = value


def device_approval_on(db: Session) -> bool:
    return get_setting(db, "device_approval") == "1"


def _hash_key(key: str) -> str:
    return hashlib.sha256(key.encode()).hexdigest()


def _find_device(db: Session, key: str | None) -> "Device | None":
    if not key:
        return None
    return db.scalar(select(Device).where(Device.key_hash == _hash_key(key)))


def _device_block_reason(dev: "Device | None") -> str | None:
    """None = PC boleh dipakai; selain itu alasan penolakan untuk ditampilkan."""
    if dev is None:
        return ("PC ini belum terdaftar di server. Minta admin menghubungkan PC ini (login administrator → "
                "menu Koneksi Server), lalu menyetujuinya di menu Admin Server → Perangkat (PC).")
    if not dev.active or dev.status == "rejected":
        return f"PC ini (#{dev.id} {dev.name}) DITOLAK / dicabut oleh admin. Hubungi admin server."
    if dev.status != "approved":
        return f"PC ini (#{dev.id} {dev.name}) MENUNGGU PERSETUJUAN admin server. Minta admin menyetujui di menu Admin Server → Perangkat (PC)."
    return None


# --------------------------------------------------------------------------- auth


def current_user(db: DB, authorization: Annotated[str | None, Header()] = None) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "Belum login.")
    try:
        payload = decode_token(authorization.split(" ", 1)[1].strip())
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Sesi berakhir, silakan login ulang.")
    except jwt.PyJWTError:
        raise HTTPException(401, "Token tidak valid.")
    user = db.scalar(select(User).where(User.username == payload.get("sub")))
    if user is None or not user.active:
        raise HTTPException(401, "Akun tidak aktif atau sudah dihapus.")
    return user


CurrentUser = Annotated[User, Depends(current_user)]


def admin_user(user: CurrentUser) -> User:
    if user.role != "admin":
        raise HTTPException(403, "Hanya admin yang boleh melakukan ini.")
    return user


AdminUser = Annotated[User, Depends(admin_user)]


def user_json(u: User) -> dict:
    return {
        "username": u.username,
        "full_name": u.full_name,
        "role": u.role,
        "active": u.active,
        "nip": u.nip,
        "jabatan": u.jabatan,
        "last_login": iso(u.last_login),
        "created_at": iso(u.created_at),
    }


# --------------------------------------------------------------------------- startup


def _startup() -> None:
    init_db()
    with SessionLocal() as db:
        if db.scalar(select(func.count()).select_from(User)) == 0:
            db.add(User(
                username=config.FIRST_ADMIN_USERNAME.lower(),
                full_name=config.FIRST_ADMIN_NAME,
                role="admin",
                active=True,
                **make_password_fields(config.FIRST_ADMIN_PASSWORD),
            ))
            audit(db, None, "system", "user.create", f"Admin pertama dibuat: {config.FIRST_ADMIN_USERNAME}")
            db.commit()
            print(f"[arsip] Admin pertama dibuat: {config.FIRST_ADMIN_USERNAME} / {config.FIRST_ADMIN_PASSWORD} — SEGERA GANTI PASSWORD!")
        if db.scalar(select(func.count()).select_from(SearchTerm)) == 0:
            for term, related, note in DEFAULT_TERMS:
                db.add(SearchTerm(term=term, related=related, note=note))
            db.commit()
    # Data contoh (9 proyek, 2 staf, 50 dokumen) saat database masih kosong
    if config.SEED_DEMO:
        from .demo_data import documents_empty, seed
        if documents_empty():
            print("[arsip] Database kosong -> mengisi 50 dokumen contoh (SEED_DEMO=1)...")
            seed()
    # Index isi file yang belum terbaca (dokumen lama / upload saat server dimatikan)
    threading.Thread(target=index_backlog, daemon=True).start()


# --------------------------------------------------------------------------- health


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "app": "arsip-dokumen-pu",
        "server": "FastAPI",
        "version": config.APP_VERSION,
        "agency": config.AGENCY_NAME,
        "time": iso(utcnow()),
    }


@app.get("/api/meta")
def meta(_: CurrentUser):
    return {
        "categories": config.CATEGORIES,
        "category_labels": config.CATEGORY_LABELS,
        "allowed_extensions": sorted(config.ALLOWED_EXTENSIONS),
        "max_upload_bytes": config.MAX_UPLOAD_BYTES,
    }


# --------------------------------------------------------------------------- login


class LoginIn(BaseModel):
    username: str
    password: str


@app.post("/api/auth/login")
def login(body: LoginIn, request: Request, db: DB, x_device_key: Annotated[str | None, Header()] = None):
    uname = body.username.strip().lower()
    user = db.scalar(select(User).where(User.username == uname))
    if user is None or not verify_password(body.password, user.pw_salt, user.pw_hash, user.pw_iter):
        audit(db, request, uname, "login_failed", "Username/password salah")
        db.commit()
        raise HTTPException(401, "Username atau password salah.")
    if not user.active:
        audit(db, request, uname, "login_failed", "Akun nonaktif")
        db.commit()
        raise HTTPException(403, "Akun ini dinonaktifkan. Hubungi admin.")
    # PC baru wajib disetujui admin. Akun admin dikecualikan (untuk menghubungkan
    # PC baru & membuka menu Admin Server), staf ditolak sampai PC disetujui.
    dev = _find_device(db, x_device_key)
    if user.role != "admin" and device_approval_on(db):
        reason = _device_block_reason(dev)
        if reason:
            audit(db, request, uname, "login_failed", reason[:200])
            db.commit()
            raise HTTPException(403, reason)
    if dev is not None:
        dev.last_user = user.username
        dev.last_seen = utcnow()
        dev.last_ip = client_ip(request)
    user.last_login = utcnow()
    audit(db, request, user.username, "login", "Login berhasil")
    db.commit()
    return {"token": create_token(user.username, user.role), "expires_in": config.JWT_HOURS * 3600, "user": user_json(user)}


@app.get("/api/auth/me")
def me(user: CurrentUser):
    return user_json(user)


class ChangePasswordIn(BaseModel):
    old_password: str
    new_password: str = Field(min_length=8)


@app.post("/api/auth/change-password")
def change_password(body: ChangePasswordIn, user: CurrentUser, request: Request, db: DB):
    if not verify_password(body.old_password, user.pw_salt, user.pw_hash, user.pw_iter):
        raise HTTPException(401, "Password lama salah.")
    for k, v in make_password_fields(body.new_password).items():
        setattr(user, k, v)
    audit(db, request, user.username, "user.update", f"{user.username}: ganti password sendiri")
    db.commit()
    return {"ok": True}


@app.get("/api/auth/offline-users")
def offline_users(user: CurrentUser, db: DB, x_device_key: Annotated[str | None, Header()] = None):
    """Hash offline semua akun, untuk login di aplikasi saat internet mati.
    Akun nonaktif dikirim TANPA hash (supaya ikut terblokir di semua PC)."""
    # PC yang belum disetujui tidak boleh menyimpan akun orang lain (login offline).
    if device_approval_on(db) and _device_block_reason(_find_device(db, x_device_key)):
        return _offline_users_payload(db, only=user.username)
    return _offline_users_payload(db)


# --------------------------------------------------------------------------- devices (kunci PC)


def _offline_users_payload(db: Session, only: str | None = None) -> dict:
    stmt = select(User).order_by(User.username)
    if only:
        stmt = stmt.where(User.username == only)
    users = db.scalars(stmt).all()
    out = []
    for u in users:
        item = {"username": u.username, "full_name": u.full_name, "role": u.role, "active": u.active}
        if u.active:
            item.update({"offline_salt": u.offline_salt, "offline_hash": u.offline_hash, "offline_iter": u.offline_iter})
        out.append(item)
    return {"users": out}


class DeviceIn(BaseModel):
    name: str = ""
    os: str = ""
    app_version: str = ""


@app.post("/api/devices")
def register_device(body: DeviceIn, user: CurrentUser, db: DB, request: Request):
    """Daftarkan PC ini. Kunci hanya dikirim SEKALI; server menyimpan hash-nya."""
    key = secrets.token_hex(32)
    approval = device_approval_on(db)
    dev = Device(
        name=(body.name or "PC").strip()[:128],
        key_hash=_hash_key(key),
        registered_by=user.username,
        last_seen=utcnow(),
        last_ip=client_ip(request),
        os=body.os.strip()[:64],
        app_version=body.app_version.strip()[:32],
        status="pending" if approval else "approved",
        approved_by="" if approval else "(otomatis)",
        approved_at=None if approval else utcnow(),
    )
    db.add(dev)
    db.flush()
    audit(db, request, user.username, "device.register",
          f"PC terdaftar: {dev.name} (#{dev.id}) — {'menunggu persetujuan' if approval else 'disetujui otomatis'}")
    db.commit()
    return {"device_id": dev.id, "device_key": key, "status": dev.status}


def device_json(d: Device) -> dict:
    return {
        "id": d.id, "name": d.name, "registered_by": d.registered_by, "created_at": iso(d.created_at),
        "last_seen": iso(d.last_seen), "last_ip": d.last_ip, "active": d.active,
        "status": d.status if d.active else "revoked", "approved_by": d.approved_by,
        "approved_at": iso(d.approved_at), "os": d.os, "app_version": d.app_version, "last_user": d.last_user,
    }


@app.get("/api/devices/me")
def device_me(db: DB, x_device_key: Annotated[str | None, Header()] = None):
    """Status PC ini (tanpa login) — ditampilkan di layar login aplikasi."""
    dev = _find_device(db, x_device_key)
    if dev is None:
        raise HTTPException(404, "PC tidak dikenal.")
    return {**device_json(dev), "approval_required": device_approval_on(db), "message": _device_block_reason(dev) or ""}


def _device(db: Session, key: str | None) -> Device:
    if not key:
        raise HTTPException(401, "Kunci PC tidak ada.")
    dev = db.scalar(select(Device).where(Device.key_hash == hashlib.sha256(key.encode()).hexdigest()))
    if dev is None or not dev.active or dev.status == "rejected":
        raise HTTPException(401, "Kunci PC tidak berlaku (ditolak/dicabut admin atau tidak dikenal).")
    return dev


@app.get("/api/devices/offline-users")
def device_offline_users(db: DB, request: Request, x_device_key: Annotated[str | None, Header()] = None):
    """Daftar akun (hash offline) untuk PC terdaftar — tanpa perlu login.
    Dipakai aplikasi tiap 5 menit supaya akun baru/berubah ikut tersimpan di PC."""
    dev = _device(db, x_device_key)
    dev.last_seen = utcnow()
    dev.last_ip = client_ip(request)
    db.commit()
    if device_approval_on(db) and dev.status != "approved":
        # 403 (bukan 401): PC menunggu persetujuan, akun belum boleh disalin.
        raise HTTPException(403, _device_block_reason(dev) or "PC belum disetujui.")
    return _offline_users_payload(db)


@app.get("/api/devices")
def list_devices(_: AdminUser, db: DB, status: str = ""):
    rows = db.scalars(select(Device).order_by(Device.id.desc())).all()
    items = [device_json(d) for d in rows]
    if status:
        items = [d for d in items if d["status"] == status]
    return {"devices": items, "approval_required": device_approval_on(db)}


def _get_device(db: Session, device_id: int) -> Device:
    dev = db.get(Device, device_id)
    if dev is None:
        raise HTTPException(404, "PC tidak ditemukan.")
    return dev


@app.post("/api/devices/{device_id}/approve")
def approve_device(device_id: int, admin: AdminUser, db: DB, request: Request):
    dev = _get_device(db, device_id)
    dev.status, dev.active = "approved", True
    dev.approved_by, dev.approved_at = admin.username, utcnow()
    audit(db, request, admin.username, "device.approve", f"PC disetujui: {dev.name} (#{dev.id})")
    db.commit()
    return device_json(dev)


@app.post("/api/devices/{device_id}/reject")
def reject_device(device_id: int, admin: AdminUser, db: DB, request: Request):
    dev = _get_device(db, device_id)
    dev.status = "rejected"
    dev.approved_by, dev.approved_at = admin.username, utcnow()
    audit(db, request, admin.username, "device.reject", f"PC ditolak: {dev.name} (#{dev.id})")
    db.commit()
    return device_json(dev)


class DeviceRename(BaseModel):
    name: str = Field(min_length=1, max_length=128)


@app.patch("/api/devices/{device_id}")
def rename_device(device_id: int, body: DeviceRename, admin: AdminUser, db: DB, request: Request):
    dev = _get_device(db, device_id)
    old = dev.name
    dev.name = body.name.strip()
    audit(db, request, admin.username, "device.rename", f"PC #{dev.id}: {old} → {dev.name}")
    db.commit()
    return device_json(dev)


@app.delete("/api/devices/{device_id}")
def revoke_device(device_id: int, user: AdminUser, db: DB, request: Request):
    """Cabut kunci PC (mis. laptop hilang): akun yang tersimpan di PC itu
    dihapus otomatis saat aplikasi di PC tersebut mencoba sinkron berikutnya."""
    dev = db.get(Device, device_id)
    if dev is None:
        raise HTTPException(404, "PC tidak ditemukan.")
    dev.active = False
    audit(db, request, user.username, "device.revoke", f"Kunci PC dicabut: {dev.name} (#{dev.id})")
    db.commit()
    return {"ok": True}


# --------------------------------------------------------------------------- users

USERNAME_RE = re.compile(r"^[a-z0-9._-]{3,40}$")


class UserCreate(BaseModel):
    username: str
    full_name: str
    password: str = Field(min_length=8)
    role: str = "staff"
    nip: str = ""
    jabatan: str = ""


class UserUpdate(BaseModel):
    full_name: str | None = None
    password: str | None = None
    role: str | None = None
    active: bool | None = None
    nip: str | None = None
    jabatan: str | None = None


@app.get("/api/users")
def list_users(_: AdminUser, db: DB):
    return {"users": [user_json(u) for u in db.scalars(select(User).order_by(User.role, User.username)).all()]}


@app.post("/api/users", status_code=201)
def create_user(body: UserCreate, admin: AdminUser, request: Request, db: DB):
    uname = body.username.strip().lower()
    if not USERNAME_RE.match(uname):
        raise HTTPException(422, "Username 3–40 karakter: huruf kecil, angka, titik, minus, garis bawah.")
    if body.role not in ("admin", "staff"):
        raise HTTPException(422, "Role harus admin atau staff.")
    if db.scalar(select(User).where(User.username == uname)):
        raise HTTPException(409, f"Username {uname} sudah dipakai.")
    u = User(
        username=uname,
        full_name=body.full_name.strip(),
        role=body.role,
        nip=body.nip.strip(),
        jabatan=body.jabatan.strip(),
        active=True,
        **make_password_fields(body.password),
    )
    db.add(u)
    audit(db, request, admin.username, "user.create", f"{uname} ({body.role})")
    db.commit()
    return user_json(u)


def _active_admins(db: Session) -> int:
    return db.scalar(select(func.count()).select_from(User).where(User.role == "admin", User.active.is_(True))) or 0


@app.patch("/api/users/{username}")
def update_user(username: str, body: UserUpdate, admin: AdminUser, request: Request, db: DB):
    u = db.scalar(select(User).where(User.username == username.lower()))
    if u is None:
        raise HTTPException(404, "Akun tidak ditemukan.")
    changes = []
    if body.full_name is not None:
        u.full_name = body.full_name.strip()
        changes.append("nama")
    if body.nip is not None:
        u.nip = body.nip.strip()
    if body.jabatan is not None:
        u.jabatan = body.jabatan.strip()
    if body.role is not None and body.role != u.role:
        if body.role not in ("admin", "staff"):
            raise HTTPException(422, "Role harus admin atau staff.")
        if u.role == "admin" and _active_admins(db) <= 1:
            raise HTTPException(409, "Tidak bisa: ini satu-satunya admin aktif.")
        u.role = body.role
        changes.append(f"role={body.role}")
    if body.active is not None and body.active != u.active:
        if u.username == admin.username:
            raise HTTPException(409, "Tidak bisa menonaktifkan akun sendiri.")
        if not body.active and u.role == "admin" and _active_admins(db) <= 1:
            raise HTTPException(409, "Tidak bisa: ini satu-satunya admin aktif.")
        u.active = body.active
        changes.append("aktif" if body.active else "nonaktif")
    if body.password:
        if len(body.password) < 8:
            raise HTTPException(422, "Password minimal 8 karakter.")
        for k, v in make_password_fields(body.password).items():
            setattr(u, k, v)
        changes.append("reset password")
    audit(db, request, admin.username, "user.update", f"{u.username}: {', '.join(changes) or 'data profil'}")
    db.commit()
    return user_json(u)


@app.delete("/api/users/{username}")
def delete_user(username: str, admin: AdminUser, request: Request, db: DB):
    u = db.scalar(select(User).where(User.username == username.lower()))
    if u is None:
        raise HTTPException(404, "Akun tidak ditemukan.")
    if u.username == admin.username:
        raise HTTPException(409, "Tidak bisa menghapus akun sendiri.")
    if u.role == "admin" and u.active and _active_admins(db) <= 1:
        raise HTTPException(409, "Tidak bisa: ini satu-satunya admin aktif.")
    db.delete(u)
    audit(db, request, admin.username, "user.delete", u.username)
    db.commit()
    return {"ok": True}


# --------------------------------------------------------------------------- projects


class ProjectIn(BaseModel):
    code: str
    name: str
    type: str = "Jalan"
    location: str = ""
    year: int
    funding_source: str = ""
    contract_value: float = 0
    contractor: str = ""
    supervisor: str = ""
    ppk: str = ""
    contract_number: str = ""
    start_date: str = ""
    end_date: str = ""
    status: str = "Perencanaan"
    progress: int = Field(0, ge=0, le=100)
    description: str = ""


def project_json(p: Project) -> dict:
    return {
        "id": p.id,
        "code": p.code,
        "name": p.name,
        "type": p.type,
        "location": p.location,
        "year": p.year,
        "funding_source": p.funding_source,
        "contract_value": float(p.contract_value or 0),
        "contractor": p.contractor,
        "supervisor": p.supervisor,
        "ppk": p.ppk,
        "contract_number": p.contract_number,
        "start_date": iso_date(p.start_date),
        "end_date": iso_date(p.end_date),
        "status": p.status,
        "progress": p.progress,
        "description": p.description or "",
        "updated_at": iso(p.updated_at),
    }


def _apply_project(p: Project, body: ProjectIn) -> None:
    p.code = body.code.strip()
    p.name = body.name.strip()
    p.type = body.type
    p.location = body.location.strip()
    p.year = body.year
    p.funding_source = body.funding_source
    p.contract_value = body.contract_value
    p.contractor = body.contractor.strip()
    p.supervisor = body.supervisor.strip()
    p.ppk = body.ppk.strip()
    p.contract_number = body.contract_number.strip()
    p.start_date = parse_date(body.start_date)
    p.end_date = parse_date(body.end_date)
    p.status = body.status
    p.progress = body.progress
    p.description = body.description


@app.get("/api/projects")
def list_projects(_: CurrentUser, db: DB):
    rows = db.scalars(select(Project).order_by(Project.year.desc(), Project.code)).all()
    return {"items": [project_json(p) for p in rows]}


@app.post("/api/projects", status_code=201)
def create_project(body: ProjectIn, admin: AdminUser, request: Request, db: DB):
    if not body.code.strip() or not body.name.strip():
        raise HTTPException(422, "Kode dan nama paket wajib diisi.")
    if db.scalar(select(Project).where(Project.code == body.code.strip())):
        raise HTTPException(409, f"Kode paket {body.code} sudah ada.")
    p = Project()
    _apply_project(p, body)
    db.add(p)
    audit(db, request, admin.username, "project.create", f"{p.code} {p.name}")
    db.commit()
    return project_json(p)


@app.put("/api/projects/{project_id}")
def update_project(project_id: int, body: ProjectIn, admin: AdminUser, request: Request, db: DB):
    p = db.get(Project, project_id)
    if p is None:
        raise HTTPException(404, "Proyek tidak ditemukan.")
    dup = db.scalar(select(Project).where(Project.code == body.code.strip(), Project.id != project_id))
    if dup:
        raise HTTPException(409, f"Kode paket {body.code} sudah dipakai proyek lain.")
    _apply_project(p, body)
    audit(db, request, admin.username, "project.update", f"{p.code} {p.name} ({p.status}, {p.progress}%)")
    db.commit()
    return project_json(p)


@app.delete("/api/projects/{project_id}")
def delete_project(project_id: int, admin: AdminUser, request: Request, db: DB):
    p = db.get(Project, project_id)
    if p is None:
        raise HTTPException(404, "Proyek tidak ditemukan.")
    n = db.scalar(select(func.count()).select_from(Document).where(Document.project_id == project_id)) or 0
    if n:
        raise HTTPException(409, f"Proyek masih punya {n} dokumen.")
    db.delete(p)
    audit(db, request, admin.username, "project.delete", f"{p.code} {p.name}")
    db.commit()
    return {"ok": True}


# --------------------------------------------------------------------------- documents


def doc_json(d: Document, names: dict[str, str] | None = None) -> dict:
    return {
        "id": d.id,
        "client_id": d.client_id,
        "title": d.title,
        "doc_number": d.doc_number,
        "doc_date": iso_date(d.doc_date),
        "category": d.category,
        "project_id": d.project_id or "",
        "project_code": d.project.code if d.project else "",
        "project_name": d.project.name if d.project else "",
        "description": d.description or "",
        "tags": d.tags,
        "series": d.series or "",
        "file_name": d.file_name,
        "file_size": d.file_size,
        "mime": d.mime,
        "sha256": d.sha256,
        "uploaded_by": d.uploaded_by,
        "uploaded_by_name": (names or {}).get(d.uploaded_by, d.uploaded_by),
        "created_at": iso(d.created_at),
        "uploaded_at": iso(d.uploaded_at),
        "updated_at": iso(d.updated_at),
        "content_status": d.content_status,
    }


def _user_names(db: Session) -> dict[str, str]:
    return {u: n for u, n in db.execute(select(User.username, User.full_name)).all()}


SAFE_NAME_RE = re.compile(r"[^A-Za-z0-9._ -]+")


@app.post("/api/documents", status_code=201)
async def upload_document(
    request: Request,
    user: CurrentUser,
    db: DB,
    background: BackgroundTasks,
    file: UploadFile = File(...),
    client_id: str = Form(...),
    title: str = Form(...),
    category: str = Form(config.DEFAULT_CATEGORY),
    doc_number: str = Form(""),
    doc_date: str = Form(""),
    project_id: str = Form(""),
    description: str = Form(""),
    tags: str = Form(""),
    series: str = Form(""),
    uploaded_by: str = Form(""),
    created_at: str = Form(""),
):
    client_id = client_id.strip()[:64]
    if not client_id:
        raise HTTPException(422, "client_id wajib diisi.")

    # Upload ulang (mis. koneksi putus setelah server menerima) -> kembalikan yang lama.
    existing = db.scalar(select(Document).where(Document.client_id == client_id))
    if existing:
        await file.close()
        return {**doc_json(existing, _user_names(db)), "duplicate": True}

    original = Path(file.filename or "dokumen").name
    ext = original.rsplit(".", 1)[-1].lower() if "." in original else ""
    if ext not in config.ALLOWED_EXTENSIONS:
        raise HTTPException(415, f"Jenis file .{ext} tidak diizinkan.")
    category = config.LEGACY_CATEGORY_MAP.get(category, category)
    if category not in config.CATEGORIES:
        category = config.DEFAULT_CATEGORY

    proj = None
    if project_id.strip():
        try:
            proj = db.get(Project, int(project_id))
        except ValueError:
            proj = None
        if proj is None:
            raise HTTPException(422, "Proyek tidak ditemukan di server.")

    # Pengunggah asli: dokumen yang diantrikan offline bisa terkirim saat user lain
    # sedang login di PC yang sama. Diterima hanya kalau akun itu memang ada.
    owner = user.username
    if uploaded_by and uploaded_by.lower() != user.username:
        if db.scalar(select(User).where(User.username == uploaded_by.lower())):
            owner = uploaded_by.lower()

    created = utcnow()
    if created_at:
        try:
            created = datetime.fromisoformat(created_at.replace("Z", "+00:00")).astimezone(timezone.utc).replace(tzinfo=None)
        except ValueError:
            pass

    safe = SAFE_NAME_RE.sub("_", original)[:150]
    folder = config.STORAGE_DIR / f"{created:%Y}" / f"{created:%m}"
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / f"{re.sub(r'[^A-Za-z0-9_-]', '_', client_id)}_{safe}"

    sha = hashlib.sha256()
    size = 0
    try:
        with open(target, "wb") as out:
            while chunk := await file.read(1024 * 1024):
                size += len(chunk)
                if size > config.MAX_UPLOAD_BYTES:
                    raise HTTPException(413, f"File melebihi batas {config.MAX_UPLOAD_BYTES // (1024 * 1024)} MB.")
                sha.update(chunk)
                out.write(chunk)
    except BaseException:
        target.unlink(missing_ok=True)
        raise
    finally:
        await file.close()

    d = Document(
        client_id=client_id,
        title=(title.strip() or original)[:255],
        doc_number=doc_number.strip()[:128],
        doc_date=parse_date(doc_date),
        category=category,
        project_id=proj.id if proj else None,
        description=description,
        tags=tags.strip()[:512],
        series=series.strip()[:128],
        file_name=original[:255],
        stored_path=str(target.relative_to(config.STORAGE_DIR)),
        file_size=size,
        mime=mimetypes.guess_type(original)[0] or "application/octet-stream",
        sha256=sha.hexdigest(),
        uploaded_by=owner,
        created_at=created,
        uploaded_at=utcnow(),
    )
    db.add(d)
    audit(db, request, user.username, "document.upload",
          f"{d.title} [{category}] {original} ({size} B){' milik ' + owner if owner != user.username else ''}")
    db.commit()
    db.refresh(d)
    background.add_task(index_document, d.id)  # baca isi file untuk pencarian pintar
    return {**doc_json(d, _user_names(db)), "duplicate": False}


@app.get("/api/documents")
def list_documents(
    _: CurrentUser,
    db: DB,
    q: str = "",
    project_id: int | None = None,
    category: str = "",
    year: int | None = None,
    limit: int = Query(5000, ge=1, le=20000),
    offset: int = Query(0, ge=0),
):
    stmt = select(Document)
    if q.strip():
        like = f"%{q.strip()}%"
        stmt = stmt.where(or_(
            Document.title.like(like), Document.doc_number.like(like), Document.description.like(like),
            Document.tags.like(like), Document.file_name.like(like), Document.uploaded_by.like(like),
        ))
    if project_id:
        stmt = stmt.where(Document.project_id == project_id)
    if category:
        stmt = stmt.where(Document.category == category)
    if year:
        stmt = stmt.where(func.extract("year", Document.doc_date) == year)
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(stmt.order_by(Document.created_at.desc()).offset(offset).limit(limit)).unique().all()
    names = _user_names(db)
    return {"total": total, "items": [doc_json(d, names) for d in rows]}


def _get_doc(db: Session, doc_id: int) -> Document:
    d = db.get(Document, doc_id)
    if d is None:
        raise HTTPException(404, "Dokumen tidak ditemukan.")
    return d


@app.get("/api/documents/{doc_id}")
def get_document(doc_id: int, _: CurrentUser, db: DB):
    return doc_json(_get_doc(db, doc_id), _user_names(db))


class DocUpdate(BaseModel):
    title: str | None = None
    doc_number: str | None = None
    doc_date: str | None = None
    category: str | None = None
    project_id: str | int | None = None
    description: str | None = None
    tags: str | None = None
    series: str | None = None


EDITABLE_FIELDS = ("title", "doc_number", "doc_date", "category", "project_id", "description", "tags", "series")


def _doc_meta(d: Document) -> dict:
    """Nilai metadata saat ini (untuk perbandingan di permintaan edit)."""
    return {
        "title": d.title,
        "doc_number": d.doc_number,
        "doc_date": iso_date(d.doc_date),
        "category": d.category,
        "project_id": str(d.project_id or ""),
        "project_label": f"{d.project.code} — {d.project.name}" if d.project else "",
        "description": d.description or "",
        "tags": d.tags,
        "series": d.series or "",
    }


def _apply_doc_changes(db: Session, d: Document, changes: dict) -> list[str]:
    """Terapkan perubahan metadata. Mengembalikan daftar nama field yang berubah."""
    changed = []
    if changes.get("title") is not None:
        title = str(changes["title"]).strip()
        if not title:
            raise HTTPException(422, "Judul tidak boleh kosong.")
        if title != d.title:
            d.title = title[:255]
            changed.append("judul")
    if changes.get("doc_number") is not None and str(changes["doc_number"]).strip() != d.doc_number:
        d.doc_number = str(changes["doc_number"]).strip()[:128]
        changed.append("nomor")
    if changes.get("doc_date") is not None:
        nd = parse_date(str(changes["doc_date"]))
        if nd != d.doc_date:
            d.doc_date = nd
            changed.append("tanggal")
    if changes.get("category") is not None:
        cat = config.LEGACY_CATEGORY_MAP.get(changes["category"], changes["category"])
        cat = cat if cat in config.CATEGORIES else config.DEFAULT_CATEGORY
        if cat != d.category:
            d.category = cat
            changed.append("kategori")
    if changes.get("project_id") is not None:
        pid = str(changes["project_id"]).strip()
        new_pid = None
        if pid:
            proj = db.get(Project, int(pid)) if pid.isdigit() else None
            if proj is None:
                raise HTTPException(422, "Proyek tidak ditemukan.")
            new_pid = proj.id
        if new_pid != d.project_id:
            d.project_id = new_pid
            changed.append("proyek")
    if changes.get("description") is not None and changes["description"] != (d.description or ""):
        d.description = changes["description"]
        changed.append("keterangan")
    if changes.get("tags") is not None and str(changes["tags"]).strip() != d.tags:
        d.tags = str(changes["tags"]).strip()[:512]
        changed.append("tag")
    if changes.get("series") is not None and str(changes["series"]).strip() != (d.series or ""):
        d.series = str(changes["series"]).strip()[:128]
        changed.append("seri")
    return changed


@app.patch("/api/documents/{doc_id}")
def update_document(doc_id: int, body: DocUpdate, user: CurrentUser, request: Request, db: DB):
    """Edit langsung — KHUSUS ADMIN. Staf mengajukan lewat /documents/{id}/edit-requests."""
    d = _get_doc(db, doc_id)
    if user.role != "admin":
        raise HTTPException(403, "Perubahan dokumen yang sudah diarsipkan harus diajukan ke admin (Ajukan Perubahan).")
    changed = _apply_doc_changes(db, d, body.model_dump(exclude_none=True))
    audit(db, request, user.username, "document.update", f"#{d.id} {d.title}: {', '.join(changed) or 'tanpa perubahan'}")
    db.commit()
    db.refresh(d)
    return doc_json(d, _user_names(db))


@app.get("/api/documents/{doc_id}/file")
def download_document(doc_id: int, user: CurrentUser, request: Request, db: DB):
    d = _get_doc(db, doc_id)
    path = (config.STORAGE_DIR / d.stored_path).resolve()
    if config.STORAGE_DIR not in path.parents or not path.exists():
        raise HTTPException(404, "File fisik tidak ditemukan di server.")
    audit(db, request, user.username, "document.download", f"#{d.id} {d.title}")
    db.commit()
    return FileResponse(path, media_type=d.mime, filename=d.file_name)


@app.delete("/api/documents/{doc_id}")
def delete_document(doc_id: int, admin: AdminUser, request: Request, db: DB):
    d = _get_doc(db, doc_id)
    paths = [d.stored_path]
    for v in db.scalars(select(DocumentVersion).where(DocumentVersion.document_id == d.id)).all():
        paths.append(v.stored_path)
        db.delete(v)
    for r in db.scalars(select(EditRequest).where(EditRequest.document_id == d.id)).all():
        if r.new_file_path:
            paths.append(r.new_file_path)
        db.delete(r)
    db.delete(d)
    audit(db, request, admin.username, "document.delete", f"#{d.id} {d.title} ({d.file_name})")
    db.commit()
    for rel in paths:
        _unlink_storage(rel)
    return {"ok": True}


def _unlink_storage(rel: str) -> None:
    path = (config.STORAGE_DIR / rel).resolve()
    if config.STORAGE_DIR in path.parents:
        path.unlink(missing_ok=True)


# --------------------------------------------------------------------------- audit & stats


@app.get("/api/audit")
def audit_log(_: AdminUser, db: DB, q: str = "", limit: int = Query(500, ge=1, le=5000)):
    stmt = select(AuditLog)
    if q.strip():
        like = f"%{q.strip()}%"
        stmt = stmt.where(or_(AuditLog.username.like(like), AuditLog.action.like(like), AuditLog.detail.like(like)))
    rows = db.scalars(stmt.order_by(AuditLog.id.desc()).limit(limit)).all()
    return {"items": [{"at": iso(r.at), "username": r.username, "action": r.action, "detail": r.detail, "ip": r.ip} for r in rows]}


# =========================================================================== Admin Server: pengaturan & email

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


@app.get("/api/admin/settings")
def admin_get_settings(_: AdminUser, db: DB):
    out = {k: get_setting(db, k) for k in SETTING_DEFAULTS if k != "smtp_password"}
    out["smtp_password_set"] = bool(get_setting(db, "smtp_password"))
    out["device_approval"] = out["device_approval"] == "1"
    out["smtp_port"] = int(out["smtp_port"] or 0)
    out["email_max_mb"] = int(out["email_max_mb"] or 20)
    return out


class SettingsIn(BaseModel):
    device_approval: bool | None = None
    smtp_host: str | None = None
    smtp_port: int | None = Field(None, ge=1, le=65535)
    smtp_security: str | None = None
    smtp_user: str | None = None
    smtp_password: str | None = None  # kosong / tidak dikirim = tidak diubah
    smtp_from_email: str | None = None
    smtp_from_name: str | None = None
    email_max_mb: int | None = Field(None, ge=1, le=100)
    email_footer: str | None = None


@app.put("/api/admin/settings")
def admin_put_settings(body: SettingsIn, admin: AdminUser, db: DB, request: Request):
    data = body.model_dump(exclude_none=True)
    if "smtp_security" in data and data["smtp_security"] not in ("starttls", "ssl", "none"):
        raise HTTPException(400, "Keamanan SMTP harus starttls, ssl, atau none.")
    if data.get("smtp_from_email") and not EMAIL_RE.match(data["smtp_from_email"].strip()):
        raise HTTPException(400, "Alamat email pengirim tidak valid.")
    if data.get("smtp_password") == "":
        data.pop("smtp_password")
    for k, v in data.items():
        set_setting(db, k, ("1" if v else "0") if isinstance(v, bool) else str(v).strip() if k != "smtp_password" else str(v))
    changed = ", ".join(k for k in data if k != "smtp_password") + (", smtp_password" if "smtp_password" in data else "")
    audit(db, request, admin.username, "settings.update", f"Pengaturan diubah: {changed}")
    db.commit()
    return admin_get_settings(admin, db)


def _send_email(db: Session, to: list[str], cc: list[str], subject: str, text_body: str, html_body: str | None,
                attachments: list[tuple[str, bytes, str]]) -> None:
    host = get_setting(db, "smtp_host").strip()
    if not host:
        raise HTTPException(400, "Email belum diatur. Admin perlu mengisi pengaturan SMTP di menu Admin Server → Email (SMTP).")
    port = int(get_setting(db, "smtp_port") or 587)
    security = get_setting(db, "smtp_security") or "starttls"
    user = get_setting(db, "smtp_user").strip()
    password = get_setting(db, "smtp_password")
    from_email = get_setting(db, "smtp_from_email").strip() or user
    from_name = get_setting(db, "smtp_from_name").strip() or "Arsip Dokumen PU"
    if not from_email:
        raise HTTPException(400, "Alamat email pengirim belum diatur di menu Admin Server → Email (SMTP).")

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = formataddr((from_name, from_email))
    msg["To"] = ", ".join(to)
    if cc:
        msg["Cc"] = ", ".join(cc)
    msg["Message-ID"] = make_msgid(domain=from_email.split("@")[-1])
    msg.set_content(text_body)
    if html_body:
        msg.add_alternative(html_body, subtype="html")
    for name, data, mime in attachments:
        maintype, _, subtype = (mime or "application/octet-stream").partition("/")
        msg.add_attachment(data, maintype=maintype, subtype=subtype or "octet-stream", filename=name)
    try:
        ctx = ssl.create_default_context()
        if security == "ssl":
            smtp = smtplib.SMTP_SSL(host, port, timeout=30, context=ctx)
        else:
            smtp = smtplib.SMTP(host, port, timeout=30)
        with smtp:
            smtp.ehlo()
            if security == "starttls":
                smtp.starttls(context=ctx)
                smtp.ehlo()
            if user:
                smtp.login(user, password)
            smtp.send_message(msg, from_addr=from_email, to_addrs=to + cc)
    except smtplib.SMTPAuthenticationError:
        raise HTTPException(502, "Login ke server email gagal: username/password SMTP salah (Gmail: pakai App Password).")
    except (smtplib.SMTPException, OSError) as e:
        raise HTTPException(502, f"Gagal mengirim email lewat {host}:{port} — {e}")


class TestEmailIn(BaseModel):
    to: str


@app.post("/api/admin/email/test")
def admin_test_email(body: TestEmailIn, admin: AdminUser, db: DB, request: Request):
    to = body.to.strip()
    if not EMAIL_RE.match(to):
        raise HTTPException(400, "Alamat email tujuan tidak valid.")
    agency = config.AGENCY_NAME
    _send_email(db, [to], [], "Tes email — Arsip Dokumen PU",
                f"Email percobaan dari server Arsip Dokumen PU ({agency}).\nPengaturan SMTP sudah benar.",
                None, [])
    audit(db, request, admin.username, "email.test", f"Tes email ke {to}")
    db.commit()
    return {"ok": True}


class DocEmailIn(BaseModel):
    to: list[str]
    cc: list[str] = []
    subject: str = ""
    message: str = ""


def _clean_emails(items: list[str], label: str) -> list[str]:
    out = []
    for raw in items:
        for part in re.split(r"[,;\s]+", raw or ""):
            p = part.strip()
            if not p:
                continue
            if not EMAIL_RE.match(p):
                raise HTTPException(400, f"Alamat email {label} tidak valid: {p}")
            if p.lower() not in (x.lower() for x in out):
                out.append(p)
    return out


_BULAN = ["Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"]


def _tanggal_id(d: date | None) -> str:
    return f"{d.day} {_BULAN[d.month - 1]} {d.year}" if d else "-"


@app.post("/api/documents/{doc_id}/email")
def email_document(doc_id: int, body: DocEmailIn, user: CurrentUser, db: DB, request: Request):
    """Kirim dokumen (lampiran file asli) ke email. Dicatat di log aktivitas."""
    d = _get_doc(db, doc_id)
    to = _clean_emails(body.to, "tujuan")
    cc = _clean_emails(body.cc, "CC")
    if not to:
        raise HTTPException(400, "Isi minimal satu alamat email tujuan.")
    if len(to) + len(cc) > 20:
        raise HTTPException(400, "Maksimal 20 alamat email sekali kirim.")
    path = (config.STORAGE_DIR / d.stored_path).resolve()
    if config.STORAGE_DIR not in path.parents or not path.exists():
        raise HTTPException(404, "File fisik tidak ditemukan di server.")
    max_mb = int(get_setting(db, "email_max_mb") or 20)
    if path.stat().st_size > max_mb * 1024 * 1024:
        raise HTTPException(400, f"File terlalu besar untuk email (maks {max_mb} MB). Kirim lewat aplikasi saja.")
    project = db.get(Project, d.project_id) if d.project_id else None
    subject = body.subject.strip() or f"[Arsip PU] {d.title}"
    info = [
        ("Judul", d.title), ("Nomor", d.doc_number or "-"), ("Tanggal", _tanggal_id(d.doc_date)),
        ("Proyek", f"{project.code} — {project.name}" if project else "-"), ("File", d.file_name),
    ]
    footer = get_setting(db, "email_footer").strip()
    sender = user.full_name or user.username
    text_body = (body.message.strip() + "\n\n" if body.message.strip() else "") + "\n".join(f"{k}: {v}" for k, v in info) + \
        f"\n\nDikirim oleh {sender} melalui aplikasi Arsip Dokumen PU ({config.AGENCY_NAME})." + (f"\n\n{footer}" if footer else "")
    import html as _html
    rows = "".join(f"<tr><td style='padding:4px 12px 4px 0;color:#666'>{_html.escape(k)}</td><td style='padding:4px 0'><b>{_html.escape(str(v))}</b></td></tr>" for k, v in info)
    msg_html = _html.escape(body.message.strip()).replace("\n", "<br>")
    html_body = (
        f"<div style='font-family:Segoe UI,Arial,sans-serif;font-size:14px;color:#232849'>"
        f"{f'<p>{msg_html}</p>' if msg_html else ''}"
        f"<div style='border:1px solid #D8DAF0;border-radius:10px;padding:14px 16px;background:#F7F8FD'>"
        f"<div style='font-weight:700;color:#5B4FE0;margin-bottom:8px'>📄 Dokumen terlampir</div><table>{rows}</table></div>"
        f"<p style='color:#8A8DAE;font-size:12px'>Dikirim oleh {_html.escape(sender)} melalui aplikasi Arsip Dokumen PU "
        f"({_html.escape(config.AGENCY_NAME)}).{('<br>' + _html.escape(footer)) if footer else ''}</p></div>"
    )
    _send_email(db, to, cc, subject, text_body, html_body, [(d.file_name, path.read_bytes(), d.mime or "application/octet-stream")])
    audit(db, request, user.username, "document.email", f"#{d.id} {d.title} → {', '.join(to + cc)}")
    db.commit()
    return {"ok": True, "sent_to": to + cc}


@app.get("/api/admin/overview")
def admin_overview(_: AdminUser, db: DB):
    """Ringkasan untuk menu Admin Server → Ringkasan Server di aplikasi."""
    devices = db.scalars(select(Device)).all()
    by_status: dict[str, int] = {}
    for dv in devices:
        st = dv.status if dv.active else "revoked"
        by_status[st] = by_status.get(st, 0) + 1
    users = db.scalars(select(User)).all()
    return {
        "users": len(users),
        "users_active": sum(1 for u in users if u.active),
        "admins": sum(1 for u in users if u.role == "admin"),
        "documents": db.scalar(select(func.count()).select_from(Document)) or 0,
        "total_bytes": int(db.scalar(select(func.coalesce(func.sum(Document.file_size), 0))) or 0),
        "projects": db.scalar(select(func.count()).select_from(Project)) or 0,
        "devices": by_status,
        "pending_requests": db.scalar(select(func.count()).select_from(EditRequest).where(EditRequest.status == "pending")) or 0,
        "device_approval": device_approval_on(db),
        "email_configured": bool(get_setting(db, "smtp_host").strip()),
        "server_version": config.APP_VERSION,
        "agency": config.AGENCY_NAME,
    }


@app.get("/api/stats")
def stats(_: CurrentUser, db: DB):
    by_cat = dict(db.execute(select(Document.category, func.count()).group_by(Document.category)).all())
    return {
        "documents": db.scalar(select(func.count()).select_from(Document)) or 0,
        "total_bytes": int(db.scalar(select(func.coalesce(func.sum(Document.file_size), 0))) or 0),
        "projects": db.scalar(select(func.count()).select_from(Project)) or 0,
        "users": db.scalar(select(func.count()).select_from(User)) or 0,
        "by_category": by_cat,
    }


# =========================================================================== pencarian pintar

# Kamus awal (bisa diubah admin di aplikasi: menu Kamus Pencarian).
DEFAULT_TERMS = [
    ("pengeluaran", "belanja, biaya, 544, pembayaran, termin", "Contoh: kode 544 dipakai untuk pengeluaran — sesuaikan dengan kode instansi"),
    ("rab", "rencana anggaran biaya, boq, bill of quantity, hps, engineer estimate", ""),
    ("kontrak", "perjanjian, spk, surat perjanjian, addendum, amandemen", ""),
    ("pho", "provisional hand over, serah terima pertama, bast 1", ""),
    ("fho", "final hand over, serah terima akhir, bast 2", ""),
    ("mc", "mutual check, opname, back up data, mc0, mc100", ""),
    ("aspal", "hotmix, ac-wc, ac-bc, ac-base, lapen, perkerasan lentur", ""),
    ("beton", "rigid, perkerasan kaku, k-350, fc 30, readymix", ""),
    ("jembatan", "girder, abutment, pilar, oprit, gelagar", ""),
    ("drainase", "saluran, gorong-gorong, box culvert, u-ditch", ""),
    ("foto", "dokumentasi, progres 0%, progres 50%, progres 100%", ""),
    ("laporan", "lap, report, harian, mingguan, bulanan", ""),
    ("pembayaran", "termin, uang muka, spp, spm, sp2d, payment", ""),
    # Dua bahasa (Inggris <-> Indonesia) untuk 5 kategori
    ("invoice", "faktur, tagihan, kuitansi, receipt, nota", "Invoices & Receipts / Faktur & Kuitansi"),
    ("contract", "kontrak, agreement, perjanjian, addendum", "Contracts & Agreements / Kontrak & Perjanjian"),
    ("tax", "pajak, ppn, pph, vat, withholding, laporan keuangan, financial report", "Tax & Financial Reports / Pajak & Laporan Keuangan"),
    ("shipment", "pengiriman, bill of lading, packing list, surat jalan, pib, certificate of origin", "Shipments & Trade Dossiers / Pengiriman & Dokumen Dagang"),
    ("minutes", "notulen, rapat, meeting, notulensi", "Meeting Minutes / Notulen Rapat"),
]


def _term_groups(db: Session) -> list[set[str]]:
    groups = []
    for t in db.scalars(select(SearchTerm)).all():
        g = {t.term.strip().lower()} | {x.strip().lower() for x in (t.related or "").split(",") if x.strip()}
        groups.append(g)
    return groups


def expand_query(db: Session, q: str) -> list[set[str]]:
    """Pecah kata kunci; tiap kata diperluas dengan kata/kode terkait dari kamus (dua arah)."""
    groups = _term_groups(db)
    out = []
    for w in [w for w in re.split(r"\s+", q.strip().lower()) if w]:
        variants = {w}
        compact = re.sub(r"[./\-]", "", w)
        if compact != w and compact:
            variants.add(compact)
        for g in groups:
            if w in g:
                variants |= g
        out.append(variants)
    return out


def index_document(doc_id: int) -> None:
    """Baca isi file -> content_text + content_tokens. Dipanggil di background."""
    with SessionLocal() as db:
        d = db.get(Document, doc_id)
        if d is None:
            return
        path = (config.STORAGE_DIR / d.stored_path).resolve()
        ext = d.file_name.rsplit(".", 1)[-1] if "." in d.file_name else ""
        if not path.exists():
            text_, status = "", "error:FileNotFound"
        else:
            text_, status = extract_text(path, ext)
        d.content_text = text_
        d.content_tokens = build_tokens(text_)
        d.content_status = status
        d.indexed_at = utcnow()
        db.commit()


def index_backlog() -> None:
    try:
        with SessionLocal() as db:
            ids = db.scalars(select(Document.id).where(Document.content_status == "pending")).all()
        for i in ids:
            try:
                index_document(i)
            except Exception as e:  # jangan hentikan seluruh antrian
                print(f"[arsip] gagal index dokumen #{i}: {e}")
        if ids:
            print(f"[arsip] {len(ids)} dokumen selesai di-index untuk pencarian isi file.")
    except Exception as e:
        print(f"[arsip] index_backlog: {e}")


@app.post("/api/admin/reindex")
def reindex_all(admin: AdminUser, request: Request, db: DB):
    n = db.query(Document).update({Document.content_status: "pending"})
    audit(db, request, admin.username, "admin.reindex", f"{n} dokumen")
    db.commit()
    threading.Thread(target=index_backlog, daemon=True).start()
    return {"queued": n}


@app.get("/api/search-index")
def search_index(_: CurrentUser, db: DB, since: str = "", since_id: int = 0, limit: int = Query(1000, ge=1, le=5000)):
    """Token isi file per dokumen, bertahap (cursor indexed_at + id). Disalin aplikasi ke
    database lokal supaya pencarian isi file tetap jalan saat offline."""
    stmt = select(Document.id, Document.client_id, Document.content_tokens, Document.content_status, Document.indexed_at).where(
        Document.indexed_at.is_not(None)
    )
    if since:
        try:
            ts = datetime.fromisoformat(since.replace("Z", "+00:00")).astimezone(timezone.utc).replace(tzinfo=None)
        except ValueError:
            raise HTTPException(422, "since tidak valid")
        stmt = stmt.where(or_(Document.indexed_at > ts, (Document.indexed_at == ts) & (Document.id > since_id)))
    rows = db.execute(stmt.order_by(Document.indexed_at, Document.id).limit(limit)).all()
    items = [{"id": r.id, "client_id": r.client_id, "tokens": r.content_tokens or "", "status": r.content_status,
              "indexed_at": iso(r.indexed_at)} for r in rows]
    last = rows[-1] if rows else None
    return {
        "items": items,
        "next_since": iso(last.indexed_at) if last else since,
        "next_since_id": last.id if last else since_id,
        "more": len(rows) == limit,
    }


@app.get("/api/search")
def search(user: CurrentUser, db: DB, q: str, limit: int = Query(100, ge=1, le=500)):
    """Pencarian di server: metadata + ISI FILE + kamus. Mengembalikan skor & cuplikan teks."""
    groups = expand_query(db, q)
    if not groups:
        return {"items": [], "expanded": []}
    stmt = select(Document).options()
    for g in groups:
        conds = []
        for v in g:
            like = f"%{v}%"
            conds += [Document.title.like(like), Document.doc_number.like(like), Document.tags.like(like),
                      Document.description.like(like), Document.file_name.like(like), Document.content_text.like(like),
                      Document.content_tokens.like(like), Document.series.like(like)]
        stmt = stmt.where(or_(*conds))
    rows = db.scalars(stmt.limit(2000)).unique().all()
    names = _user_names(db)
    scored = []
    for d in rows:
        content = (d.content_text or "") + "\n" + (d.content_tokens or "")
        score = 0
        matched = []
        hits: list[str] = []
        for g in groups:
            best = 0
            for v in g:
                for field, w, text_ in (("judul", 10, d.title), ("nomor", 8, d.doc_number), ("tag", 6, d.tags),
                                        ("keterangan", 4, d.description or ""), ("nama file", 3, d.file_name), ("isi file", 2, content)):
                    if v in (text_ or "").lower():
                        val = w if v in (q.lower().split()) else w // 2 or 1
                        if val > best:
                            best = val
                        if field not in matched:
                            matched.append(field)
                        if field == "isi file" and v not in hits:
                            hits.append(v)
            score += best
        scored.append((score, d, matched, hits))
    scored.sort(key=lambda x: (-x[0], -(x[1].id)))
    return {
        "expanded": [sorted(g) for g in groups],
        "items": [{**doc_json(d, names), "score": s, "matched": m, "snippet": snippet(d.content_text or "", h)}
                  for s, d, m, h in scored[:limit]],
    }


class TermIn(BaseModel):
    term: str
    related: str = ""
    note: str = ""


def term_json(t: SearchTerm) -> dict:
    return {"id": t.id, "term": t.term, "related": t.related, "note": t.note, "updated_at": iso(t.updated_at)}


@app.get("/api/search-terms")
def list_terms(_: CurrentUser, db: DB):
    return {"items": [term_json(t) for t in db.scalars(select(SearchTerm).order_by(SearchTerm.term)).all()]}


@app.post("/api/search-terms", status_code=201)
def create_term(body: TermIn, admin: AdminUser, request: Request, db: DB):
    term = body.term.strip().lower()
    if not term:
        raise HTTPException(422, "Istilah wajib diisi.")
    if db.scalar(select(SearchTerm).where(SearchTerm.term == term)):
        raise HTTPException(409, f"Istilah '{term}' sudah ada.")
    t = SearchTerm(term=term, related=body.related.strip(), note=body.note.strip())
    db.add(t)
    audit(db, request, admin.username, "term.create", f"{term}: {t.related}")
    db.commit()
    return term_json(t)


@app.put("/api/search-terms/{term_id}")
def update_term(term_id: int, body: TermIn, admin: AdminUser, request: Request, db: DB):
    t = db.get(SearchTerm, term_id)
    if t is None:
        raise HTTPException(404, "Istilah tidak ditemukan.")
    term = body.term.strip().lower()
    if db.scalar(select(SearchTerm).where(SearchTerm.term == term, SearchTerm.id != term_id)):
        raise HTTPException(409, f"Istilah '{term}' sudah ada.")
    t.term, t.related, t.note = term, body.related.strip(), body.note.strip()
    audit(db, request, admin.username, "term.update", f"{term}: {t.related}")
    db.commit()
    return term_json(t)


@app.delete("/api/search-terms/{term_id}")
def delete_term(term_id: int, admin: AdminUser, request: Request, db: DB):
    t = db.get(SearchTerm, term_id)
    if t is None:
        raise HTTPException(404, "Istilah tidak ditemukan.")
    db.delete(t)
    audit(db, request, admin.username, "term.delete", t.term)
    db.commit()
    return {"ok": True}


# =========================================================================== permintaan edit


async def _save_upload(file: UploadFile, folder: Path, prefix: str) -> tuple[Path, str, int, str]:
    """Simpan UploadFile ke folder. -> (path, nama asli, ukuran, sha256)."""
    original = Path(file.filename or "dokumen").name
    ext = original.rsplit(".", 1)[-1].lower() if "." in original else ""
    if ext not in config.ALLOWED_EXTENSIONS:
        raise HTTPException(415, f"Jenis file .{ext} tidak diizinkan.")
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / f"{prefix}_{SAFE_NAME_RE.sub('_', original)[:150]}"
    sha = hashlib.sha256()
    size = 0
    try:
        with open(target, "wb") as out:
            while chunk := await file.read(1024 * 1024):
                size += len(chunk)
                if size > config.MAX_UPLOAD_BYTES:
                    raise HTTPException(413, f"File melebihi batas {config.MAX_UPLOAD_BYTES // (1024 * 1024)} MB.")
                sha.update(chunk)
                out.write(chunk)
    except BaseException:
        target.unlink(missing_ok=True)
        raise
    finally:
        await file.close()
    return target, original, size, sha.hexdigest()


def _project_label(db: Session, pid: str) -> str:
    if not pid or not str(pid).isdigit():
        return ""
    p = db.get(Project, int(pid))
    return f"{p.code} — {p.name}" if p else ""


def request_json(r: EditRequest, db: Session, names: dict[str, str] | None = None) -> dict:
    names = names if names is not None else _user_names(db)
    changes = json.loads(r.changes_json or "{}")
    if "project_id" in changes:
        changes["project_label"] = _project_label(db, changes["project_id"])
    d = r.document
    return {
        "id": r.id,
        "document_id": r.document_id,
        "document_client_id": d.client_id if d else "",
        "document_title": d.title if d else "(dokumen dihapus)",
        "document_file_name": d.file_name if d else "",
        "requested_by": r.requested_by,
        "requested_by_name": names.get(r.requested_by, r.requested_by),
        "requested_at": iso(r.requested_at),
        "reason": r.reason,
        "changes": changes,
        "old": json.loads(r.old_json or "{}"),
        "new_file_name": r.new_file_name,
        "new_file_size": r.new_file_size,
        "status": r.status,
        "reviewed_by": r.reviewed_by,
        "reviewed_by_name": names.get(r.reviewed_by, r.reviewed_by),
        "reviewed_at": iso(r.reviewed_at),
        "review_note": r.review_note,
    }


@app.post("/api/documents/{doc_id}/edit-requests", status_code=201)
async def create_edit_request(
    doc_id: int,
    request: Request,
    user: CurrentUser,
    db: DB,
    reason: str = Form(...),
    changes: str = Form("{}"),
    file: UploadFile | None = File(None),
):
    """Staf mengajukan perubahan metadata dan/atau file pengganti. Admin menyetujui/menolak."""
    d = _get_doc(db, doc_id)
    if not reason.strip():
        raise HTTPException(422, "Alasan perubahan wajib diisi.")
    try:
        proposed = json.loads(changes or "{}")
        assert isinstance(proposed, dict)
    except Exception:
        raise HTTPException(422, "Format perubahan tidak valid.")
    current = _doc_meta(d)
    diff = {k: v for k, v in proposed.items() if k in EDITABLE_FIELDS and v is not None and str(v) != str(current.get(k, ""))}
    has_file = file is not None and bool(file.filename)
    if not diff and not has_file:
        raise HTTPException(422, "Tidak ada perubahan yang diajukan.")
    if db.scalar(select(EditRequest).where(EditRequest.document_id == d.id, EditRequest.requested_by == user.username,
                                           EditRequest.status == "pending")):
        raise HTTPException(409, "Anda masih punya permintaan yang menunggu untuk dokumen ini.")
    r = EditRequest(document_id=d.id, requested_by=user.username, reason=reason.strip(),
                    changes_json=json.dumps(diff, ensure_ascii=False),
                    old_json=json.dumps({k: current.get(k, "") for k in list(diff) + ["project_label"]}, ensure_ascii=False))
    if has_file:
        target, original, size, _sha = await _save_upload(file, config.STORAGE_DIR / "_requests", f"doc{d.id}_{utcnow():%Y%m%d%H%M%S}")
        r.new_file_name, r.new_file_path, r.new_file_size = original[:255], str(target.relative_to(config.STORAGE_DIR)), size
    db.add(r)
    audit(db, request, user.username, "request.create",
          f"#{d.id} {d.title}: {', '.join(diff) or ''}{' + file ' + r.new_file_name if has_file else ''} — {reason.strip()[:200]}")
    db.commit()
    db.refresh(r)
    return request_json(r, db)


@app.get("/api/edit-requests")
def list_edit_requests(user: CurrentUser, db: DB, status: str = "all", limit: int = Query(500, ge=1, le=5000)):
    stmt = select(EditRequest)
    if user.role != "admin":
        stmt = stmt.where(EditRequest.requested_by == user.username)
    if status != "all":
        stmt = stmt.where(EditRequest.status == status)
    rows = db.scalars(stmt.order_by(EditRequest.id.desc()).limit(limit)).unique().all()
    names = _user_names(db)
    pending = db.scalar(select(func.count()).select_from(EditRequest).where(
        EditRequest.status == "pending", *([] if user.role == "admin" else [EditRequest.requested_by == user.username])
    )) or 0
    return {"pending": pending, "items": [request_json(r, db, names) for r in rows]}


def _get_request(db: Session, req_id: int) -> EditRequest:
    r = db.get(EditRequest, req_id)
    if r is None:
        raise HTTPException(404, "Permintaan tidak ditemukan.")
    return r


@app.get("/api/edit-requests/{req_id}/file")
def edit_request_file(req_id: int, user: CurrentUser, db: DB):
    r = _get_request(db, req_id)
    if user.role != "admin" and r.requested_by != user.username:
        raise HTTPException(403, "Tidak berhak.")
    if not r.new_file_path:
        raise HTTPException(404, "Permintaan ini tidak menyertakan file.")
    path = (config.STORAGE_DIR / r.new_file_path).resolve()
    if config.STORAGE_DIR not in path.parents or not path.exists():
        raise HTTPException(404, "File tidak ditemukan.")
    return FileResponse(path, filename=r.new_file_name)


class ReviewIn(BaseModel):
    note: str = ""


@app.post("/api/edit-requests/{req_id}/approve")
def approve_edit_request(req_id: int, body: ReviewIn, admin: AdminUser, request: Request, db: DB, background: BackgroundTasks):
    r = _get_request(db, req_id)
    if r.status != "pending":
        raise HTTPException(409, f"Permintaan sudah {r.status}.")
    d = r.document
    if d is None:
        raise HTTPException(409, "Dokumen sudah dihapus.")
    changed = _apply_doc_changes(db, d, json.loads(r.changes_json or "{}"))
    reindex = False
    if r.new_file_path:
        src = (config.STORAGE_DIR / r.new_file_path).resolve()
        if not src.exists():
            raise HTTPException(409, "File pengganti hilang dari server.")
        n = (db.scalar(select(func.count()).select_from(DocumentVersion).where(DocumentVersion.document_id == d.id)) or 0) + 1
        db.add(DocumentVersion(document_id=d.id, version_no=n, file_name=d.file_name, stored_path=d.stored_path,
                               file_size=d.file_size, sha256=d.sha256, replaced_by=admin.username, request_id=r.id,
                               note=r.reason[:500]))
        now = utcnow()
        folder = config.STORAGE_DIR / f"{now:%Y}" / f"{now:%m}"
        folder.mkdir(parents=True, exist_ok=True)
        dest = folder / f"{re.sub(r'[^A-Za-z0-9_-]', '_', d.client_id)}_v{n + 1}_{SAFE_NAME_RE.sub('_', r.new_file_name)[:150]}"
        src.replace(dest)
        sha = hashlib.sha256()
        with open(dest, "rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                sha.update(chunk)
        d.file_name = r.new_file_name
        d.stored_path = str(dest.relative_to(config.STORAGE_DIR))
        d.file_size = dest.stat().st_size
        d.sha256 = sha.hexdigest()
        d.mime = mimetypes.guess_type(r.new_file_name)[0] or "application/octet-stream"
        d.content_status = "pending"
        r.new_file_path = ""  # file sudah dipindah jadi file utama
        changed.append(f"file → {r.new_file_name} (versi lama disimpan sebagai v{n})")
        reindex = True
    d.updated_at = utcnow()
    r.status = "approved"
    r.reviewed_by = admin.username
    r.reviewed_at = utcnow()
    r.review_note = body.note.strip()
    audit(db, request, admin.username, "request.approve", f"#{r.id} dok #{d.id} {d.title}: {', '.join(changed) or 'tanpa perubahan'}")
    db.commit()
    if reindex:
        background.add_task(index_document, d.id)
    return request_json(r, db)


@app.post("/api/edit-requests/{req_id}/reject")
def reject_edit_request(req_id: int, body: ReviewIn, admin: AdminUser, request: Request, db: DB):
    r = _get_request(db, req_id)
    if r.status != "pending":
        raise HTTPException(409, f"Permintaan sudah {r.status}.")
    if not body.note.strip():
        raise HTTPException(422, "Tulis alasan penolakan untuk staf.")
    if r.new_file_path:
        _unlink_storage(r.new_file_path)
        r.new_file_path = ""
    r.status = "rejected"
    r.reviewed_by = admin.username
    r.reviewed_at = utcnow()
    r.review_note = body.note.strip()
    audit(db, request, admin.username, "request.reject", f"#{r.id} dok #{r.document_id}: {r.review_note[:200]}")
    db.commit()
    return request_json(r, db)


@app.post("/api/edit-requests/{req_id}/cancel")
def cancel_edit_request(req_id: int, user: CurrentUser, request: Request, db: DB):
    r = _get_request(db, req_id)
    if r.requested_by != user.username:
        raise HTTPException(403, "Hanya pengaju yang bisa membatalkan.")
    if r.status != "pending":
        raise HTTPException(409, f"Permintaan sudah {r.status}.")
    if r.new_file_path:
        _unlink_storage(r.new_file_path)
        r.new_file_path = ""
    r.status = "cancelled"
    audit(db, request, user.username, "request.cancel", f"#{r.id} dok #{r.document_id}")
    db.commit()
    return request_json(r, db)


@app.get("/api/documents/{doc_id}/versions")
def list_versions(doc_id: int, _: CurrentUser, db: DB):
    d = _get_doc(db, doc_id)
    rows = db.scalars(select(DocumentVersion).where(DocumentVersion.document_id == d.id).order_by(DocumentVersion.version_no.desc())).all()
    names = _user_names(db)
    return {
        "current_version": len(rows) + 1,
        "items": [{"id": v.id, "version_no": v.version_no, "file_name": v.file_name, "file_size": v.file_size, "sha256": v.sha256,
                   "replaced_at": iso(v.replaced_at), "replaced_by": names.get(v.replaced_by, v.replaced_by), "note": v.note}
                  for v in rows],
    }


@app.get("/api/documents/{doc_id}/versions/{version_id}/file")
def version_file(doc_id: int, version_id: int, user: CurrentUser, request: Request, db: DB):
    v = db.get(DocumentVersion, version_id)
    if v is None or v.document_id != doc_id:
        raise HTTPException(404, "Versi tidak ditemukan.")
    path = (config.STORAGE_DIR / v.stored_path).resolve()
    if config.STORAGE_DIR not in path.parents or not path.exists():
        raise HTTPException(404, "File versi lama tidak ditemukan.")
    audit(db, request, user.username, "document.download", f"#{doc_id} versi {v.version_no}")
    db.commit()
    return FileResponse(path, filename=v.file_name)


@app.get("/api/series")
def list_series(_: CurrentUser, db: DB):
    """Daftar seri yang sudah dipakai + jumlah dokumen dan rentang tahun (untuk isian otomatis)."""
    rows = db.execute(
        select(Document.series, func.count(), func.min(Document.doc_date), func.max(Document.doc_date))
        .where(Document.series != "").group_by(Document.series).order_by(Document.series)
    ).all()
    return {"items": [{"series": s, "count": n, "first": iso_date(a), "last": iso_date(b)} for s, n, a, b in rows]}
