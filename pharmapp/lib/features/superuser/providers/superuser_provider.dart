import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/features/superuser/providers/superuser_api_client.dart';
import 'package:pharmapp/shared/models/org_subscription_summary.dart';
import 'package:pharmapp/shared/models/subscription.dart';

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
        !org.phone.toLowerCase().contains(query)) return false;
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
