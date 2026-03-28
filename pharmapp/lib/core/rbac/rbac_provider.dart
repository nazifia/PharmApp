import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';

/// Check a single permission for the current user.
///
/// Usage:
/// ```dart
/// final canViewReports = ref.watch(canProvider(AppPermission.viewReports));
/// if (canViewReports) { ... }
/// ```
final canProvider = Provider.family<bool, String>((ref, permission) {
  final user = ref.watch(currentUserProvider);
  return Rbac.can(user, permission);
});
