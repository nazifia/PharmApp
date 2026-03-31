/// Subscription model — plain Dart, no codegen needed.
library;

// ── Billing Cycle ─────────────────────────────────────────────────────────────

enum BillingCycle {
  monthly,
  annual;

  String get displayName => switch (this) {
        monthly => 'Monthly',
        annual  => 'Annual',
      };

  String get apiValue => switch (this) {
        monthly => 'monthly',
        annual  => 'annual',
      };

  static BillingCycle fromString(String? value) => switch (value) {
        'annual' => BillingCycle.annual,
        _        => BillingCycle.monthly,
      };
}

// ── Plan enum ─────────────────────────────────────────────────────────────────

enum SubscriptionPlan {
  trial,
  starter,
  professional,
  enterprise;

  String get displayName => switch (this) {
        trial        => 'Free Trial',
        starter      => 'Starter',
        professional => 'Professional',
        enterprise   => 'Enterprise',
      };

  /// Monthly price label.
  String get price => switch (this) {
        trial        => 'Free',
        starter      => '\$9.99/mo',
        professional => '\$29.99/mo',
        enterprise   => '\$79.99/mo',
      };

  /// Monthly price as a number (0 for trial).
  double get monthlyAmount => switch (this) {
        trial        => 0,
        starter      => 9.99,
        professional => 29.99,
        enterprise   => 79.99,
      };

  /// Equivalent monthly cost when billed annually (20 % discount).
  double get annualMonthlyAmount => (monthlyAmount * 0.80 * 100).roundToDouble() / 100;

  /// Total charged annually.
  double get annualTotal => (annualMonthlyAmount * 12 * 100).roundToDouble() / 100;

  /// Annual savings vs 12 months of monthly billing.
  double get annualSavings =>
      (monthlyAmount * 12 * 100).roundToDouble() / 100 - annualTotal;

  /// Price label for the given billing cycle.
  String priceLabel(BillingCycle cycle) {
    if (monthlyAmount == 0) return 'Free';
    return switch (cycle) {
      BillingCycle.monthly => '\$${monthlyAmount.toStringAsFixed(2)}/mo',
      BillingCycle.annual  =>
        '\$${annualMonthlyAmount.toStringAsFixed(2)}/mo · \$${annualTotal.toStringAsFixed(2)}/yr',
    };
  }

  /// Numeric rank — used to compare "is plan X at least as high as Y?"
  int get rank => switch (this) {
        trial        => 0,
        starter      => 1,
        professional => 2,
        enterprise   => 3,
      };

  bool isAtLeast(SubscriptionPlan other) => rank >= other.rank;

  static SubscriptionPlan fromString(String? value) => switch (value) {
        'starter'      => SubscriptionPlan.starter,
        'professional' => SubscriptionPlan.professional,
        'enterprise'   => SubscriptionPlan.enterprise,
        _              => SubscriptionPlan.trial,
      };
}

// ── Status enum ───────────────────────────────────────────────────────────────

enum SubscriptionStatus {
  active,
  trial,
  expiring,    // trial < 7 days remaining
  expired,
  suspended,
  cancelled;

  static SubscriptionStatus fromString(String? value) => switch (value) {
        'active'    => SubscriptionStatus.active,
        'trial'     => SubscriptionStatus.trial,
        'expiring'  => SubscriptionStatus.expiring,
        'expired'   => SubscriptionStatus.expired,
        'suspended' => SubscriptionStatus.suspended,
        'cancelled' => SubscriptionStatus.cancelled,
        _           => SubscriptionStatus.trial,
      };
}

// ── Usage Limits ──────────────────────────────────────────────────────────────

class UsageLimits {
  final int maxUsers;           // -1 = unlimited
  final int maxItems;           // -1 = unlimited
  final int maxTransactionsPerMonth; // -1 = unlimited
  final int maxBranches;        // -1 = unlimited

  const UsageLimits({
    required this.maxUsers,
    required this.maxItems,
    required this.maxTransactionsPerMonth,
    required this.maxBranches,
  });

  bool get unlimitedUsers        => maxUsers == -1;
  bool get unlimitedItems        => maxItems == -1;
  bool get unlimitedTransactions => maxTransactionsPerMonth == -1;
  bool get unlimitedBranches     => maxBranches == -1;

  static UsageLimits forPlan(SubscriptionPlan plan) => switch (plan) {
        SubscriptionPlan.trial        => const UsageLimits(maxUsers: 2,  maxItems: 50,  maxTransactionsPerMonth: 200,  maxBranches: 1),
        SubscriptionPlan.starter      => const UsageLimits(maxUsers: 5,  maxItems: 500, maxTransactionsPerMonth: 2000, maxBranches: 1),
        SubscriptionPlan.professional => const UsageLimits(maxUsers: 15, maxItems: -1,  maxTransactionsPerMonth: -1,   maxBranches: 3),
        SubscriptionPlan.enterprise   => const UsageLimits(maxUsers: -1, maxItems: -1,  maxTransactionsPerMonth: -1,   maxBranches: -1),
      };
}

