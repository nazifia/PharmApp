import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pharmapp/core/services/auth_service.dart';

// ── Inactivity timeout (10 minutes) ──────────────────────────────────────────
const _inactivityLimit = Duration(minutes: 10);
const _checkInterval = Duration(seconds: 30);

/// Tracks the timestamp of the last user interaction.
final lastActivityProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// ── InactivityGuard ──────────────────────────────────────────────────────────
///
/// Wraps the entire authenticated app. Listens to all pointer events (taps,
/// scrolls, drags) via `GestureBinding`. Every 30 seconds checks if the user
/// has been idle for 10+ minutes; if so, logs them out and sends them to /login.
class InactivityGuard extends ConsumerStatefulWidget {
  final Widget child;
  const InactivityGuard({super.key, required this.child});

  @override
  ConsumerState<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends ConsumerState<InactivityGuard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Update lastActivity on every pointer event
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onActivity);
    // Periodic check for inactivity
    _timer = Timer.periodic(_checkInterval, _checkInactivity);
  }

  void _onActivity(PointerEvent event) {
    ref.read(lastActivityProvider.notifier).state = DateTime.now();
  }

  void _checkInactivity(Timer timer) {
    final last = ref.read(lastActivityProvider);
    if (DateTime.now().difference(last) >= _inactivityLimit) {
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
