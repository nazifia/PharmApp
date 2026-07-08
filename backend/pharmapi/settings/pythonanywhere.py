"""
PythonAnywhere free-tier settings — SQLite, DEBUG off.
Required environment variables (set in WSGI file):
  DJANGO_SECRET_KEY    — long random secret key
  DJANGO_ALLOWED_HOSTS — comma-separated hostnames
  CORS_ALLOWED_ORIGINS — comma-separated origins
"""
import os
from pathlib import Path
from django.core.exceptions import ImproperlyConfigured
from .base import *  # noqa: F401, F403

# ── Core ──────────────────────────────────────────────────────────────────────

DEBUG = False

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY")
if not SECRET_KEY:
    raise ImproperlyConfigured("DJANGO_SECRET_KEY environment variable is required.")

ALLOWED_HOSTS = [h.strip() for h in os.environ.get("DJANGO_ALLOWED_HOSTS", "").split(",") if h.strip()]
if not ALLOWED_HOSTS:
    raise ImproperlyConfigured("DJANGO_ALLOWED_HOSTS environment variable is required.")

# ── Database: SQLite (free tier) ──────────────────────────────────────────────

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
        # Persistent connection — skip reopen per request.
        "CONN_MAX_AGE": 60,
        # WAL + tuned PRAGMAs: concurrent reads during writes, 64MB page cache,
        # memory temp store. Biggest single speedup for SQLite on shared tier.
        "OPTIONS": {
            "transaction_mode": "IMMEDIATE",
            "init_command": (
                "PRAGMA journal_mode=WAL;"
                "PRAGMA synchronous=NORMAL;"
                "PRAGMA cache_size=-64000;"
                "PRAGMA temp_store=MEMORY;"
                "PRAGMA busy_timeout=5000;"
            ),
        },
    }
}

# ── Cache + sessions ──────────────────────────────────────────────────────────
# Local-memory cache (single worker on free tier). Sessions read from cache,
# write-through to DB — cuts one SQLite hit off every authenticated request.

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
        "LOCATION": "pharmapp-locmem",
    }
}
SESSION_ENGINE = "django.contrib.sessions.backends.cached_db"

# ── Static files (WhiteNoise) ─────────────────────────────────────────────────

STATIC_ROOT = BASE_DIR / "staticfiles"
STATIC_URL = "/static/"
STORAGES = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "pharmapi.storage.CompressedNoManifestStorage",
    },
}

MIDDLEWARE.insert(1, "whitenoise.middleware.WhiteNoiseMiddleware")  # noqa: F405

# Cache static (Jazzmin CSS/JS) 1 day in the browser — refresh/nav reuse them
# instead of re-fetching. Assets are unhashed, so keep it modest, not immutable.
WHITENOISE_MAX_AGE = 86400

# ── CORS ──────────────────────────────────────────────────────────────────────

_cors_origins = [o.strip() for o in os.environ.get("CORS_ALLOWED_ORIGINS", "").split(",") if o.strip()]
if not _cors_origins:
    raise ImproperlyConfigured("CORS_ALLOWED_ORIGINS environment variable is required.")
CORS_ALLOWED_ORIGINS = _cors_origins
CORS_ALLOW_CREDENTIALS = True

from corsheaders.defaults import default_headers  # noqa: E402
CORS_ALLOW_HEADERS = [
    *default_headers,
    "skip_auth",
    "skip-auth",
    "x-prescriber-token",
]

# ── Security ──────────────────────────────────────────────────────────────────

# PythonAnywhere terminates SSL at their proxy — don't redirect internally
SECURE_SSL_REDIRECT = False
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = "strict-origin-when-cross-origin"
X_FRAME_OPTIONS = "DENY"
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_BROWSER_XSS_FILTER = True

CSRF_TRUSTED_ORIGINS = _cors_origins
