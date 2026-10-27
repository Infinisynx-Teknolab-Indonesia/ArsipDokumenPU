"""Hash password (PBKDF2-SHA256) dan token JWT."""
import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

import jwt

from .config import JWT_HOURS, JWT_SECRET, LOGIN_ITERATIONS, OFFLINE_ITERATIONS


def pbkdf2_hex(password: str, salt: str, iterations: int) -> str:
    """Sama persis dengan pbkdf2Sha256Hex() di aplikasi Flutter (salt dipakai sebagai teks UTF-8)."""
    return hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), iterations, 32).hex()


def make_password_fields(password: str) -> dict:
    """Field hash untuk tabel users: login server + hash offline terpisah."""
    pw_salt = secrets.token_hex(16)
    off_salt = secrets.token_hex(16)
    return {
        "pw_salt": pw_salt,
        "pw_hash": pbkdf2_hex(password, pw_salt, LOGIN_ITERATIONS),
        "pw_iter": LOGIN_ITERATIONS,
        "offline_salt": off_salt,
        "offline_hash": pbkdf2_hex(password, off_salt, OFFLINE_ITERATIONS),
        "offline_iter": OFFLINE_ITERATIONS,
    }


def verify_password(password: str, salt: str, expected_hex: str, iterations: int) -> bool:
    return hmac.compare_digest(pbkdf2_hex(password, salt, iterations), expected_hex)


def create_token(username: str, role: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {"sub": username, "role": role, "iat": now, "exp": now + timedelta(hours=JWT_HOURS)}
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


def decode_token(token: str) -> dict:
    return jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
