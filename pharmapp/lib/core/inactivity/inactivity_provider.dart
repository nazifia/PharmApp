import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/features/auth/providers/auth_repository.dart'
    show kAutoLogoutMinutesKey;

// ── Inactivity timeout ────────────────────────────────────────────────────────
// Default 10 minutes; each org can override via django-admin
// (Organization.auto_logout_minutes, delivered as user.autoLogoutMinutes and
// stashed in SharedPreferences on login / profile refresh). 0 = never.
const _defaultLogoutMinutes = 10;
const _checkInterval = Duration(seconds: 30);

/// Tracks the timestamp of the last user interaction.
final lastActivityProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// ── InactivityGuard ──────────────────────────────────────────────────────────
///
/// Wraps the entire authenticated app. Listens to all pointer events (taps,
/// scrolls, drags) via `GestureBinding`. Every 30 seconds checks if the user
/// has been idle longer than the org's auto-logout limit; if so, logs them
/// out and sends them to /login.
class InactivityGuard extends ConsumerStatefulWidget {
  final Widget child;
  const InactivityGuard({super.key, required this.child});

  @override
  ConsumerState<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends ConsumerState<InactivityGuard> {
  Timer? _timer;
  int _logoutMinutes = _defaultLogoutMinutes;

  @override
  void initState() {
    super.initState();
    // Update lastActivity on every pointer event
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onActivity);
    // Periodic check for inactivity
    _timer = Timer.periodic(_checkInterval, _checkInactivity);
    SharedPreferences.getInstance().then((prefs) {
      _logoutMinutes =
          prefs.getInt(kAutoLogoutMinutesKey) ?? _defaultLogoutMinutes;
    });
  }

  void _onActivity(PointerEvent event) {
    ref.read(lastActivityProvider.notifier).state = DateTime.now();
  }

  void _checkInactivity(Timer timer) {
    // Re-read each tick so an admin change lands after the next profile
    // refresh without an app restart (instance is cached — no disk I/O).
    SharedPreferences.getInstance().then((prefs) {
      _logoutMinutes =
          prefs.getInt(kAutoLogoutMinutesKey) ?? _defaultLogoutMinutes;
    });
    if (_logoutMinutes <= 0) return; // 0 = auto-logout disabled for this org
    final last = ref.read(lastActivityProvider);
    if (DateTime.now().difference(last) >= Duration(minutes: _logoutMinutes)) {
      _autoLogout();
    }
  }

  Future<void> _autoLogout() async {
    _timer?.cancel();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onActivity);

    await ref.read(authServiceProvider).logout();

    if (!mounted) return;
    context.go('/login');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Session expired due to inactivity'),
        backgroundColor: const Color(0xFFF59E0B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onActivity);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
