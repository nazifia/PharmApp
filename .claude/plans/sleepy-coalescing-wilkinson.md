# Auto-Logout on Inactivity

**Context**: Currently neither the Django admin nor the Flutter app auto-logs out inactive users. This is a security requirement — admin sessions should expire after 2 minutes of inactivity, and the Flutter app after 10 minutes.

## Part 1: Django Admin — Auto-logout after 2 minutes

### Files to modify:
1. **`backend/authapp/middleware.py`** — Add new `AdminInactivityMiddleware` class
2. **`backend/pharmapi/settings/base.py`** — Register the middleware in MIDDLEWARE list

### Implementation:
- New middleware `AdminInactivityMiddleware` added to `middleware.py` alongside existing `MaintenanceModeMiddleware`
- On every request to `/admin/` paths (excluding `/admin/login/`):
  - Check `request.session['last_admin_activity']`
  - If > 120 seconds elapsed → `request.session.flush()` → redirect to `/admin/login/`
  - Otherwise → update `request.session['last_admin_activity'] = now`
- Place in `MIDDLEWARE` in `base.py` **after** `SessionMiddleware` and `AuthenticationMiddleware` (so session and auth are available)
- Non-admin paths pass through unchanged

### Settings in `base.py`:
```python
MIDDLEWARE = [
    # ... existing ...
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "authapp.middleware.AdminInactivityMiddleware",  # NEW
    "django.contrib.messages.middleware.MessageMiddleware",
    # ...
]
```

## Part 2: Flutter App — Auto-logout after 10 minutes

### Files to modify:
1. **`pharmapp/lib/core/inactivity/inactivity_provider.dart`** — NEW file with Riverpod provider
2. **`pharmapp/lib/main.dart`** — Wrap `PharmApp` with `InactivityGuard`
3. **`pharmapp/lib/core/services/auth_service.dart`** — Add `autoLogout()` method (optional, for future use)

### Implementation:
- New `inactivity_provider.dart`:
  - `inactivityTimeoutProvider` = `StateProvider` tracking last activity timestamp
  - `autoLogoutProvider` = `StateProvider<bool>` whether auto-logout is triggered
  - `InactivityGuard` widget: a `ConsumerStatefulWidget` that wraps the entire app and uses a periodic timer (every 30s) to check if `lastActivity + 10 min < now`
  - Uses `WidgetsBinding.instance.addPostFrameCallback` + `GestureBinding.instance` to listen to pointer events (taps, scrolls) and reset the timer
  - On timeout: calls `authServiceProvider.logout()` and `context.go('/login')`, shows a snackbar "Session expired due to inactivity"

- In `main.dart`, wrap the authenticated app with `InactivityGuard`:
  ```dart
  class _AppStartup extends ConsumerWidget {
    // FutureBuilder returns:
    //   authenticated → InactivityGuard(child: PharmApp())
    //   not authenticated → PharmApp() (no guard needed on login screen)
  }
  ```

### Key design decisions:
- **GestureBinding listener**: Captures all user interactions (taps, scrolls, drags) globally at the Flutter framework level — no need to wrap individual screens
- **Timer interval**: 30 seconds (balances accuracy with battery drain)
- **Timeout**: 10 minutes = 600 seconds
- **Auto-logout reuses existing `AuthService.logout()`** — clears SharedPreferences, resets Riverpod providers, triggers router redirect
- Does NOT fire during app background (user may have minimized the app intentionally) — only tracks foreground activity

## Verification:
1. **Django admin**: Log into `/admin/`, wait 2+ minutes without interaction, try to navigate — should redirect to login
2. **Flutter app**: Log in, leave the app open and untouched for 10+ minutes, try to tap anything — should redirect to `/login` with a snackbar
3. `flutter analyze` — no type errors
