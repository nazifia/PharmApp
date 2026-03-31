import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/core/network/api_client.dart';
import 'package:pharmapp/shared/models/subscription.dart';
import 'subscription_api_client.dart';

// ── Raw fetch ──────────────────────────────────────────────────────────────────

/// Fetches subscription from backend. Cached until explicitly invalidated.
final subscriptionProvider = FutureProvider<Subscription>((ref) async {
  return ref.watch(subscriptionApiClientProvider).getSubscription();
});

// ── Sync notifier (for upgrade / cancel mutations) ────────────────────────────

class SubscriptionNotifier extends StateNotifier<AsyncValue<Subscription>> {
  final Ref _ref;

  SubscriptionNotifier(this._ref) : super(const AsyncValue.loading()) {
    // Listen for token changes so we fetch as soon as auth is restored,
    // and reset to trial on logout.
    _ref.listen<String?>(authTokenProvider, (_, token) {
      if (token != null) {
        _load();
      } else {
        state = AsyncValue.data(Subscription.defaultTrial());
      }
    });
    _load();
  }

  Future<void> _load() async {
    // Skip if not yet authenticated — avoids a 401 on app startup before
    // checkAuthStatus() has restored the token from SharedPreferences.
    if (_ref.read(authTokenProvider) == null) {
      state = AsyncValue.data(Subscription.defaultTrial());
      return;
    }
    state = const AsyncValue.loading();
    try {
      final sub = await _ref.read(subscriptionApiClientProvider).getSubscription();
      state = AsyncValue.data(sub);
    } catch (e, st) {
      // Fall back to trial so the app remains usable
      state = AsyncValue.data(Subscription.defaultTrial());
      // ignore: avoid_print
      print('SubscriptionNotifier: backend unreachable, using trial fallback — $e\n$st');
    }
  }

  /// Refresh from backend (call after upgrade / on resume).
  Future<void> refresh() => _load();

  /// Optimistically upgrades the in-memory plan while the network call runs.
  /// [billingCycle] is 'monthly' or 'annual'.
  Future<String?> upgradePlan(String planId,
      {String billingCycle = 'monthly'}) async {
    try {
      final result = await _ref
          .read(subscriptionApiClientProvider)
          .upgradePlan(planId, billingCycle);

      await _load(); // refresh from backend
      return result['checkout_url'] as String?; // may return a payment URL
    } catch (e) {
      return null;
    }
  }

  Future<void> cancelSubscription() async {
    await _ref.read(subscriptionApiClientProvider).cancelSubscription();
    await _load();
  }
}

final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<Subscription>>(
  (ref) => SubscriptionNotifier(ref),
);

// ── Derived convenience providers ─────────────────────────────────────────────

/// The resolved [Subscription] object — returns a defaultTrial while loading.
final currentSubscriptionProvider = Provider<Subscription>((ref) {
  return ref
      .watch(subscriptionNotifierProvider)
      .maybeWhen(data: (s) => s, orElse: Subscription.defaultTrial);
});

/// Whether the current subscription allows access to a named feature.
/// Usage: `ref.watch(hasFeatureProvider(SaasFeature.wholesale))`
final hasFeatureProvider = Provider.family<bool, String>((ref, feature) {
  final sub = ref.watch(currentSubscriptionProvider);
  return sub.isAccessible && sub.hasFeature(feature);
});

/// Current plan — quick access for UI.
final currentPlanProvider = Provider<SubscriptionPlan>((ref) {
  return ref.watch(currentSubscriptionProvider).plan;
});

/// Whether the subscription is accessible (active, trial, or expiring).
final subscriptionAccessibleProvider = Provider<bool>((ref) {
  return ref.watch(currentSubscriptionProvider).isAccessible;
});

/// Days remaining in trial (null if not on trial).
final trialDaysRemainingProvider = Provider<int?>((ref) {
  return ref.watch(currentSubscriptionProvider).trialDaysRemaining;
});

/// True when trial expires within 7 days — used to show the warning banner.
final isTrialExpiringProvider = Provider<bool>((ref) {
  return ref.watch(currentSubscriptionProvider).isTrialExpiring;
});

/// Current usage stats.
final currentUsageProvider = Provider<CurrentUsage>((ref) {
  return ref.watch(currentSubscriptionProvider).usage;
});

/// Usage limits for the current plan.
final usageLimitsProvider = Provider<UsageLimits>((ref) {
  return ref.watch(currentSubscriptionProvider).limits;
});
