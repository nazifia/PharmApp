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
    }
}

# ── Static files (WhiteNoise) ─────────────────────────────────────────────────

STATIC_ROOT = BASE_DIR / "staticfiles"
STATIC_URL = "/static/"
STORAGES = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}

MIDDLEWARE.insert(1, "whitenoise.middleware.WhiteNoiseMiddleware")  # noqa: F405

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

CSRF_TRUSTED_ORIGINS = _cors_origins
