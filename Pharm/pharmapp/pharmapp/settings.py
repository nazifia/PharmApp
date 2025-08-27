import os
import shutil
from django.contrib import messages
from decouple import config
from pathlib import Path

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/5.1/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = 'django-insecure-745$ysi)dtow@&h&g9%um@8m-7#8)xkva&4r1q4vx_mpg3pg&3'

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

# ALLOWED_HOSTS = []
ALLOWED_HOSTS = ['localhost', '127.0.0.1', 'testserver']


# Application definition

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    'whitenoise.runserver_nostatic',
    'django.contrib.humanize',
    'django_htmx',
    'crispy_forms',  # Removed - using simple HTML/CSS instead
    'crispy_bootstrap5',  # Removed - using simple HTML/CSS instead
    # 'channels',  # Add channels for WebSocket support (temporarily disabled)
    'store',
    'userauth',
    'customer',
    'wholesale',
    'supplier',
    'chat',
    'notebook',  # Add notebook app for note-taking functionality
    'corsheaders',  # Make sure this is here

    "pwa",
    "webpush",
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    # Re-enable essential middleware
    'pharmapp.middleware.ConnectionDetectionMiddleware',
    'pharmapp.middleware.OfflineMiddleware',
    'userauth.middleware.ActivityMiddleware',  # Add ActivityMiddleware to log user actions
    'userauth.middleware.RoleBasedAccessMiddleware',  # Add role-based access control
    'userauth.middleware.AutoLogoutMiddleware',  # Add auto-logout functionality
    # Session security middleware
    'userauth.session_middleware.SessionValidationMiddleware',  # Session validation for security
    'userauth.session_middleware.UserActivityTrackingMiddleware',  # Track user activity per session
    'userauth.session_middleware.SessionCleanupMiddleware',  # Clean up expired sessions
    # User isolation middleware (temporarily disabled for testing)
    # 'userauth.user_isolation_middleware.UserIsolationMiddleware',  # Ensure user data isolation
    # 'userauth.user_isolation_middleware.UserSessionIsolationMiddleware',  # Session isolation
    # 'userauth.user_isolation_middleware.UserActivityIsolationMiddleware',  # Activity isolation
]

# CORS settings
CORS_ALLOWED_ORIGINS = [
    "capacitor://localhost",
    "http://localhost",
    "http://localhost:8000",
]

CORS_ALLOW_METHODS = [
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'OPTIONS'
]

STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

ROOT_URLCONF = 'pharmapp.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [os.path.join(BASE_DIR, 'templates')],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'store.context_processors.marquee_context',
                'userauth.context_processors.user_roles',
                "pharmapp.context_processors.vapid_public_key",
            ],
        },
    },
]

WSGI_APPLICATION = 'pharmapp.wsgi.application'
# ASGI_APPLICATION = 'pharmapp.asgi.application'

# Channel layers configuration for WebSocket support (temporarily disabled)
# CHANNEL_LAYERS = {
#     'default': {
#         'BACKEND': 'channels_redis.core.RedisChannelLayer',
#         'CONFIG': {
#             "hosts": [('127.0.0.1', 6379)],
#         },
#     },
# }


# Database
# https://docs.djangoproject.com/en/5.1/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    },
    'offline': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'offline.sqlite3',
    }
}

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.db.DatabaseCache',
        'LOCATION': 'cache_table',
        'OPTIONS': {
            'MAX_ENTRIES': 1000,
            'CULL_FREQUENCY': 3,
        }
    }
}

# Database routing settings
DATABASE_ROUTERS = ['pharmapp.routers.OfflineRouter']


# Password validation
# https://docs.djangoproject.com/en/5.1/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# Internationalization
# https://docs.djangoproject.com/en/5.1/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'Africa/Lagos'

USE_I18N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/5.1/howto/static-files/

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_DIRS = [
    os.path.join(BASE_DIR, 'static'),
]

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR /'media'

AUTH_USER_MODEL = 'userauth.User'

# Authentication backends
# AUTHENTICATION_BACKENDS = [
#     'userauth.backends.MobileBackend',  # Custom mobile authentication
#     'django.contrib.auth.backends.ModelBackend',  # Default backend as fallback
# ]


