import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/features/superuser/providers/superuser_api_client.dart';
import 'package:pharmapp/shared/models/org_subscription_summary.dart';
import 'package:pharmapp/shared/models/subscription.dart';
import 'package:pharmapp/shared/models/plan_feature_matrix.dart';

export 'package:pharmapp/shared/models/plan_feature_matrix.dart';

// ── Org list ──────────────────────────────────────────────────────────────────

class OrgListNotifier
    extends StateNotifier<AsyncValue<List<OrgSubscriptionSummary>>> {
  final Ref _ref;
  OrgListNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final orgs =
          await _ref.read(superuserApiClientProvider).listOrganizations();
      state = AsyncValue.data(orgs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Replace a single org entry after an edit.
  void updateOrg(OrgSubscriptionSummary updated) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([
      for (final org in current)
        if (org.id == updated.id) updated else org,
    ]);
  }
}

final orgListProvider =
    StateNotifierProvider<OrgListNotifier, AsyncValue<List<OrgSubscriptionSummary>>>(
  (ref) => OrgListNotifier(ref),
);

// ── Plan / status filter chips ────────────────────────────────────────────────

final orgPlanFilterProvider = StateProvider<SubscriptionPlan?>((ref) => null);
final orgStatusFilterProvider =
    StateProvider<SubscriptionStatus?>((ref) => null);
final orgSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered & searched org list.
final filteredOrgListProvider =
    Provider<List<OrgSubscriptionSummary>>((ref) {
  final orgs   = ref.watch(orgListProvider).valueOrNull ?? [];
  final plan   = ref.watch(orgPlanFilterProvider);
  final status = ref.watch(orgStatusFilterProvider);
  final query  = ref.watch(orgSearchQueryProvider).toLowerCase();

  return orgs.where((org) {
    if (plan   != null && org.plan   != plan)   return false;
    if (status != null && org.status != status) return false;
    if (query.isNotEmpty &&
        !org.name.toLowerCase().contains(query) &&
        !org.slug.toLowerCase().contains(query) &&
        !org.phone.toLowerCase().contains(query)) {
      return false;
    }
    return true;
  }).toList();
});

// ── Aggregate stats ───────────────────────────────────────────────────────────

class OrgStats {
  final int total;
  final int active;
  final int trial;
  final int expired;
  final int suspended;

  const OrgStats({
    this.total     = 0,
    this.active    = 0,
    this.trial     = 0,
    this.expired   = 0,
    this.suspended = 0,
  });
}

final orgStatsProvider = Provider<OrgStats>((ref) {
  final orgs = ref.watch(orgListProvider).valueOrNull ?? [];
  return OrgStats(
    total:     orgs.length,
    active:    orgs.where((o) => o.status == SubscriptionStatus.active).length,
    trial:     orgs.where((o) =>
        o.status == SubscriptionStatus.trial ||
        o.status == SubscriptionStatus.expiring).length,
    expired:   orgs.where((o) => o.status == SubscriptionStatus.expired).length,
    suspended: orgs.where((o) => o.status == SubscriptionStatus.suspended).length,
  );
});

// ── Single-org editor state ───────────────────────────────────────────────────

class OrgEditorNotifier extends StateNotifier<AsyncValue<OrgSubscriptionSummary?>> {
  final Ref _ref;
  final int orgId;

