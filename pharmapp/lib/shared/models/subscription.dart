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
        starter      => '₦9.99/mo',
        professional => '₦29.99/mo',
        enterprise   => '₦79.99/mo',
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
      BillingCycle.monthly => '₦${monthlyAmount.toStringAsFixed(2)}/mo',
      BillingCycle.annual  =>
        '₦${annualMonthlyAmount.toStringAsFixed(2)}/mo · ₦${annualTotal.toStringAsFixed(2)}/yr',
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
  static const String prioritySupport  = 'priority_support';

  /// Public display label for a feature key.
  static String labelFor(String key) => switch (key) {
        pos             => 'Point of Sale',
        inventory       => 'Inventory Management',
        customers       => 'Customer Management',
        userManagement  => 'User Management',
        basicReports    => 'Basic Reports',
        advancedReports => 'Advanced Reports',
        wholesale       => 'Wholesale Module',
        exportData      => 'Export Data',
        multiBranch     => 'Multi-Branch',
        prioritySupport => 'Priority Support',
        _               => key,
      };

  static Set<String> forPlan(SubscriptionPlan plan) {
    final base = {pos, inventory};

    if (plan.isAtLeast(SubscriptionPlan.starter)) {
      base.addAll({customers, userManagement, basicReports});
    }
    if (plan.isAtLeast(SubscriptionPlan.professional)) {
      base.addAll({advancedReports, wholesale, exportData, multiBranch});
    }
    if (plan.isAtLeast(SubscriptionPlan.enterprise)) {
      base.addAll({prioritySupport});
    }

    return base;
  }
}

// ── Billing Contact ───────────────────────────────────────────────────────────

/// Subscriber's contact details used for billing notifications.
/// Stored on the backend and used to send payment receipts via email
/// and payment reminders/confirmations via WhatsApp.
class BillingContact {
  final String? email;
  final String? whatsApp;   // international format, e.g. +2348012345678
  final String? fullName;

  const BillingContact({this.email, this.whatsApp, this.fullName});

  bool get isEmpty => (email == null || email!.isEmpty) &&
      (whatsApp == null || whatsApp!.isEmpty);

  factory BillingContact.fromJson(Map<String, dynamic> json) => BillingContact(
        email:    json['email']      as String?,
        whatsApp: json['whats_app']  as String?,
        fullName: json['full_name']  as String?,
      );

  Map<String, dynamic> toJson() => {
        if (email    != null && email!.isNotEmpty)    'email':     email,
        if (whatsApp != null && whatsApp!.isNotEmpty) 'whats_app': whatsApp,
        if (fullName != null && fullName!.isNotEmpty) 'full_name': fullName,
      };
}

// ── Platform Payment Account ──────────────────────────────────────────────────

/// The platform's receiving account — where subscribers send payment.
/// Returned by the backend; a placeholder is shown if the endpoint is absent.
class PlatformPaymentAccount {
  final String  bankName;
  final String  accountNumber;
  final String  accountName;
  final String? sortCode;
  final String? paymentLink;   // Paystack / Flutterwave link for online payment
  final String  currency;      // e.g. 'NGN', 'USD'

  const PlatformPaymentAccount({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.sortCode,
    this.paymentLink,
    this.currency = 'NGN',
  });

  factory PlatformPaymentAccount.fromJson(Map<String, dynamic> json) =>
      PlatformPaymentAccount(
        bankName:      json['bank_name']      as String? ?? '',
        accountNumber: json['account_number'] as String? ?? '',
        accountName:   json['account_name']   as String? ?? '',
        sortCode:      json['sort_code']      as String?,
        paymentLink:   json['payment_link']   as String?,
        currency:      json['currency']       as String? ?? 'NGN',
      );

  /// Shown when the backend has not yet configured a receiving account.
  factory PlatformPaymentAccount.placeholder() => const PlatformPaymentAccount(
        bankName:      'First Bank Nigeria',
        accountNumber: '3012345678',
        accountName:   'PharmApp Technologies Ltd',
        currency:      'NGN',
      );
}


