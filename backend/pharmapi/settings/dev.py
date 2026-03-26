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

# ── CORS: allow all origins in dev ───────────────────────────────────────────
# Flutter web uses a dynamic port (flutter run -d chrome picks any free port),
# so we can't enumerate every origin. Allow all in dev — safe since DEBUG=True.

CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True

# The Flutter client sends a custom `skip_auth` header on public endpoints.
# It must be explicitly listed or the browser CORS preflight blocks the POST.
from corsheaders.defaults import default_headers  # noqa: E402

CORS_ALLOW_HEADERS = [
    *default_headers,
    "skip_auth",
    "skip-auth",
]
