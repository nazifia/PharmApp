"""
Production settings — MySQL, DEBUG off, strict security.
Required environment variables:
  DJANGO_SECRET_KEY    — long random secret key
  DATABASE_URL         — mysql://user:password@host:3306/dbname
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

ALLOWED_HOSTS = [h.strip() for h in os.environ.get("DJANGO_ALLOWED_HOSTS", "").split(",") if h.strip()]
if not ALLOWED_HOSTS:
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
            "ssl_disabled": False,
        },
        "CONN_MAX_AGE": 60,
    }
}

# ── Static files (WhiteNoise) ─────────────────────────────────────────────────

STATIC_ROOT = os.path.join(BASE_DIR, "staticfiles")
STORAGES = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "pharmapi.storage.CompressedNoManifestStorage",
    },
}

# Insert WhiteNoise after SecurityMiddleware
MIDDLEWARE.insert(1, "whitenoise.middleware.WhiteNoiseMiddleware")  # type: ignore[name-defined]  # noqa: F405

# ── CORS ──────────────────────────────────────────────────────────────────────

_cors_origins = [o.strip() for o in os.environ.get("CORS_ALLOWED_ORIGINS", "").split(",") if o.strip()]
if not _cors_origins:
    raise ImproperlyConfigured("CORS_ALLOWED_ORIGINS environment variable is required and must be non-empty in production.")
CORS_ALLOWED_ORIGINS = _cors_origins
CORS_ALLOW_CREDENTIALS = True

from corsheaders.defaults import default_headers  # noqa: E402
CORS_ALLOW_HEADERS = [
    *default_headers,
    "skip_auth",
    "skip-auth",
]

# ── Security headers ──────────────────────────────────────────────────────────

SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000          # 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = "strict-origin-when-cross-origin"
X_FRAME_OPTIONS = "DENY"

# ── Logging ───────────────────────────────────────────────────────────────────

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {
            "format": "{levelname} {asctime} {module} {process:d} {thread:d} {message}",
            "style": "{",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "verbose",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": "WARNING",
    },
    "loggers": {
        "django": {
            "handlers": ["console"],
            "level": "WARNING",
            "propagate": False,
        },
        "django.security": {
            "handlers": ["console"],
            "level": "ERROR",
            "propagate": False,
        },
    },
}


# Static files                                                                                                                                
STATIC_URL = '/static/'

CSRF_TRUSTED_ORIGINS = _cors_origins

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

CONN_HEALTH_CHECKS = True

SECURE_BROWSER_XSS_FILTER = True