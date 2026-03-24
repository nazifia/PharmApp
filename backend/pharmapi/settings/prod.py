"""
Production settings — MySQL, DEBUG off, strict security.
Required environment variables:
  DJANGO_SECRET_KEY   — long random secret key
  DATABASE_URL        — mysql://user:password@host:3306/dbname
  DJANGO_ALLOWED_HOSTS — comma-separated hostnames (e.g. api.mypharmapp.com)
  CORS_ALLOWED_ORIGINS — comma-separated origins  (e.g. https://mypharmapp.com)
"""
import os
import urllib.parse
from django.core.exceptions import ImproperlyConfigured
from .base import *  # noqa: F401, F403

# ── Core ──────────────────────────────────────────────────────────────────────

DEBUG = False

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY")
if not SECRET_KEY:
    raise ImproperlyConfigured("DJANGO_SECRET_KEY environment variable is required in production.")

ALLOWED_HOSTS = os.environ.get("DJANGO_ALLOWED_HOSTS", "").split(",")
if not any(ALLOWED_HOSTS):
    raise ImproperlyConfigured("DJANGO_ALLOWED_HOSTS environment variable is required in production.")

# ── Database: MySQL ───────────────────────────────────────────────────────────

_db_url = os.environ.get("DATABASE_URL")
if not _db_url:
    raise ImproperlyConfigured("DATABASE_URL environment variable is required in production.")

_parsed = urllib.parse.urlparse(_db_url)
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.mysql",
        "NAME": _parsed.path.lstrip("/"),
        "USER": _parsed.username,
        "PASSWORD": _parsed.password,
        "HOST": _parsed.hostname,
        "PORT": str(_parsed.port or 3306),
        "OPTIONS": {
            "charset": "utf8mb4",
            "init_command": "SET sql_mode='STRICT_TRANS_TABLES'",
        },
        "CONN_MAX_AGE": 60,
    }
}

# ── CORS ──────────────────────────────────────────────────────────────────────

CORS_ALLOWED_ORIGINS = os.environ.get("CORS_ALLOWED_ORIGINS", "").split(",")

# ── Security headers ──────────────────────────────────────────────────────────

SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000          # 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_CONTENT_TYPE_NOSNIFF = True
