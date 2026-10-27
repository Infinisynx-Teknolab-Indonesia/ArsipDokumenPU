"""Koneksi database + model tabel (SQLAlchemy 2.0). Tabel dibuat otomatis."""
from datetime import date, datetime, timezone

from sqlalchemy import (
    BigInteger, Boolean, Date, DateTime, ForeignKey, Integer, Numeric, String, Text, create_engine, inspect, text,
)
from sqlalchemy.dialects.mysql import LONGTEXT
from sqlalchemy.engine import make_url
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, sessionmaker

from .config import DATABASE_URL, MYSQL_ADMIN_URL

def ensure_database() -> None:
    """INSTAL DATABASE OTOMATIS (MySQL/MariaDB).

    1. Coba konek dengan user aplikasi (DATABASE_URL). Berhasil -> selesai.
    2. Database belum ada -> coba buat dengan user aplikasi.
    3. User aplikasi belum ada / tidak berhak -> pakai MYSQL_ADMIN_URL (mis. root XAMPP)
       untuk membuat database + user + hak akses.
    Tabel-tabelnya dibuat setelah ini oleh init_db().
    """
    url = make_url(DATABASE_URL)
    if not url.drivername.startswith("mysql"):
        return
    import pymysql

    db_name = url.database
    host, port = url.host or "localhost", url.port or 3306
    user, password = url.username or "", url.password or ""

    def connect(u: str, p: str, database: str | None = None):
        return pymysql.connect(host=host, port=port, user=u, password=p, database=database, charset="utf8mb4", connect_timeout=8)

    try:
        connect(user, password, db_name).close()
        return  # sudah siap
    except pymysql.err.OperationalError as e:
        code = e.args[0] if e.args else 0
        if code == 2003:
            raise SystemExit(
                f"[arsip] MySQL tidak bisa dihubungi di {host}:{port}. Pastikan MySQL/MariaDB (mis. XAMPP) sudah berjalan."
            ) from e
        first_error = e

    # 2) database belum ada, user ada & berhak membuat database
    if first_error.args and first_error.args[0] == 1049:
        try:
            with connect(user, password) as c, c.cursor() as cur:
                cur.execute(f"CREATE DATABASE IF NOT EXISTS `{db_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
            print(f"[arsip] Database '{db_name}' dibuat otomatis.")
            return
        except pymysql.err.MySQLError:
            pass

    # 3) pakai akun admin MySQL
    if not MYSQL_ADMIN_URL:
        raise SystemExit(f"[arsip] Tidak bisa konek ke database '{db_name}' sebagai '{user}': {first_error}. "
                         "Isi MYSQL_ADMIN_URL di .env supaya database dibuat otomatis, atau jalankan setup_mysql.sql.")
    adm = make_url(MYSQL_ADMIN_URL)
    try:
        conn = pymysql.connect(host=adm.host or host, port=adm.port or port, user=adm.username or "root",
                               password=adm.password or "", charset="utf8mb4", connect_timeout=8)
    except pymysql.err.MySQLError as e:
        raise SystemExit(f"[arsip] Gagal login sebagai admin MySQL ({adm.username}@{adm.host}): {e}. "
                         "Periksa MYSQL_ADMIN_URL di .env (XAMPP: root tanpa password).") from e
    pw = password.replace("'", "''")
    with conn, conn.cursor() as cur:
        cur.execute(f"CREATE DATABASE IF NOT EXISTS `{db_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
        for h in ("localhost", "127.0.0.1", "%"):
            cur.execute(f"CREATE USER IF NOT EXISTS '{user}'@'{h}' IDENTIFIED BY '{pw}'")
            cur.execute(f"GRANT ALL PRIVILEGES ON `{db_name}`.* TO '{user}'@'{h}'")
        cur.execute("FLUSH PRIVILEGES")
    print(f"[arsip] Database '{db_name}' dan user '{user}' dibuat otomatis memakai akun admin MySQL.")


_engine_kwargs = {"pool_pre_ping": True}
if DATABASE_URL.startswith("mysql"):
    _engine_kwargs["pool_recycle"] = 3600
engine = create_engine(DATABASE_URL, **_engine_kwargs)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def utcnow() -> datetime:
    """Waktu UTC tanpa tzinfo (disimpan apa adanya di MySQL DATETIME)."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


class Base(DeclarativeBase):
    pass


# TEXT biasa di MySQL maks 64 KB -> isi dokumen pakai LONGTEXT (SQLite tetap TEXT)
BigText = Text().with_variant(LONGTEXT(), "mysql")


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    username: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    full_name: Mapped[str] = mapped_column(String(128))
    nip: Mapped[str] = mapped_column(String(32), default="")
    jabatan: Mapped[str] = mapped_column(String(128), default="")
    role: Mapped[str] = mapped_column(String(16), default="staff")  # admin | staff
    active: Mapped[bool] = mapped_column(Boolean, default=True)

    # hash login server (PBKDF2-SHA256, iterasi tinggi)
    pw_salt: Mapped[str] = mapped_column(String(64))
    pw_hash: Mapped[str] = mapped_column(String(128))
    pw_iter: Mapped[int] = mapped_column(Integer)

    # hash TERPISAH untuk login offline di aplikasi (salt berbeda, iterasi lebih ringan)
    offline_salt: Mapped[str] = mapped_column(String(64))
    offline_hash: Mapped[str] = mapped_column(String(128))
    offline_iter: Mapped[int] = mapped_column(Integer)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    last_login: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class Project(Base):
    __tablename__ = "projects"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    code: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(255))
    type: Mapped[str] = mapped_column(String(64), default="Jalan")
    location: Mapped[str] = mapped_column(String(255), default="")
    year: Mapped[int] = mapped_column(Integer, index=True)
    funding_source: Mapped[str] = mapped_column(String(64), default="")
    contract_value: Mapped[float] = mapped_column(Numeric(18, 2), default=0)
    contractor: Mapped[str] = mapped_column(String(255), default="")
    supervisor: Mapped[str] = mapped_column(String(255), default="")
    ppk: Mapped[str] = mapped_column(String(255), default="")
    contract_number: Mapped[str] = mapped_column(String(128), default="")
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[str] = mapped_column(String(64), default="Perencanaan")
    progress: Mapped[int] = mapped_column(Integer, default=0)
    description: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow, onupdate=utcnow)


class Document(Base):
    __tablename__ = "documents"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    client_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)  # anti-duplikat upload ulang
    title: Mapped[str] = mapped_column(String(255))
    doc_number: Mapped[str] = mapped_column(String(128), default="")
    doc_date: Mapped[date | None] = mapped_column(Date, nullable=True, index=True)
    category: Mapped[str] = mapped_column(String(32), default="LAINNYA", index=True)
    project_id: Mapped[int | None] = mapped_column(ForeignKey("projects.id"), nullable=True, index=True)
    description: Mapped[str] = mapped_column(Text, default="")
    tags: Mapped[str] = mapped_column(String(512), default="")
    # Seri / kelompok dokumen: menyatukan dokumen yang sama dari tahun ke tahun
    # (mis. "Dokumen 1" berisi Formula A 2000, Formula B 2002, Formula C 2026)
    series: Mapped[str] = mapped_column(String(128), default="", index=True)
    file_name: Mapped[str] = mapped_column(String(255))
    stored_path: Mapped[str] = mapped_column(String(512))
    file_size: Mapped[int] = mapped_column(BigInteger, default=0)
    mime: Mapped[str] = mapped_column(String(128), default="application/octet-stream")
    sha256: Mapped[str] = mapped_column(String(64), default="")
    uploaded_by: Mapped[str] = mapped_column(String(64), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)  # waktu input di PC
    uploaded_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)  # waktu masuk server
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow, onupdate=utcnow)

    # Pencarian pintar: teks hasil ekstraksi isi file + daftar kata/kode unik
    content_text: Mapped[str | None] = mapped_column(BigText, nullable=True, deferred=True)
    content_tokens: Mapped[str | None] = mapped_column(BigText, nullable=True, deferred=True)
    content_status: Mapped[str] = mapped_column(String(48), default="pending")  # pending|ok|empty|unsupported|error:..
    indexed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True, index=True)

    project: Mapped[Project | None] = relationship(lazy="joined")


class DocumentVersion(Base):
    """File lama yang diganti lewat permintaan edit yang disetujui (riwayat versi)."""
    __tablename__ = "document_versions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    document_id: Mapped[int] = mapped_column(ForeignKey("documents.id", ondelete="CASCADE"), index=True)
    version_no: Mapped[int] = mapped_column(Integer)
    file_name: Mapped[str] = mapped_column(String(255))
    stored_path: Mapped[str] = mapped_column(String(512))
    file_size: Mapped[int] = mapped_column(BigInteger, default=0)
    sha256: Mapped[str] = mapped_column(String(64), default="")
    replaced_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    replaced_by: Mapped[str] = mapped_column(String(64), default="")
    request_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    note: Mapped[str] = mapped_column(String(512), default="")


class EditRequest(Base):
    """Permintaan perubahan dokumen dari staf, menunggu persetujuan admin."""
    __tablename__ = "edit_requests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    document_id: Mapped[int] = mapped_column(ForeignKey("documents.id", ondelete="CASCADE"), index=True)
    requested_by: Mapped[str] = mapped_column(String(64), index=True)
    requested_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    reason: Mapped[str] = mapped_column(Text, default="")
    changes_json: Mapped[str] = mapped_column(Text, default="{}")  # field metadata yang diusulkan
    old_json: Mapped[str] = mapped_column(Text, default="{}")      # nilai saat diajukan (untuk perbandingan)
    new_file_name: Mapped[str] = mapped_column(String(255), default="")
    new_file_path: Mapped[str] = mapped_column(String(512), default="")
    new_file_size: Mapped[int] = mapped_column(BigInteger, default=0)
    status: Mapped[str] = mapped_column(String(16), default="pending", index=True)  # pending|approved|rejected|cancelled
    reviewed_by: Mapped[str] = mapped_column(String(64), default="")
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    review_note: Mapped[str] = mapped_column(Text, default="")

    document: Mapped[Document] = relationship(lazy="joined")


class SearchTerm(Base):
    """Kamus pencarian: istilah <-> kata/kode terkait (mis. pengeluaran <-> 544, belanja)."""
    __tablename__ = "search_terms"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    term: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    related: Mapped[str] = mapped_column(Text, default="")  # dipisah koma
    note: Mapped[str] = mapped_column(String(255), default="")
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow, onupdate=utcnow)


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    at: Mapped[datetime] = mapped_column(DateTime, default=utcnow, index=True)
    username: Mapped[str] = mapped_column(String(64), default="", index=True)
    action: Mapped[str] = mapped_column(String(64))
    detail: Mapped[str] = mapped_column(String(1024), default="")
    ip: Mapped[str] = mapped_column(String(64), default="")


class Device(Base):
    """PC yang terdaftar ke server. Kunci PC dipakai aplikasi untuk menyalin
    daftar akun (hash offline) secara berkala, juga saat belum ada yang login,
    supaya admin & staf tetap bisa login di PC itu ketika server mati."""
    __tablename__ = "devices"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(128), default="")
    key_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)  # sha256(kunci)
    registered_by: Mapped[str] = mapped_column(String(64), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    last_seen: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    last_ip: Mapped[str] = mapped_column(String(64), default="")
    active: Mapped[bool] = mapped_column(Boolean, default=True)  # False = dicabut admin
    # Persetujuan admin: pending (baru) | approved (boleh dipakai) | rejected (ditolak)
    status: Mapped[str] = mapped_column(String(16), default="pending", index=True)
    approved_by: Mapped[str] = mapped_column(String(64), default="")
    approved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    os: Mapped[str] = mapped_column(String(64), default="")
    app_version: Mapped[str] = mapped_column(String(32), default="")
    last_user: Mapped[str] = mapped_column(String(64), default="")


class Setting(Base):
    """Pengaturan server yang diubah lewat aplikasi Admin Server (SMTP email,
    persetujuan PC, dll.) — key/value."""
    __tablename__ = "settings"

    key: Mapped[str] = mapped_column(String(64), primary_key=True)
    value: Mapped[str] = mapped_column(Text, default="")


def init_db() -> None:
    ensure_database()
    Base.metadata.create_all(engine)
    _auto_migrate()


def _auto_migrate() -> None:
    """Tambah kolom baru ke tabel lama (database dari versi sebelumnya) tanpa menghapus data."""
    insp = inspect(engine)
    mysql = engine.dialect.name == "mysql"
    wanted = {
        "documents": {
            "content_text": "LONGTEXT NULL" if mysql else "TEXT",
            "content_tokens": "LONGTEXT NULL" if mysql else "TEXT",
            "content_status": "VARCHAR(48) NOT NULL DEFAULT 'pending'",
            "indexed_at": "DATETIME NULL",
            "series": "VARCHAR(128) NOT NULL DEFAULT ''",
        },
        # PC yang sudah terdaftar sebelum ada fitur persetujuan -> dianggap disetujui
        "devices": {
            "status": "VARCHAR(16) NOT NULL DEFAULT 'approved'",
            "approved_by": "VARCHAR(64) NOT NULL DEFAULT ''",
            "approved_at": "DATETIME NULL",
            "os": "VARCHAR(64) NOT NULL DEFAULT ''",
            "app_version": "VARCHAR(32) NOT NULL DEFAULT ''",
            "last_user": "VARCHAR(64) NOT NULL DEFAULT ''",
        },
    }
    with engine.begin() as conn:
        for table, cols in wanted.items():
            existing = {c["name"] for c in insp.get_columns(table)}
            for col, ddl in cols.items():
                if col not in existing:
                    conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {col} {ddl}"))