// ── Invoice ───────────────────────────────────────────────────────────────────

enum InvoiceStatus {
  paid,
  pending,
  failed;

  static InvoiceStatus fromString(String? v) => switch (v) {
        'paid'    => InvoiceStatus.paid,
        'pending' => InvoiceStatus.pending,
        'failed'  => InvoiceStatus.failed,
        _         => InvoiceStatus.pending,
      };

  String get displayName => switch (this) {
        paid    => 'Paid',
        pending => 'Pending',
        failed  => 'Failed',
      };
}

class Invoice {
  final String        id;
  final DateTime      date;
  final double        amount;
  final InvoiceStatus status;
  final String?       downloadUrl;
  final String?       description;

  const Invoice({
    required this.id,
    required this.date,
    required this.amount,
    required this.status,
    this.downloadUrl,
    this.description,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id:          json['id'] as String? ?? '',
        date:        DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        amount:      (json['amount'] as num?)?.toDouble() ?? 0,
        status:      InvoiceStatus.fromString(json['status'] as String?),
        downloadUrl: json['download_url'] as String?,
        description: json['description'] as String?,
      );
}

// ── Payment Method ────────────────────────────────────────────────────────────

class PaymentMethod {
  final String brand;   // e.g. 'Visa', 'Mastercard'
  final String last4;
  final int    expMonth;
  final int    expYear;

  const PaymentMethod({
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
  });

  String get maskedNumber => '**** **** **** $last4';
  String get expiry       => '${expMonth.toString().padLeft(2, '0')}/$expYear';

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        brand:    json['brand'] as String? ?? 'Card',
        last4:    json['last4'] as String? ?? '****',
        expMonth: (json['exp_month'] as num?)?.toInt() ?? 1,
        expYear:  (json['exp_year']  as num?)?.toInt() ?? 2099,
      );
}

// ── Billing Info ──────────────────────────────────────────────────────────────

class BillingInfo {
  final DateTime?              nextPaymentDate;
  final double?                nextPaymentAmount;
  final PaymentMethod?         paymentMethod;
  final List<Invoice>          invoices;
  /// Subscriber's email + WhatsApp contact for billing notifications.
  final BillingContact?        billingContact;
  /// Platform bank/payment account that receives subscription payments.
  final PlatformPaymentAccount? platformAccount;
  /// Whether auto-billing (auto-renewal) is enabled for this subscription.
  final bool                   autoBillingEnabled;

  const BillingInfo({
    this.nextPaymentDate,
    this.nextPaymentAmount,
    this.paymentMethod,
    this.invoices            = const [],
    this.billingContact,
    this.platformAccount,
    this.autoBillingEnabled  = false,
  });

