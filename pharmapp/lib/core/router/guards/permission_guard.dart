import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/core/services/auth_service.dart';

/// Widget that conditionally renders [child] only when the current user has
/// [permission]. Shows [fallback] (or an empty box) when access is denied.
class PermissionGuard extends ConsumerWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    if (!authService.hasPermission(permission)) {
      return fallback ?? const SizedBox.shrink();
    }
    return child;
  }
}