# --- PWA CONFIG ---
PWA_APP_NAME = "PHARMAPP"
PWA_APP_DESCRIPTION = "A Django PWA with Push Notifications"
PWA_APP_THEME_COLOR = "#2196f3"
PWA_APP_BACKGROUND_COLOR = "#ffffff"
PWA_APP_DISPLAY = "standalone"
PWA_APP_SCOPE = "/"
PWA_APP_ORIENTATION = "any"
PWA_APP_START_URL = "/"
PWA_APP_STATUS_BAR_COLOR = "default"
PWA_APP_ICONS = [
    {"src": "/static/icons/icon-192x192.png", "sizes": "192x192"},
    {"src": "/static/icons/icon-512x512.png", "sizes": "512x512"},
]
PWA_SERVICE_WORKER_PATH = os.path.join(BASE_DIR, "static/js", "serviceworker.js")

# --- WEBPUSH CONFIG ---
WEBPUSH_SETTINGS = {
    "VAPID_PUBLIC_KEY": config("VAPID_PUBLIC_KEY"),
    "VAPID_PRIVATE_KEY": config("VAPID_PRIVATE_KEY"),
    "VAPID_ADMIN_EMAIL": config("VAPID_ADMIN_EMAIL", default="nazzsankira@gmail.com"),
}



# Add to your settings.py for offline-mode
# PWA_SERVICE_WORKER_PATH = os.path.join(BASE_DIR, 'static', 'js', 'sw.js')
PWA_APP_NAME = 'PharmApp'
PWA_APP_DESCRIPTION = "Pharmacy Management System"
PWA_APP_THEME_COLOR = '#4285f4'
PWA_APP_BACKGROUND_COLOR = '#ffffff'
PWA_APP_DISPLAY = 'standalone'
PWA_APP_SCOPE = '/'
PWA_APP_START_URL = '/'
PWA_APP_STATUS_BAR_COLOR = 'default'


# Default primary key field type
# https://docs.djangoproject.com/en/5.1/ref/settings/#default-auto-field

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'


# Bootstrap Messages class configuration
MESSAGE_TAGS = {
    messages.SUCCESS: 'success',
    messages.INFO: 'info',
    messages.WARNING: 'warning',
    messages.ERROR: 'danger',
}



# Session Security Settings
SESSION_COOKIE_AGE = 1200  # 20 minutes in seconds
SESSION_SAVE_EVERY_REQUEST = True  # Reset the session expiration time on each request
SESSION_EXPIRE_AT_BROWSER_CLOSE = True  # Session expires when browser closes
SESSION_COOKIE_SECURE = False  # Set to True in production with HTTPS
SESSION_COOKIE_HTTPONLY = True  # Prevent JavaScript access to session cookies
SESSION_COOKIE_SAMESITE = 'Lax'  # CSRF protection
SESSION_ENGINE = 'django.contrib.sessions.backends.db'  # Use database sessions for better isolation

# Auto logout settings
AUTO_LOGOUT_DELAY = 20  # Auto logout after 20 minutes of inactivity

# Additional security settings for session isolation
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'



# Authentication settings
LOGIN_URL = 'store:index'  # Update this to match your login URL pattern
LOGIN_REDIRECT_URL = 'store:index'
LOGOUT_REDIRECT_URL = 'store:index'


# Allow more form fields
DATA_UPLOAD_MAX_NUMBER_FIELDS = 10000

# Crispy Forms Configuration
CRISPY_ALLOWED_TEMPLATE_PACKS = "bootstrap5"
CRISPY_TEMPLATE_PACK = "bootstrap5"


# def copy_index_html(sender, **kwargs):
#     """Copy capacitor_index.html to staticfiles/index.html after collectstatic"""
#     source = os.path.join(BASE_DIR, 'templates', 'capacitor_index.html')
#     dest = os.path.join(BASE_DIR, 'staticfiles', 'index.html')
#     if os.path.exists(source):
#         shutil.copy2(source, dest)

# from django.core.signals import static_files_copied
# static_files_copied.connect(copy_index_html)
