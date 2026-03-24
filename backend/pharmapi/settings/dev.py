"""
Development settings — SQLite, DEBUG on, relaxed security.
Used automatically by manage.py.
"""
from .base import *  # noqa: F401, F403

# ── Core ──────────────────────────────────────────────────────────────────────

DEBUG = True
SECRET_KEY = "pharmapp-dev-secret-key-not-for-production"
ALLOWED_HOSTS = ["*"]

# ── Database: SQLite ──────────────────────────────────────────────────────────

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
    }
}

# ── CORS: allow all local origins in dev ─────────────────────────────────────

CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:8080",
    "http://127.0.0.1:8080",
    "http://10.0.2.2:8080",
]