  OrgEditorNotifier(this._ref, this.orgId) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final org = await _ref.read(superuserApiClientProvider).getOrganization(orgId);
      state = AsyncValue.data(org);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Save subscription overrides to backend.
  Future<String?> save(Map<String, dynamic> payload) async {
    try {
      final updated = await _ref
          .read(superuserApiClientProvider)
          .updateOrgSubscription(orgId, payload);
      state = AsyncValue.data(updated);
      _ref.read(orgListProvider.notifier).updateOrg(updated);
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  /// Extend trial for this org.
  Future<String?> extendTrial(int days) async {
    try {
      final updated =
          await _ref.read(superuserApiClientProvider).extendTrial(orgId, days);
      state = AsyncValue.data(updated);
      _ref.read(orgListProvider.notifier).updateOrg(updated);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Reset all overrides to plan defaults.
  Future<String?> resetToDefaults() async {
    try {
      final updated =
          await _ref.read(superuserApiClientProvider).resetToDefaults(orgId);
      state = AsyncValue.data(updated);
      _ref.read(orgListProvider.notifier).updateOrg(updated);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final orgEditorProvider = StateNotifierProvider.family<OrgEditorNotifier,
    AsyncValue<OrgSubscriptionSummary?>, int>(
  (ref, orgId) => OrgEditorNotifier(ref, orgId),
);

// ── Plan Feature Matrix notifier ──────────────────────────────────────────────

/// Manages the global plan → feature matrix.
/// All mutations are local-only until [save] is called.
class PlanFeatureMatrixNotifier
    extends StateNotifier<AsyncValue<PlanFeatureMatrix>> {
  final Ref _ref;

  PlanFeatureMatrixNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final matrix =
          await _ref.read(superuserApiClientProvider).getPlanFeatureMatrix();
      state = AsyncValue.data(matrix);
    } catch (e, st) {
      // Fall back to hardcoded defaults so the screen remains usable
      state = AsyncValue.data(PlanFeatureMatrix.fromDefaults());
      // ignore: avoid_print
      print('PlanFeatureMatrixNotifier: backend unreachable — $e\n$st');
    }
  }

  /// Reload from backend (discards unsaved local changes).
  Future<void> reload() => _load();

  // ── Local (staged) mutations ───────────────────────────────────────────────

  void _update(PlanFeatureMatrix Function(PlanFeatureMatrix) fn) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(fn(current));
  }

  /// Toggle [feature] inclusion in [planName].
  void toggleFeatureInPlan(String planName, String feature) =>
      _update((m) => m.withToggledFeatureInPlan(planName, feature));

  /// Add [feature] to [planName]'s set.
  void addFeatureToPlan(String planName, String feature) =>
      _update((m) => m.withFeatureInPlan(planName, feature));

  /// Remove [feature] from [planName]'s set.
  void removeFeatureFromPlan(String planName, String feature) =>
      _update((m) => m.withoutFeatureInPlan(planName, feature));

  /// Add a brand-new feature key [key] with display label [label].
  /// The feature starts unassigned to any plan; add it to plans with [addFeatureToPlan].
  void addFeature(String key, String label) =>
      _update((m) => m.withNewFeature(key, label));

  /// Remove feature [key] from the system (all plans + feature list).
  void removeFeature(String key) =>
      _update((m) => m.withoutFeature(key));

  /// Change the display label of [key] to [newLabel].
  void renameFeature(String key, String newLabel) =>
      _update((m) => m.withRenamedFeature(key, newLabel));

  /// Reorder the feature list (drag-and-drop support).
  void reorderFeatures(int oldIndex, int newIndex) {
    final current = state.valueOrNull;
    if (current == null) return;
    final order = List<String>.from(current.featureOrder);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);
    state = AsyncValue.data(current.withReorderedFeatures(order));
  }

  // ── Persist to backend ─────────────────────────────────────────────────────

  /// Save current in-memory matrix to backend.
  /// Returns null on success, error message on failure.
  Future<String?> save() async {
    final current = state.valueOrNull;
    if (current == null) return 'Nothing to save.';
    try {
      final updated = await _ref
          .read(superuserApiClientProvider)
          .updatePlanFeatureMatrix(current);
      state = AsyncValue.data(updated);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final planFeatureMatrixProvider = StateNotifierProvider<
    PlanFeatureMatrixNotifier, AsyncValue<PlanFeatureMatrix>>(
  (ref) => PlanFeatureMatrixNotifier(ref),
);
