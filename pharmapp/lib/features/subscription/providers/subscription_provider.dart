import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/core/network/api_client.dart';
import 'package:pharmapp/shared/models/subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_api_client.dart';

// ── Raw fetch ──────────────────────────────────────────────────────────────────

/// Fetches subscription from backend. Cached until explicitly invalidated.
final subscriptionProvider = FutureProvider<Subscription>((ref) async {
  return ref.watch(subscriptionApiClientProvider).getSubscription();
});

// ── Sync notifier (for upgrade / cancel mutations) ────────────────────────────

class SubscriptionNotifier extends StateNotifier<AsyncValue<Subscription>>
    with WidgetsBindingObserver {
  final Ref _ref;

  SubscriptionNotifier(this._ref) : super(const AsyncValue.loading()) {
    WidgetsBinding.instance.addObserver(this);

    // Refresh when org access is revoked (403 received while authenticated).
    _ref.listen<int>(orgAccessRevokedProvider, (_, __) {
      if (_ref.read(authTokenProvider) != null) _load();
    });

    // Listen for token changes so we fetch as soon as auth is restored,
    // and reset to trial on logout.
    _ref.listen<String?>(authTokenProvider, (_, token) {
      if (token != null) {
        _load();
      } else {
        // Clear cache on logout so a different org doesn't inherit stale data.
        SharedPreferences.getInstance()
            .then((p) => p.remove(_cacheKey))
            .ignore();
        state = AsyncValue.data(Subscription.defaultTrial());
      }
    });
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-validate subscription whenever user returns to the app so that
    // superuser-initiated suspension/cancellation propagates to active sessions.
    if (state == AppLifecycleState.resumed &&
        _ref.read(authTokenProvider) != null) {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static const _cacheKey = 'cached_subscription';

  Future<void> _saveCache(Subscription sub) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(sub.toJson()));
    } catch (_) {}
  }

  Future<Subscription?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        return Subscription.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
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
      await _saveCache(sub);
      state = AsyncValue.data(sub);
    } catch (e, st) {
      // Offline or backend unreachable — restore last known subscription.
      // Only fall back to trial if no cached data exists.
      final cached = await _loadCache();
      if (cached != null) {
        state = AsyncValue.data(cached);
      } else {
        state = AsyncValue.data(Subscription.defaultTrial());
      }
      // ignore: avoid_print
      print('SubscriptionNotifier: backend unreachable, using ${cached != null ? "cached" : "trial"} fallback — $e\n$st');
    }
  }

  /// Refresh from backend (call after upgrade / on resume).
  Future<void> refresh() => _load();

  /// Requests a plan upgrade via the backend.
  /// Returns the payment gateway checkout URL if the backend requires online
  /// payment (e.g. Paystack/Flutterwave), or null if the switch was immediate.
  ///
  /// IMPORTANT: callers MUST open the returned URL so the subscriber completes
  /// payment before the plan is considered active. Silently dropping the URL
  /// would grant plan access without payment (fraud vector).
  ///
  /// Throws on backend error so the caller can surface it to the user.
  Future<String?> upgradePlan(String planId,
      {String billingCycle = 'monthly'}) async {
    final result = await _ref
        .read(subscriptionApiClientProvider)
        .upgradePlan(planId, billingCycle);

    await _load(); // refresh from backend after the request

    // Return checkout_url to the UI layer; may be null for direct switches.
    return result['checkout_url'] as String?;
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

/// Days remaining on the subscription (trial OR paid plan). Null = no end date.
final subscriptionDaysRemainingProvider = Provider<int?>((ref) {
  return ref.watch(currentSubscriptionProvider).subscriptionDaysRemaining;
});

/// True when any subscription (trial or paid) expires within 7 days.
final isSubscriptionExpiringProvider = Provider<bool>((ref) {
  return ref.watch(currentSubscriptionProvider).isSubscriptionExpiring;
});

/// Current usage stats.
final currentUsageProvider = Provider<CurrentUsage>((ref) {
  return ref.watch(currentSubscriptionProvider).usage;
});

/// Usage limits for the current plan.
final usageLimitsProvider = Provider<UsageLimits>((ref) {
  return ref.watch(currentSubscriptionProvider).limits;
});
