# PharmApp

Pharmacy Management System — Flutter frontend + Django REST backend.
Multi-tenant SaaS: one deployment, multiple isolated pharmacy organisations.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Backend Setup](#backend-setup)
3. [Admin Site](#admin-site)
   - [Platform Superuser (Software Owner)](#platform-superuser-software-owner)
   - [Org-Admin User (Pharmacy Admin)](#org-admin-user-pharmacy-admin)
   - [Global Overview Dashboard](#global-overview-dashboard)
4. [Multi-Tenancy Model](#multi-tenancy-model)
5. [Flutter Setup](#flutter-setup)
6. [Environment Variables](#environment-variables)
7. [Build & Deploy](#build--deploy)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│  Flutter App  (Android · iOS · Web · Windows)                │
│  Auth: JWT   |  API: Dio → Django REST                       │
└──────────────────────────┬───────────────────────────────────┘
                           │ HTTPS
┌──────────────────────────▼───────────────────────────────────┐
│  Django REST API  (pharmapi)                                 │
│  /api/auth/   /api/inventory/   /api/customers/              │
│  /api/pos/    /api/reports/                                  │
│                                                              │
│  Admin site: /admin/                                         │
│    ├── Platform superuser  → sees ALL organisations          │
│    └── Org admin           → sees OWN organisation only      │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────┐
│  MySQL (production)  /  SQLite (development)                 │
└──────────────────────────────────────────────────────────────┘
```

---

## Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Development
python manage.py migrate
python manage.py runserver 8000
```

---

## Admin Site

The Django admin (`/admin/`) supports two distinct access levels:

| Level | `is_superuser` | `organization` | Sees |
|-------|---------------|----------------|------|
| Platform superuser | ✅ True | None (not needed) | All organisations |
| Org admin | ❌ False | Set to their org | Their org only |

---

### Platform Superuser (Software Owner)

A platform superuser has full, unrestricted access to every organisation's
data and to the Global Overview dashboard.

**Using the management command (recommended):**

```bash
python manage.py create_admin_user --superuser --phone 08000000000 --password "S3cur3P@ss!"
```

**Interactive (prompts securely):**

```bash
python manage.py create_admin_user --superuser
```

**Django shell (manual):**

```bash
python manage.py shell -c "
from authapp.models import PharmUser
PharmUser.objects.create_superuser(phone_number='08000000000', password='S3cur3P@ss!')
"
```

---

### Org-Admin User (Pharmacy Admin)

An org-admin can log into `/admin/` and manage only their own pharmacy's data —
inventory, customers, sales, expenses, users, etc. They cannot see other organisations
or access Site Configuration.

**Using the management command (recommended):**

```bash
# First, find the organisation slug
python manage.py shell -c "
from authapp.models import Organization
for o in Organization.objects.all():
    print(o.slug, '-', o.name)
"

# Create the org admin
python manage.py create_admin_user --org-slug=green-valley-pharmacy --phone 08011111111 --password "OrgPass123!"
```

**Interactive (prompts securely):**

```bash
python manage.py create_admin_user --org-slug=green-valley-pharmacy
```

**Django shell (manual):**

```bash
python manage.py shell -c "
from authapp.models import PharmUser, Organization
org  = Organization.objects.get(slug='green-valley-pharmacy')
user = PharmUser.objects.create_user(phone_number='08011111111', password='OrgPass123!', role='Admin')
user.is_staff     = True
user.organization = org
user.save()
print('Done —', user, 'scoped to', org)
"
```

---

### Global Overview Dashboard

Platform superusers can access a cross-organisation analytics dashboard at:

```
/admin/overview/
```

The dashboard shows:

- **Platform totals** — organisations, users, items, customers, sales, revenue, expenses
- **Per-org breakdown table** — users, inventory health, customers, completed sales,
  revenue, expenses, net, last sale date — sortable by revenue
- **Quick-access links** — directly filter any org's users / items / sales in admin
- **Recently registered organisations**

The link appears in the Jazzmin top navigation bar as **🌐 Global Overview**
(visible only to users with `view_organization` permission, i.e. superusers).

---

## Multi-Tenancy Model

Every major model (`Item`, `Customer`, `Sale`, `Expense`, `Supplier`, etc.) carries
an `organization` ForeignKey. The admin isolation is enforced by `OrgScopedAdminMixin`
(`authapp/admin_mixins.py`):

| Behaviour | Superuser | Org admin |
|-----------|-----------|-----------|
| `get_queryset` | All rows | Org rows only |
| `save_model` | Manual | Auto-sets `organization` |
| FK dropdowns | All choices | Own-org choices only |
| List filters | Incl. org filter | Org filter hidden |
| Organisation admin page | Visible | Hidden |
| Site Config page | Visible | Hidden |
| Global Overview | Visible | Hidden |

---

## Flutter Setup

```bash
cd pharmapp
flutter pub get

# Development (connect to local backend)
flutter run -d chrome                          # Web
flutter run -d emulator-5554                  # Android emulator

# Production build (set API URL at build time)
flutter build apk --dart-define=API_URL=https://api.yourpharmapp.com
flutter build web  --dart-define=API_URL=https://api.yourpharmapp.com
flutter build windows
```

### Android Release Signing

1. Generate a keystore (one-time):
   ```bash
   keytool -genkey -v -keystore android/app/pharmapp-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias pharmapp
   ```

2. Create `android/key.properties` (**never commit this file**):
   ```properties
   storePassword=<your-keystore-password>
   keyPassword=<your-key-password>
   keyAlias=pharmapp
   storeFile=pharmapp-release.jks
   ```

3. Build the release APK:
   ```bash
   flutter build apk --release --dart-define=API_URL=https://api.yourpharmapp.com
   ```

---

## Environment Variables

### Backend (production)

| Variable | Description | Example |
|----------|-------------|---------|
| `DJANGO_SECRET_KEY` | Long random string | `openssl rand -hex 50` |
| `DATABASE_URL` | MySQL DSN | `mysql://user:pass@host:3306/pharmapp` |
| `DJANGO_ALLOWED_HOSTS` | Comma-separated hostnames | `api.yourpharmapp.com` |
| `CORS_ALLOWED_ORIGINS` | Comma-separated origins | `https://yourpharmapp.com` |

### Flutter (build-time)

| Dart Define | Description | Default |
|-------------|-------------|---------|
| `API_URL` | Backend API base URL | `http://localhost:8000/api` |

---

## Build & Deploy

### Backend

```bash
# Collect static files (WhiteNoise serves them)
python manage.py collectstatic --noinput

# Run database migrations
python manage.py migrate

# Create platform superuser
python manage.py create_admin_user --superuser

# Start with gunicorn (production)
gunicorn pharmapi.wsgi:application --bind 0.0.0.0:8000 --workers 4
```

### Django security check

```bash
DJANGO_SECRET_KEY=x DATABASE_URL=mysql://x:x@localhost/x \
  DJANGO_ALLOWED_HOSTS=localhost CORS_ALLOWED_ORIGINS=https://localhost \
  python manage.py check --deploy --settings=pharmapi.settings.prod
```
