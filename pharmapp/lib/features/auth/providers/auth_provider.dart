import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmapp/shared/models/user.dart';
import 'package:pharmapp/shared/models/organization.dart';
import 'package:pharmapp/shared/models/branch.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/eager_sync_service.dart';
import '../../../core/services/auth_storage.dart';
import '../../../features/branches/providers/branch_provider.dart';
import 'auth_repository.dart';

export '../../../core/network/api_client.dart' show authTokenProvider;

// ── Token / User state ────────────────────────────────────────────────────────

/// Holds the authenticated [User] profile.
final currentUserProvider = StateProvider<User?>((ref) => null);

/// Derived from the authenticated user — no separate storage needed.
/// Returns null if the user has no org (e.g. local dev, legacy session).
final currentOrganizationProvider = Provider<Organization?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.organizationId == 0) return null;
  return Organization(
    id: user.organizationId,
    name: user.organizationName,
    slug: user.organizationSlug,
    address: user.organizationAddress.isEmpty ? null : user.organizationAddress,
    phone: user.organizationPhone.isEmpty ? null : user.organizationPhone,
    logoUrl: user.organizationLogo.isEmpty ? null : user.organizationLogo,
  );
});

/// Derived from the active session branch — prefers activeBranchProvider (covers
/// both backend-assigned and manually-selected branches), falls back to the
/// user model's branchId (legacy / dev-mode fallback).
/// Returns null for org-wide access (admin with no specific branch selected).
final currentBranchProvider = Provider<({int id, String name})?> ((ref) {
  final active = ref.watch(activeBranchProvider);
  if (active != null && active.id > 0) return (id: active.id, name: active.name);
  final user = ref.watch(currentUserProvider);
  if (user == null || user.branchId == 0) return null;
  return (id: user.branchId, name: user.branchName);
});

// ── Repository provider ───────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final isDev = ref.watch(isDevModeProvider);
  if (isDev) return AuthRepository.local();
  return AuthRepository.remote(ref.watch(dioProvider));
});

// ── Auth flow state ───────────────────────────────────────────────────────────

enum AuthFlowState { initial, loggingIn, registering, registered, authenticated, error }

class AuthNotifier extends StateNotifier<AuthFlowState> {
  final Ref _ref;
  String? _errorMessage;

  AuthNotifier(this._ref) : super(AuthFlowState.initial);

  String? get errorMessage => _errorMessage;

  /// Direct phone + password login (no OTP).
  Future<void> login(String phone, String password) async {
    _errorMessage = null;
    state = AuthFlowState.loggingIn;

    try {
      final result = await _ref.read(authRepositoryProvider).login(phone, password);

      final String token = result['token'] as String;
      final User   user  = result['user']  as User;

      _ref.read(authTokenProvider.notifier).state   = token;
      _ref.read(currentUserProvider.notifier).state = user;

      // Auto-activate backend-assigned branch — skip manual selection screen.
      if (user.branchId != 0) {
        _ref.read(activeBranchProvider.notifier).state = Branch(
          id:   user.branchId,
          name: user.branchName,
        );
      }

      await AuthStorage.write('auth_token',   token);
      await AuthStorage.write('current_user', jsonEncode(user.toJson()));

      state = AuthFlowState.authenticated;

      // Warm the offline cache in the background — don't block login.
      _ref.read(eagerSyncProvider.notifier).warmCache();
    } catch (e) {
      _errorMessage = _friendly(e);
      state = AuthFlowState.error;
    }
  }

  /// Called by [AuthService.checkAuthStatus] to restore a persisted session
  /// without going through the login network call.
  void restoreSession(String token, User user) {
    _ref.read(authTokenProvider.notifier).state   = token;
    _ref.read(currentUserProvider.notifier).state = user;
    state = AuthFlowState.authenticated;
  }

  /// Register a new pharmacy organization + first admin user.
  Future<void> registerOrg({
    required String orgName,
    required String phone,
    required String password,
    String? address,
  }) async {
    _errorMessage = null;
    state = AuthFlowState.registering;
    try {
      await _ref.read(authRepositoryProvider).registerOrg(
            orgName: orgName,
            phone: phone,
            password: password,
            address: address,
          );
      // Registration succeeded — do NOT log the user in automatically.
      // Redirect to login so they authenticate explicitly.
      state = AuthFlowState.registered;
    } catch (e) {
      _errorMessage = _friendly(e);
      state = AuthFlowState.error;
    }
  }

