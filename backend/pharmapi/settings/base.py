"""
Base settings shared by all environments.
Do NOT run with this file directly — use dev.py or prod.py.
"""
import os
from datetime import timedelta
from pathlib import Path

# backend/
BASE_DIR = Path(__file__).resolve().parent.parent.parent

# ── Jazzmin Admin UI ──────────────────────────────────────────────────────────

JAZZMIN_SETTINGS = {
    # ── Branding ──────────────────────────────────────────────────────────────
    "site_title": "PharmApp Admin",
    "site_header": "PharmApp",
    "site_brand": "PharmApp",
    "site_logo": None,
    "login_logo": None,
    "welcome_sign": "PharmApp — Pharmacy Management System",
    "copyright": "PharmApp &copy; 2026. All rights reserved.",
    "site_logo_classes": "img-circle elevation-3",
    "login_logo_classes": "img-fluid",

    # ── Search ────────────────────────────────────────────────────────────────
    "search_model": ["authapp.Organization", "authapp.PharmUser", "inventory.Item", "customers.Customer", "pos.Sale"],

    # ── Top bar ───────────────────────────────────────────────────────────────
    "topmenu_links": [
        {"name": "Dashboard", "url": "admin:index", "permissions": ["auth.view_user"]},
        # Superuser-only global overview — shows cross-org analytics
        {"name": "🌐 Global Overview", "url": "/admin/overview/", "permissions": ["authapp.view_organization"]},
        {"name": "API Docs", "url": "/api/", "new_window": True},
        {"model": "authapp.PharmUser"},
        {"app": "inventory"},
    ],

    # ── User menu (top right) ─────────────────────────────────────────────────
    "usermenu_links": [
        {"name": "Support", "url": "#", "icon": "fas fa-life-ring"},
        {"model": "authapp.PharmUser"},
    ],

    # ── Sidebar ───────────────────────────────────────────────────────────────
    "show_sidebar": True,
    "navigation_expanded": True,
    "hide_apps": [],
    "hide_models": [],
    "order_with_respect_to": [
        "authapp",
        "inventory",
        "customers",
        "pos",
        "auth",
    ],

    "custom_links": {
        "pos": [
            {
                "name": "Monthly Report",
                "url": "/api/reports/sales/?period=month",
                "icon": "fas fa-chart-bar",
                "permissions": ["pos.view_sale"],
            },
        ],
    },

    # ── Icons (FontAwesome 5 free) ─────────────────────────────────────────────
    "icons": {
        "authapp":   "fas fa-users-cog",
        "inventory": "fas fa-pills",
        "customers": "fas fa-user-friends",
        "pos":       "fas fa-cash-register",
        "auth":      "fas fa-shield-alt",

        "authapp.PharmUser":           "fas fa-user-md",
        "authapp.Organization":        "fas fa-hospital",

        "inventory.Item":              "fas fa-capsules",

        "customers.Customer":          "fas fa-user-friends",
        "customers.WalletTransaction": "fas fa-wallet",

        "pos.Cashier":            "fas fa-user-tie",
        "pos.Sale":               "fas fa-receipt",
        "pos.SaleItem":           "fas fa-list-alt",
        "pos.DispensingLog":      "fas fa-clipboard-list",
        "pos.PaymentRequest":     "fas fa-hand-holding-usd",
        "pos.ReceiptPayment":     "fas fa-credit-card",
        "pos.ReturnRecord":       "fas fa-undo-alt",
        "pos.ExpenseCategory":    "fas fa-tags",
        "pos.Expense":            "fas fa-file-invoice-dollar",
        "pos.Supplier":           "fas fa-truck",
        "pos.Procurement":        "fas fa-shopping-cart",
        "pos.ProcurementItem":    "fas fa-box",
        "pos.StockCheck":         "fas fa-tasks",
        "pos.StockCheckItem":     "fas fa-check-square",
        "pos.Notification":       "fas fa-bell",
        "pos.TransferRequest":    "fas fa-exchange-alt",

        "auth.Group": "fas fa-layer-group",
    },
    "default_icon_parents": "fas fa-chevron-circle-right",
    "default_icon_children": "fas fa-circle",

    # ── UI tweaks ──────────────────────────────────────────────────────────────
    "related_modal_active": True,
    "custom_css": "admin/css/custom_admin.css",
    "custom_js": None,
    "use_google_fonts_cdn": True,
    "show_ui_builder": False,

    "changeform_format": "horizontal_tabs",
    "changeform_format_overrides": {
        "authapp.pharmuser": "collapsible",
        "pos.sale": "horizontal_tabs",
        "pos.procurement": "horizontal_tabs",
        "pos.stockcheck": "horizontal_tabs",
    },

    "language_chooser": False,
}

JAZZMIN_UI_TWEAKS = {
    "navbar_small_text": False,
    "footer_small_text": False,
    "body_small_text": False,
    "brand_small_text": False,
    "brand_colour": "navbar-teal",
    "accent": "accent-teal",
    "navbar": "navbar-dark",
    "no_navbar_border": True,
    "navbar_fixed": True,
    "layout_boxed": False,
    "footer_fixed": False,
    "sidebar_fixed": True,
    "sidebar": "sidebar-dark-teal",
    "sidebar_nav_small_text": False,
    "sidebar_disable_expand": False,
    "sidebar_nav_child_indent": True,
    "sidebar_nav_compact_style": False,
    "sidebar_nav_legacy_style": False,
    "sidebar_nav_flat_style": False,
    "theme": "superhero",
    "dark_mode_theme": "superhero",
    "button_classes": {
        "primary":   "btn-primary",
        "secondary": "btn-secondary",
        "info":      "btn-info",
        "warning":   "btn-warning",
        "danger":    "btn-danger",
        "success":   "btn-success",
    },
    "actions_sticky_top": True,
}

# ── Templates ─────────────────────────────────────────────────────────────────

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

# ── Apps & Middleware ──────────────────────────────────────────────────────────

INSTALLED_APPS = [
    "jazzmin",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "rest_framework_simplejwt",
    "corsheaders",
    "authapp",
    "inventory",
    "customers",
    "pos",
    "reports",
    "subscription",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "authapp.middleware.MaintenanceModeMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "pharmapi.urls"
AUTH_USER_MODEL = "authapp.PharmUser"
WSGI_APPLICATION = "pharmapi.wsgi.application"

# ── REST Framework ─────────────────────────────────────────────────────────────

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 50,
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": "100/day",
        "user": "2000/day",
        "auth": "10/minute",
    },
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(hours=12),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ALGORITHM": "HS256",
    "AUTH_HEADER_TYPES": ("Bearer",),
}

# ── CORS ──────────────────────────────────────────────────────────────────────

CORS_ALLOW_ALL_ORIGINS = False

# ── Static files ──────────────────────────────────────────────────────────────

STATIC_URL = "/static/"
STATICFILES_DIRS = [BASE_DIR / "static"]

# ── Misc ──────────────────────────────────────────────────────────────────────

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_TZ = True
