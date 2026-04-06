/// Model representing an organization's subscription as seen by a superuser.
library;

import 'package:pharmapp/shared/models/subscription.dart';

class OrgSubscriptionSummary {
  final int                id;
  final String             name;
  final String             slug;
  final String             phone;
  final SubscriptionPlan   plan;
  final SubscriptionStatus status;
  final BillingCycle       billingCycle;
  final DateTime?          trialEndsAt;
  final DateTime?          currentPeriodEnd;
  final Set<String>        extraFeatures;
  final Set<String>        removedFeatures;
  final UsageLimits?       customLimits;
  final CurrentUsage       usage;
  final int                userCount;

  OrgSubscriptionSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.phone,
    required this.plan,
    required this.status,
    this.billingCycle    = BillingCycle.monthly,
    this.trialEndsAt,
    this.currentPeriodEnd,
    this.extraFeatures   = const {},
    this.removedFeatures = const {},
    this.customLimits,
    required this.usage,
    this.userCount       = 0,
  });

  // ── Derived ───────────────────────────────────────────────────────────────────

  Set<String> get effectiveFeatures {
    final base = SaasFeature.forPlan(plan);
    base.addAll(extraFeatures);
    base.removeAll(removedFeatures);
    return base;
  }

  UsageLimits get effectiveLimits => customLimits ?? UsageLimits.forPlan(plan);

  bool get hasCustomLimits => customLimits != null;

  bool get hasFeatureOverrides =>
      extraFeatures.isNotEmpty || removedFeatures.isNotEmpty;

  int? get trialDaysRemaining {
    if (trialEndsAt == null) return null;
    final diff = trialEndsAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  // ── Serialization ─────────────────────────────────────────────────────────────

  factory OrgSubscriptionSummary.fromJson(Map<String, dynamic> json) {
    final plan   = SubscriptionPlan.fromString(json['plan'] as String?);
    final status = SubscriptionStatus.fromString(json['status'] as String?);

    final extraFeatures = (json['extra_features'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toSet() ??
        <String>{};
    final removedFeatures = (json['removed_features'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toSet() ??
        <String>{};

    final customLimitsJson = json['custom_limits'] as Map<String, dynamic>?;
    final customLimits = customLimitsJson != null
        ? UsageLimits(
            maxUsers: (customLimitsJson['max_users'] as num?)?.toInt() ?? -1,
            maxItems: (customLimitsJson['max_items'] as num?)?.toInt() ?? -1,
            maxTransactionsPerMonth:
                (customLimitsJson['max_transactions_per_month'] as num?)
                        ?.toInt() ??
                    -1,
            maxBranches:
                (customLimitsJson['max_branches'] as num?)?.toInt() ?? -1,
          )
        : null;

    return OrgSubscriptionSummary(
      id:               (json['id'] as num).toInt(),
      name:             json['name'] as String? ?? '',
      slug:             json['slug'] as String? ?? '',
      phone:            json['phone'] as String? ?? '',
      plan:             plan,
      status:           status,
      billingCycle:     BillingCycle.fromString(json['billing_cycle'] as String?),
      trialEndsAt:      json['trial_ends_at'] != null
          ? DateTime.tryParse(json['trial_ends_at'] as String)
          : null,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.tryParse(json['current_period_end'] as String)
          : null,
      extraFeatures:   extraFeatures,
      removedFeatures: removedFeatures,
      customLimits:    customLimits,
      usage: json['usage'] != null
          ? CurrentUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : const CurrentUsage(),
      userCount: (json['user_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id':               id,
        'name':             name,
        'slug':             slug,
        'phone':            phone,
        'plan':             plan.name,
        'status':           status.name,
        'billing_cycle':    billingCycle.apiValue,
        'trial_ends_at':    trialEndsAt?.toIso8601String(),
        'current_period_end': currentPeriodEnd?.toIso8601String(),
        'extra_features':   extraFeatures.toList(),
        'removed_features': removedFeatures.toList(),
        'custom_limits': customLimits == null
            ? null
            : {
                'max_users':                  customLimits!.maxUsers,
                'max_items':                  customLimits!.maxItems,
                'max_transactions_per_month': customLimits!.maxTransactionsPerMonth,
                'max_branches':               customLimits!.maxBranches,
              },
        'user_count': userCount,
      };

  OrgSubscriptionSummary copyWith({
    int?                id,
    String?             name,
    String?             slug,
    String?             phone,
    SubscriptionPlan?   plan,
    SubscriptionStatus? status,
    BillingCycle?       billingCycle,
    DateTime?           trialEndsAt,
    DateTime?           currentPeriodEnd,
    Set<String>?        extraFeatures,
    Set<String>?        removedFeatures,
    UsageLimits?        customLimits,
    CurrentUsage?       usage,
    int?                userCount,
    bool                clearCustomLimits = false,
    bool                clearTrialEndsAt  = false,
  }) =>
      OrgSubscriptionSummary(
        id:               id               ?? this.id,
        name:             name             ?? this.name,
        slug:             slug             ?? this.slug,
        phone:            phone            ?? this.phone,
        plan:             plan             ?? this.plan,
        status:           status           ?? this.status,
        billingCycle:     billingCycle     ?? this.billingCycle,
        trialEndsAt:      clearTrialEndsAt  ? null : trialEndsAt  ?? this.trialEndsAt,
        currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
        extraFeatures:   extraFeatures   ?? this.extraFeatures,
        removedFeatures: removedFeatures ?? this.removedFeatures,
        customLimits:    clearCustomLimits ? null : customLimits ?? this.customLimits,
        usage:           usage           ?? this.usage,
        userCount:       userCount       ?? this.userCount,
      );
}
