import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';

/// Returns a redirect path if the current user does not have one of the
/// [allowedRoles], otherwise returns `null` (access granted).
String? checkRoleGuard(WidgetRef ref, List<String> allowedRoles) {
  final user = ref.read(currentUserProvider);
  if (user == null) return '/login';
  if (allowedRoles.contains(user.role)) return null;
  return '/dashboard';
}

/// Widget wrapper that enforces role-based access on a screen.
class RoleGuard extends ConsumerWidget {
  final List<String> allowedRoles;
  final Widget child;
  final String? redirectTo;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.redirectTo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null || !allowedRoles.contains(user.role)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(redirectTo ?? '/dashboard');
      });
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
          ),
        ),
      );
    }

    return child;
  }
}