// ── Feature Flags ──────────────────────────────────────────────────────────────

/// All feature keys used throughout the app.
/// Gate access via [Subscription.hasFeature].
class SaasFeature {
  SaasFeature._();

  static const String pos              = 'pos';
  static const String inventory        = 'inventory';
  static const String customers        = 'customers';
  static const String userManagement   = 'user_management';
  static const String basicReports     = 'basic_reports';
  static const String advancedReports  = 'advanced_reports';
  static const String wholesale        = 'wholesale';
  static const String exportData       = 'export_data';
  static const String multiBranch      = 'multi_branch';
  static const String apiAccess        = 'api_access';
  static const String prioritySupport  = 'priority_support';
  static const String whiteLabel       = 'white_label';

  static Set<String> forPlan(SubscriptionPlan plan) {
    final base = {pos, inventory};

    if (plan.isAtLeast(SubscriptionPlan.starter)) {
      base.addAll({customers, userManagement, basicReports});
    }
    if (plan.isAtLeast(SubscriptionPlan.professional)) {
      base.addAll({advancedReports, wholesale, exportData});
    }
    if (plan.isAtLeast(SubscriptionPlan.enterprise)) {
      base.addAll({multiBranch, apiAccess, prioritySupport, whiteLabel});
    }

    return base;
  }
}

// ── Current Usage ─────────────────────────────────────────────────────────────

class CurrentUsage {
  final int usersCount;
  final int itemsCount;
  final int transactionsThisMonth;
  final int branchesCount;

  const CurrentUsage({
    this.usersCount            = 0,
    this.itemsCount            = 0,
    this.transactionsThisMonth = 0,
    this.branchesCount         = 1,
  });

  factory CurrentUsage.fromJson(Map<String, dynamic> json) => CurrentUsage(
        usersCount:            (json['users_count']             as num?)?.toInt() ?? 0,
        itemsCount:            (json['items_count']             as num?)?.toInt() ?? 0,
        transactionsThisMonth: (json['transactions_this_month'] as num?)?.toInt() ?? 0,
        branchesCount:         (json['branches_count']          as num?)?.toInt() ?? 1,
      );
}

// ── Subscription ─────────────────────────────────────────────────────────────

class Subscription {
  final SubscriptionPlan   plan;
  final SubscriptionStatus status;
  final BillingCycle       billingCycle;
  final DateTime?          trialEndsAt;
  final DateTime?          currentPeriodEnd;
  final UsageLimits        limits;
  final Set<String>        features;
  final CurrentUsage       usage;

  Subscription({
    required this.plan,
    required this.status,
    this.billingCycle    = BillingCycle.monthly,
    this.trialEndsAt,
    this.currentPeriodEnd,
    required this.limits,
    required this.features,
    required this.usage,
  });

  // ── Derived helpers ──────────────────────────────────────────────────────────

  bool hasFeature(String feature) => features.contains(feature);

  bool get isAccessible =>
      status == SubscriptionStatus.active  ||
      status == SubscriptionStatus.trial   ||
      status == SubscriptionStatus.expiring;

  int? get trialDaysRemaining {
    if (trialEndsAt == null) return null;
    final diff = trialEndsAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get isTrialExpiring =>
      status == SubscriptionStatus.expiring ||
      (status == SubscriptionStatus.trial &&
       (trialDaysRemaining ?? 99) <= 7);

  // ── Serialization ────────────────────────────────────────────────────────────

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final plan         = SubscriptionPlan.fromString(json['plan'] as String?);
    final status       = SubscriptionStatus.fromString(json['status'] as String?);
    final billingCycle = BillingCycle.fromString(json['billing_cycle'] as String?);
    return Subscription(
      plan:             plan,
      status:           status,
      billingCycle:     billingCycle,
      trialEndsAt:      json['trial_ends_at']      != null
          ? DateTime.tryParse(json['trial_ends_at'] as String)
          : null,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.tryParse(json['current_period_end'] as String)
          : null,
      limits:   UsageLimits.forPlan(plan),
      features: SaasFeature.forPlan(plan),
      usage:    json['usage'] != null
          ? CurrentUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : const CurrentUsage(),
    );
  }

  /// Default trial subscription — used while the real data is loading
  /// or when the backend does not yet implement the subscription endpoint.
  factory Subscription.defaultTrial() => Subscription(
        plan:     SubscriptionPlan.trial,
        status:   SubscriptionStatus.trial,
        limits:   UsageLimits.forPlan(SubscriptionPlan.trial),
        features: SaasFeature.forPlan(SubscriptionPlan.trial),
        usage:    const CurrentUsage(),
        trialEndsAt: DateTime.now().add(const Duration(days: 14)),
      );
}