  /// Re-fetches the current user's profile from the backend and updates
  /// both the in-memory provider and the SharedPreferences cache.
  /// Call this after session restore, after saving permission overrides,
  /// or whenever the app resumes from background.
  Future<void> refreshProfile() async {
    final current = _ref.read(currentUserProvider);
    if (current == null) return; // not logged in
    try {
      final fresh = await _ref
          .read(authRepositoryProvider)
          .fetchCurrentUser(current);
      _ref.read(currentUserProvider.notifier).state = fresh;
      // Re-enforce backend-assigned branch in case it changed server-side.
      // Always write so the router (which listens to activeBranchProvider)
      // triggers a redirect even when the branch id was already set to the
      // same value in a previous session.
      if (fresh.branchId != 0) {
        _ref.read(activeBranchProvider.notifier).state = Branch(
          id:   fresh.branchId,
          name: fresh.branchName,
        );
        // Persist so the next session restore skips the branch selection screen.
        SharedPreferences.getInstance().then(
          (p) => p.setString('active_branch',
              jsonEncode(Branch(id: fresh.branchId, name: fresh.branchName).toJson())),
        );
      }
      await AuthStorage.write('current_user', jsonEncode(fresh.toJson()));
    } catch (_) {
      // Silently ignore — keep the cached user
    }
  }

  /// Patches the current user's profile (username, fullname) via PATCH /auth/me/.
  /// Updates in-memory state and persists to AuthStorage on success.
  Future<void> updateProfile({String? username, String? fullname}) async {
    final current = _ref.read(currentUserProvider);
    if (current == null) return;
    final updated = await _ref.read(authRepositoryProvider).updateProfile(
          current: current,
          username: username,
          fullname: fullname,
        );
    _ref.read(currentUserProvider.notifier).state = updated;
    await AuthStorage.write('current_user', jsonEncode(updated.toJson()));
  }

  /// Uploads a new logo for the org and patches the cached user so the
  /// drawer updates immediately without a full re-login.
  Future<void> uploadOrgLogo(XFile imageFile) async {
    final newLogoUrl = await _ref.read(authRepositoryProvider).uploadOrgLogo(imageFile);
    final current = _ref.read(currentUserProvider);
    if (current == null) return;
    final updated = current.copyWith(organizationLogo: newLogoUrl);
    _ref.read(currentUserProvider.notifier).state = updated;
    await AuthStorage.write('current_user', jsonEncode(updated.toJson()));
  }

  /// Called from BranchSelectionScreen when user picks a branch.
  /// Updates [currentUserProvider] with the chosen branch, marks
  /// [activeBranchProvider] so the router stops redirecting to /select-branch,
  /// and persists the choice for session restore.
  void selectBranch(Branch branch) {
    // Only update the session-level activeBranchProvider — do NOT write branchId
    // into the user model. The user model must always reflect the backend truth
    // (branchId = 0 means no backend-assigned branch). Writing here would cause
    // refreshProfile() to reset it back to 0, re-showing the branch switcher.
    _ref.read(activeBranchProvider.notifier).state = branch;
    SharedPreferences.getInstance()
        .then((p) => p.setString('active_branch', jsonEncode(branch.toJson())));
  }

  /// Called when user explicitly skips branch selection (org-wide access).
  /// Uses a sentinel Branch(id: -1) so [activeBranchProvider] is non-null.
  void skipBranchSelection() {
    const sentinel = Branch(id: -1, name: 'All Branches');
    _ref.read(activeBranchProvider.notifier).state = sentinel;
    SharedPreferences.getInstance()
        .then((p) => p.setString('active_branch', jsonEncode(sentinel.toJson())));
  }

  void resetFlow() {
    _errorMessage = null;
    state = AuthFlowState.initial;
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.contains('Exception:')) return msg.replaceFirst('Exception: ', '');
    return msg;
  }
}

final authFlowProvider =
    StateNotifierProvider<AuthNotifier, AuthFlowState>((ref) {
  return AuthNotifier(ref);
});
