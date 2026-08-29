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

# The Flutter client's custom headers must be listed here or the browser
# preflight blocks the request. `skip_auth` is not among them: AuthInterceptor
# strips it before the request leaves the app, so it never reaches the wire.
from corsheaders.defaults import default_headers  # noqa: E402

CORS_ALLOW_HEADERS = [
    *default_headers,
    "x-prescriber-token",
    # Replayed offline writes carry this; without it the browser preflight
    # blocks every queued checkout and mutation on web.
    "idempotency-key",
]