  factory BillingInfo.fromJson(Map<String, dynamic> json) => BillingInfo(
        nextPaymentDate:   json['next_payment_date'] != null
            ? DateTime.tryParse(json['next_payment_date'] as String)
            : null,
        nextPaymentAmount: (json['next_payment_amount'] as num?)?.toDouble(),
        paymentMethod: json['payment_method'] != null
            ? PaymentMethod.fromJson(
                json['payment_method'] as Map<String, dynamic>)
            : null,
        invoices: (json['invoices'] as List<dynamic>?)
                ?.map((e) => Invoice.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        billingContact: json['billing_contact'] != null
            ? BillingContact.fromJson(
                json['billing_contact'] as Map<String, dynamic>)
            : null,
        platformAccount: json['platform_account'] != null
            ? PlatformPaymentAccount.fromJson(
                json['platform_account'] as Map<String, dynamic>)
            : null,
        autoBillingEnabled:
            (json['auto_billing_enabled'] as bool?) ?? false,
      );

  /// Placeholder used while loading or when the backend has no data.
  factory BillingInfo.empty() => BillingInfo(
        platformAccount: PlatformPaymentAccount.placeholder(),
      );
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
  /// Features added by a superuser beyond what the plan includes.
  final Set<String>        extraFeatures;
  /// Features removed by a superuser from what the plan normally includes.
  final Set<String>        removedFeatures;
  /// Dynamic feature matrix from backend: plan_name → set of feature keys.
  /// Null when the backend doesn't yet support the endpoint (falls back to hardcoded).
  final Map<String, Set<String>>? planFeatures;
  /// Human-readable labels for feature keys, editable by superusers in Django admin.
  final Map<String, String>?      featureLabels;
  /// Ordered list of feature keys for the comparison table.
  final List<String>?             featureOrder;
  /// Dynamic plan prices from backend: plan_name → monthly price in USD.
  /// Null when the backend doesn't include pricing (falls back to hardcoded defaults).
  final Map<String, double>?      planPrices;

  Subscription({
    required this.plan,
    required this.status,
    this.billingCycle    = BillingCycle.monthly,
    this.trialEndsAt,
    this.currentPeriodEnd,
    required this.limits,
    required this.features,
    required this.usage,
    this.extraFeatures   = const {},
    this.removedFeatures = const {},
    this.planFeatures,
    this.featureLabels,
    this.featureOrder,
    this.planPrices,
  });

  // ── Dynamic feature helpers ───────────────────────────────────────────────

  /// Feature set for [plan] using backend data if available, else hardcoded defaults.
  Set<String> featuresForPlan(SubscriptionPlan p) =>
      planFeatures?[p.name] ?? SaasFeature.forPlan(p);

  /// Display label for a feature key — backend label wins over hardcoded.
  String featureLabel(String key) =>
      featureLabels?[key] ?? _defaultFeatureLabel(key);

  /// Ordered feature keys for the comparison matrix.
  List<String> get comparisonFeatureOrder =>
      featureOrder ?? _defaultFeatureOrder;

  static String _defaultFeatureLabel(String f) => switch (f) {
        SaasFeature.pos             => 'Point of Sale',
        SaasFeature.inventory       => 'Inventory Management',
        SaasFeature.customers       => 'Customer Management',
        SaasFeature.userManagement  => 'User Management',
        SaasFeature.basicReports    => 'Basic Reports',
        SaasFeature.advancedReports => 'Advanced Reports',
        SaasFeature.wholesale       => 'Wholesale Module',
        SaasFeature.exportData      => 'Export Data',
        SaasFeature.multiBranch     => 'Multi-Branch',
        SaasFeature.prioritySupport => 'Priority Support',
        _                           => f,
      };

  static const _defaultFeatureOrder = [
    SaasFeature.pos,
    SaasFeature.inventory,
    SaasFeature.customers,
    SaasFeature.userManagement,
    SaasFeature.basicReports,
    SaasFeature.advancedReports,
    SaasFeature.wholesale,
    SaasFeature.exportData,
    SaasFeature.multiBranch,
    SaasFeature.prioritySupport,
  ];

  // ── Dynamic price helpers ─────────────────────────────────────────────────

  /// Monthly price for [p] — uses backend value if available, else enum default.
  double monthlyAmountForPlan(SubscriptionPlan p) =>
      planPrices?[p.name] ?? p.monthlyAmount;

  /// Annual total for [p] (20 % discount applied to backend price too).
  double annualTotalForPlan(SubscriptionPlan p) {
    final monthly = monthlyAmountForPlan(p);
    return (monthly * 0.80 * 12 * 100).roundToDouble() / 100;
  }

  /// Annual savings vs 12 × monthly for [p].
  double annualSavingsForPlan(SubscriptionPlan p) {
    final monthly = monthlyAmountForPlan(p);
    return (monthly * 12 * 100).roundToDouble() / 100 - annualTotalForPlan(p);
  }

  /// Formatted price label for [p] at [cycle].
  String priceLabelForPlan(SubscriptionPlan p, BillingCycle cycle) {
    final monthly = monthlyAmountForPlan(p);
    if (monthly == 0) return 'Free';
    return switch (cycle) {
      BillingCycle.monthly =>
        '₦${monthly.toStringAsFixed(2)}/mo',
      BillingCycle.annual =>
        '₦${(monthly * 0.80).toStringAsFixed(2)}/mo · ₦${annualTotalForPlan(p).toStringAsFixed(2)}/yr',
    };
  }

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

    final extraFeatures = (json['extra_features'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toSet() ??
        <String>{};
    final removedFeatures = (json['removed_features'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toSet() ??
        <String>{};

    // Effective features = plan defaults + extras − removed
    final effectiveFeatures = SaasFeature.forPlan(plan)
      ..addAll(extraFeatures)
      ..removeAll(removedFeatures);

    // Custom limits override plan defaults if provided
    final customLimitsJson = json['custom_limits'] as Map<String, dynamic>?;
    final limits = customLimitsJson != null
        ? UsageLimits(
            maxUsers: (customLimitsJson['max_users'] as num?)?.toInt() ??
                UsageLimits.forPlan(plan).maxUsers,
            maxItems: (customLimitsJson['max_items'] as num?)?.toInt() ??
                UsageLimits.forPlan(plan).maxItems,
            maxTransactionsPerMonth:
                (customLimitsJson['max_transactions_per_month'] as num?)
                        ?.toInt() ??
                    UsageLimits.forPlan(plan).maxTransactionsPerMonth,
            maxBranches: (customLimitsJson['max_branches'] as num?)?.toInt() ??
                UsageLimits.forPlan(plan).maxBranches,
          )
        : UsageLimits.forPlan(plan);

    // Dynamic plan feature matrix from backend
    Map<String, Set<String>>? planFeatures;
    if (json['plan_features'] is Map) {
      planFeatures = (json['plan_features'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as List<dynamic>).map((e) => e as String).toSet()),
      );
    }

    Map<String, String>? featureLabels;
    if (json['feature_labels'] is Map) {
      featureLabels = (json['feature_labels'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      );
    }

    List<String>? featureOrder;
    if (json['feature_order'] is List) {
      featureOrder = (json['feature_order'] as List<dynamic>).cast<String>();
    }

    // Dynamic plan prices from backend.
    // Backend sends `plan_pricing` — a nested dict: {plan: {monthly_price, annual_price, ...}}
    // Fall back to flat `plan_prices` {plan: double} for older backend versions.
    Map<String, double>? planPrices;
    if (json['plan_pricing'] is Map) {
      planPrices = {};
      for (final entry
          in (json['plan_pricing'] as Map<String, dynamic>).entries) {
        final v = entry.value;
        if (v is Map) {
          planPrices[entry.key] =
              (v['monthly_price'] as num?)?.toDouble() ?? 0.0;
        } else if (v is num) {
          planPrices[entry.key] = v.toDouble();
        }
      }
    } else if (json['plan_prices'] is Map) {
      planPrices = (json['plan_prices'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      );
    }

    // If the backend sent plan_features, recompute effective features using
    // the backend-defined baseline for THIS plan (instead of the hardcoded one)
    if (planFeatures != null) {
      final backendBase = planFeatures[plan.name] ?? <String>{};
      final recomputed  = Set<String>.from(backendBase)
        ..addAll(extraFeatures)
        ..removeAll(removedFeatures);
      effectiveFeatures
        ..clear()
        ..addAll(recomputed);
    }

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
      limits:          limits,
      features:        effectiveFeatures,
      extraFeatures:   extraFeatures,
      removedFeatures: removedFeatures,
      planFeatures:    planFeatures,
      featureLabels:   featureLabels,
      featureOrder:    featureOrder,
      planPrices:      planPrices,
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
