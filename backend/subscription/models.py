from datetime import timedelta
from decimal import Decimal
from django.db import models
from django.utils import timezone
from authapp.models import Organization


PLAN_CHOICES = [
    ('trial',        'Free Trial'),
    ('starter',      'Starter'),
    ('professional', 'Professional'),
    ('enterprise',   'Enterprise'),
]

STATUS_CHOICES = [
    ('trial',     'Trial'),
    ('expiring',  'Trial Expiring'),
    ('expired',   'Expired'),
    ('active',    'Active'),
    ('pending',   'Pending Approval'),
    ('suspended', 'Suspended'),
    ('cancelled', 'Cancelled'),
]

TRIAL_DAYS = 14

# Plan hard limits  (-1 = unlimited)
PLAN_LIMITS = {
    'trial':        {'users': 2,  'items': 50,  'transactions': 200},
    'starter':      {'users': 5,  'items': 500, 'transactions': 2_000},
    'professional': {'users': 15, 'items': -1,  'transactions': -1},
    'enterprise':   {'users': -1, 'items': -1,  'transactions': -1},
}

PLAN_FEATURES = {
    'trial': [
        ('✅', 'Basic POS (retail)'),
        ('✅', 'Inventory — up to 50 items'),
        ('✅', 'Customer management'),
        ('✅', '2 active users'),
        ('✅', '200 transactions / month'),
        ('❌', 'Reports & analytics'),
        ('❌', 'Wholesale module'),
        ('❌', 'Expenses & suppliers'),
        ('❌', 'Payment requests'),
        ('❌', 'Priority support'),
    ],
    'starter': [
        ('✅', 'Full POS (retail + wholesale)'),
        ('✅', 'Inventory — up to 500 items'),
        ('✅', 'Customer management + wallets'),
        ('✅', '5 active users'),
        ('✅', '2,000 transactions / month'),
        ('✅', 'Basic reports (sales, inventory)'),
        ('✅', 'Expenses & suppliers'),
        ('❌', 'Profit & customer reports'),
        ('❌', 'Payment requests'),
        ('❌', 'Priority support'),
    ],
    'professional': [
        ('✅', 'Full POS (retail + wholesale)'),
        ('✅', 'Unlimited inventory'),
        ('✅', 'Customer management + wallets'),
        ('✅', '15 active users'),
        ('✅', 'Unlimited transactions'),
        ('✅', 'All reports + profit analytics'),
        ('✅', 'Expenses, suppliers & procurement'),
        ('✅', 'Payment requests'),
        ('✅', 'Stock checks & dispensing log'),
        ('❌', 'Priority support'),
    ],
    'enterprise': [
        ('✅', 'Full POS (retail + wholesale)'),
        ('✅', 'Unlimited inventory'),
        ('✅', 'Customer management + wallets'),
        ('✅', 'Unlimited users'),
        ('✅', 'Unlimited transactions'),
        ('✅', 'All reports + profit analytics'),
        ('✅', 'Expenses, suppliers & procurement'),
        ('✅', 'Payment requests'),
        ('✅', 'Stock checks & dispensing log'),
        ('✅', 'Priority support & SLA'),
    ],
}

PLAN_PRICES = {
    'trial':        0,
    'starter':      9.99,
    'professional': 29.99,
    'enterprise':   79.99,
}

SUPPORTED_CURRENCIES = ['USD', 'GBP', 'EUR', 'NGN', 'GHS', 'KES', 'ZAR']


# ── Editable plan pricing ─────────────────────────────────────────────────────

class PlanPricing(models.Model):
    """
    Database-editable price per plan.  Superusers edit via the admin pricing
    editor.  Falls back to PLAN_PRICES constants if no DB row exists.
    """
    plan          = models.CharField(max_length=20, choices=PLAN_CHOICES, unique=True)
    monthly_price = models.DecimalField(max_digits=10, decimal_places=2,
                                        default=Decimal('0.00'))
    annual_price  = models.DecimalField(
        max_digits=10, decimal_places=2, default=Decimal('0.00'),
        help_text='Full yearly price (total for 12 months). Set to 0 to disable annual billing.',
    )
    currency      = models.CharField(max_length=3, default='USD')
    is_active     = models.BooleanField(
        default=True,
        help_text='Inactive plans are hidden from the in-app upgrade screen.',
    )
    updated_at    = models.DateTimeField(auto_now=True)
    updated_by    = models.CharField(max_length=150, blank=True, default='')

    class Meta:
        verbose_name        = 'Plan Pricing'
        verbose_name_plural = 'Plan Pricing'
        ordering            = ['monthly_price']

    def __str__(self):
        return f"{self.get_plan_display()} — {self.currency} {self.monthly_price}/mo"

    # ── Helpers ───────────────────────────────────────────────────────────────

    @property
    def annual_savings_pct(self):
        """Discount % compared to paying monthly for 12 months."""
        if not self.annual_price or not self.monthly_price:
            return 0
        equiv = self.monthly_price * 12
        if equiv <= 0:
            return 0
        return max(int((equiv - self.annual_price) / equiv * 100), 0)

    @property
    def monthly_if_annual(self):
        """Effective monthly cost when billed annually."""
        if self.annual_price:
            return round(self.annual_price / 12, 2)
        return self.monthly_price

    # ── Class-level helpers used across admin / views ─────────────────────────

    @classmethod
    def get_price(cls, plan):
        """Monthly price for `plan` as Decimal.  Fallback to PLAN_PRICES."""
        try:
            return cls.objects.get(plan=plan).monthly_price
        except cls.DoesNotExist:
            return Decimal(str(PLAN_PRICES.get(plan, 0)))

    @classmethod
    def get_all_prices(cls):
        """{plan: float} starting from PLAN_PRICES defaults, DB values win."""
        result = dict(PLAN_PRICES)
        for pp in cls.objects.all():
            result[pp.plan] = float(pp.monthly_price)
        return result

    @classmethod
    def ensure_defaults(cls):
        """Create missing rows from PLAN_PRICES defaults (idempotent)."""
        for plan, price in PLAN_PRICES.items():
            cls.objects.get_or_create(
                plan=plan,
                defaults={'monthly_price': Decimal(str(price))},
            )


BILLING_CYCLE_CHOICES = [
    ('monthly', 'Monthly'),
    ('annual',  'Annual'),
]

# ── All known feature keys (canonical order) ──────────────────────────────────

FEATURE_KEY_CHOICES = [
    ('pos',              'Point of Sale'),
    ('inventory',        'Inventory Management'),
    ('customers',        'Customer Management'),
    ('user_management',  'User Management'),
    ('basic_reports',    'Basic Reports'),
    ('advanced_reports', 'Advanced Reports'),
    ('wholesale',        'Wholesale Module'),
    ('export_data',      'Export Data'),
    ('multi_branch',     'Multi-Branch'),
    ('priority_support', 'Priority Support'),
]

# Default features per plan — used as fallback if no DB rows exist.
PLAN_FEATURES_DEFAULT = {
    'trial':        {'pos', 'inventory'},
    'starter':      {'pos', 'inventory', 'customers', 'user_management', 'basic_reports'},
    'professional': {'pos', 'inventory', 'customers', 'user_management', 'basic_reports',
                     'advanced_reports', 'wholesale', 'export_data', 'multi_branch'},
    'enterprise':   {'pos', 'inventory', 'customers', 'user_management', 'basic_reports',
                     'advanced_reports', 'wholesale', 'export_data',
                     'multi_branch', 'priority_support'},
}


class PlanFeatureFlag(models.Model):
    """
    Controls which features are included in each subscription plan.
    Superusers edit this via the Django admin matrix to add, remove, or rename
    features per plan. The Flutter app reads these flags from the subscription
    API and uses them to render the feature comparison table dynamically.
    """
    plan          = models.CharField(max_length=20, choices=PLAN_CHOICES, db_index=True)
    feature_key   = models.CharField(
        max_length=50, choices=FEATURE_KEY_CHOICES,
        help_text='Internal key used by the Flutter app to gate feature access.',
    )
    feature_label = models.CharField(
        max_length=100,
        help_text='Display name shown in the subscription screen feature table.',
    )
    is_enabled    = models.BooleanField(
        default=True,
        help_text='Uncheck to remove this feature from the plan.',
    )
    sort_order    = models.PositiveSmallIntegerField(
        default=0,
        help_text='Controls the row order in the feature comparison table.',
    )

    class Meta:
        unique_together     = ('plan', 'feature_key')
        ordering            = ['sort_order', 'plan', 'feature_key']
        verbose_name        = 'Plan Feature Flag'
        verbose_name_plural = 'Plan Feature Flags'

    def __str__(self):
        state = '✅' if self.is_enabled else '❌'
        return f"{state} {self.get_plan_display()} → {self.feature_label}"

    # ── Class-level helpers ───────────────────────────────────────────────────

    @classmethod
    def get_features_for_plan(cls, plan):
        """
        Returns a set of enabled feature keys for the given plan.
        Falls back to PLAN_FEATURES_DEFAULT if no DB rows exist for this plan.
        """
        qs = cls.objects.filter(plan=plan, is_enabled=True).values_list('feature_key', flat=True)
        if qs.exists():
            return set(qs)
        return set(PLAN_FEATURES_DEFAULT.get(plan, set()))

    @classmethod
    def get_all_features_matrix(cls):
        """
        Returns a dict: {plan: list[feature_key]} for all plans,
        and a feature label dict: {feature_key: label}.
        Used by the subscription API so Flutter can render the comparison table.
        """
        plan_features = {}
        for plan, _ in PLAN_CHOICES:
            plan_features[plan] = sorted(cls.get_features_for_plan(plan))

        # Build label map from DB rows first, then fill gaps from FEATURE_KEY_CHOICES
        label_map = {key: label for key, label in FEATURE_KEY_CHOICES}
        for row in cls.objects.values('feature_key', 'feature_label'):
            label_map[row['feature_key']] = row['feature_label']

        # All feature keys that appear in at least one plan, in canonical sort order
        all_keys_in_use = {k for keys in plan_features.values() for k in keys}
        canonical_order = [k for k, _ in FEATURE_KEY_CHOICES if k in all_keys_in_use]
        # Append any DB-only keys not in the canonical list
        for row in cls.objects.values_list('feature_key', flat=True).distinct():
            if row not in canonical_order:
                canonical_order.append(row)

        return {
            'plan_features':  plan_features,
            'feature_labels': {k: label_map.get(k, k) for k in canonical_order},
            'feature_order':  canonical_order,
        }

    @classmethod
    def ensure_defaults(cls):
        """
        Seeds the table from PLAN_FEATURES_DEFAULT if it is empty.
        Fast path — skips entirely when the table already has rows.
        For an additive sync that fills gaps in an existing table use sync_defaults().
        """
        if cls.objects.exists():
            return
        cls.sync_defaults()

    @classmethod
    def sync_defaults(cls):
        """
        Additive sync: for every (plan, feature_key) pair in PLAN_FEATURES_DEFAULT,
        create the row if it does not exist.  Existing rows are NEVER modified or
        deleted — this only adds what is missing.

        Covers all plans (trial / starter / professional / enterprise) and all
        features in PLAN_FEATURES_DEFAULT.  Safe to call repeatedly (idempotent).

        Returns a dict  { 'added': N, 'already_present': M }  for reporting.
        """
        label_map  = dict(FEATURE_KEY_CHOICES)
        sort_map   = {k: i for i, (k, _) in enumerate(FEATURE_KEY_CHOICES)}
        added      = 0
        already    = 0

        for plan, feature_set in PLAN_FEATURES_DEFAULT.items():
            for key in feature_set:
                _, created = cls.objects.get_or_create(
                    plan=plan,
                    feature_key=key,
                    defaults={
                        'feature_label': label_map.get(key, key),
                        'is_enabled':    True,
                        'sort_order':    sort_map.get(key, 99),
                    },
                )
                if created:
                    added += 1
                else:
                    already += 1

        return {'added': added, 'already_present': already}


class Subscription(models.Model):
    """
    One subscription per Organization — created automatically when the org is
    registered (via a post-save signal or register_org_view) and defaults to a
    14-day free trial.
    """
    organization = models.OneToOneField(
        Organization,
        on_delete=models.CASCADE,
        related_name='subscription',
    )
    plan          = models.CharField(max_length=20, choices=PLAN_CHOICES, default='trial')
    status        = models.CharField(max_length=20, choices=STATUS_CHOICES, default='trial')
    billing_cycle = models.CharField(
        max_length=10,
        choices=BILLING_CYCLE_CHOICES,
        default='monthly',
        help_text='Monthly or annual billing. Annual shows a discounted total/year price.',
    )

    trial_ends_at      = models.DateTimeField(null=True, blank=True)
    current_period_end = models.DateTimeField(null=True, blank=True)

    # Optional reference to an external payment provider (Stripe, Flutterwave, etc.)
    external_subscription_id = models.CharField(max_length=200, blank=True, default='')

    # ── Superuser feature overrides ──────────────────────────────────────────────
    # Features added beyond what the plan normally includes (list of feature keys).
    extra_features   = models.JSONField(
        default=list, blank=True,
        help_text=(
            'Feature keys enabled for this org beyond the plan default. '
            'Valid keys: pos, inventory, customers, user_management, basic_reports, '
            'advanced_reports, wholesale, export_data, multi_branch, priority_support'
        ),
    )
    # Features removed from what the plan normally includes.
    removed_features = models.JSONField(
        default=list, blank=True,
        help_text='Feature keys explicitly disabled for this org (overrides plan default).',
    )

    # ── Custom usage limits (null = use plan default) ─────────────────────────────
    custom_max_users         = models.IntegerField(
        null=True, blank=True,
        help_text='Override max staff users. -1 = unlimited. Leave blank for plan default.',
    )
    custom_max_items         = models.IntegerField(
        null=True, blank=True,
        help_text='Override max inventory items. -1 = unlimited. Leave blank for plan default.',
    )
    custom_max_transactions  = models.IntegerField(
        null=True, blank=True,
        help_text='Override max transactions/month. -1 = unlimited. Leave blank for plan default.',
    )
    custom_max_branches      = models.IntegerField(
        null=True, blank=True,
        help_text='Override max branches. -1 = unlimited. Leave blank for plan default.',
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name        = 'Subscription'
        verbose_name_plural = 'Subscriptions'

    # ── Status refresh ────────────────────────────────────────────────────────

    def refresh_status(self):
        """Recalculate status from dates — call before reading status."""
        # Never auto-override a manually-set terminal status or a pending approval
        if self.status in ('suspended', 'cancelled', 'pending'):
            return
        if self.plan == 'trial':
            if not self.trial_ends_at:
                self.status = 'trial'
                return
            now       = timezone.now()
            days_left = (self.trial_ends_at - now).days
            if days_left < 0:
                self.status = 'expired'
            elif days_left <= 7:
                self.status = 'expiring'
            else:
                self.status = 'trial'
        # Paid plans: status set explicitly by payment webhook / admin

    def save(self, *args, **kwargs):
        self.refresh_status()
        super().save(*args, **kwargs)

    # ── Usage snapshot ────────────────────────────────────────────────────────

    def _usage(self):
        from inventory.models import Item

        org   = self.organization
        now   = timezone.now()
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

        users_count = org.users.filter(is_active=True).count()
        items_count = Item.objects.filter(organization=org, status='active').count()

        # Import Sale lazily to avoid circular import
        try:
            from pos.models import Sale
            tx_count = Sale.objects.filter(
                organization=org,
                created__gte=month_start,
            ).count()
        except Exception:
            tx_count = 0

        try:
            from branches.models import Branch
            branches_count = Branch.objects.filter(organization=org, is_active=True).count()
        except Exception:
            branches_count = 1

        return {
            'users_count':             users_count,
            'items_count':             items_count,
            'transactions_this_month': tx_count,
            'branches_count':          branches_count,
        }

    # ── API serialization ─────────────────────────────────────────────────────

    def to_api_dict(self):
        self.refresh_status()
        # Seed feature flags on first call if table is empty
        PlanFeatureFlag.ensure_defaults()
        # Seed plan pricing rows so Django admin shows editable entries
        PlanPricing.ensure_defaults()
        # Inline plan pricing so Flutter always shows current prices
        pricing = {}
        for pp in PlanPricing.objects.all():
            pricing[pp.plan] = {
                'monthly_price':  float(pp.monthly_price),
                'annual_price':   float(pp.annual_price),
                'currency':       pp.currency,
                'is_active':      pp.is_active,
                'savings_pct':    pp.annual_savings_pct,
            }
        # Ensure every plan has an entry (fallback to hardcoded defaults)
        for plan, price in PLAN_PRICES.items():
            if plan not in pricing:
                pricing[plan] = {
                    'monthly_price': price,
                    'annual_price':  0,
                    'currency':      'USD',
                    'is_active':     True,
                    'savings_pct':   0,
                }
        # Build custom_limits dict only if at least one limit is overridden
        plan_limits = PLAN_LIMITS.get(self.plan, {})
        custom_limits = None
        if any(v is not None for v in [
            self.custom_max_users, self.custom_max_items,
            self.custom_max_transactions, self.custom_max_branches,
        ]):
            custom_limits = {
                'max_users':
                    self.custom_max_users
                    if self.custom_max_users is not None
                    else plan_limits.get('users', -1),
                'max_items':
                    self.custom_max_items
                    if self.custom_max_items is not None
                    else plan_limits.get('items', -1),
                'max_transactions_per_month':
                    self.custom_max_transactions
                    if self.custom_max_transactions is not None
                    else plan_limits.get('transactions', -1),
                'max_branches':
                    self.custom_max_branches
                    if self.custom_max_branches is not None
                    else 1,
            }

        # Dynamic feature matrix — controls the comparison table in Flutter
        feature_matrix = PlanFeatureFlag.get_all_features_matrix()

        return {
            'plan':               self.plan,
            'status':             self.status,
            'billing_cycle':      self.billing_cycle,
            'trial_ends_at':      self.trial_ends_at.isoformat()      if self.trial_ends_at      else None,
            'current_period_end': self.current_period_end.isoformat() if self.current_period_end else None,
            'usage':              self._usage(),
            'plan_pricing':       pricing,
            'extra_features':     list(self.extra_features or []),
            'removed_features':   list(self.removed_features or []),
            'custom_limits':      custom_limits,
            # Feature comparison table data (editable in Django admin)
            'plan_features':      feature_matrix['plan_features'],
            'feature_labels':     feature_matrix['feature_labels'],
            'feature_order':      feature_matrix['feature_order'],
        }

    def __str__(self):
        return f"{self.organization.name} — {self.plan} ({self.status})"

    @property
    def trial_days_remaining(self):
        if self.plan != 'trial' or not self.trial_ends_at:
            return None
        return max((self.trial_ends_at - timezone.now()).days, 0)

    # ── Factory ────────────────────────────────────────────────────────────────

    @classmethod
    def get_or_create_trial(cls, org):
        """Return existing subscription or create a fresh trial for `org`."""
        sub, created = cls.objects.get_or_create(
            organization=org,
            defaults={
                'plan':          'trial',
                'status':        'trial',
                'trial_ends_at': timezone.now() + timedelta(days=TRIAL_DAYS),
            },
        )
        if not created:
            sub.refresh_status()
            sub.save(update_fields=['status'])
        return sub


# ── Audit event log ───────────────────────────────────────────────────────────

class SubscriptionEvent(models.Model):
    """
    Immutable audit trail of every significant subscription change.
    Written by the admin quick-actions, save_model, and API endpoints.
    Never modified or deleted.
    """

    EVENT_CHOICES = [
        ('plan_changed',   'Plan Changed'),
        ('status_changed', 'Status Changed'),
        ('trial_extended', 'Trial Extended'),
        ('activated',      'Activated'),
        ('suspended',      'Suspended'),
        ('reactivated',    'Reactivated'),
        ('cancelled',      'Cancelled'),
        ('reset',          'Reset to Trial'),
        ('note',           'Admin Note'),
    ]

    subscription = models.ForeignKey(
        Subscription,
        on_delete=models.CASCADE,
        related_name='events',
    )
    event_type   = models.CharField(max_length=30, choices=EVENT_CHOICES)
    old_value    = models.CharField(max_length=100, blank=True, default='')
    new_value    = models.CharField(max_length=100, blank=True, default='')
    note         = models.TextField(blank=True, default='')
    performed_by = models.CharField(max_length=150, default='system',
                                    help_text='Username, "system", or "api"')
    created_at   = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering            = ['-created_at']
        verbose_name        = 'Subscription Event'
        verbose_name_plural = 'Subscription Events'

    def __str__(self):
        ts = self.created_at.strftime('%Y-%m-%d %H:%M') if self.created_at else '—'
        return f"{self.get_event_type_display()} ({ts})"


# ── Payment receiving accounts ─────────────────────────────────────────────────

PAYMENT_TYPE_CHOICES = [
    ('bank_transfer', 'Bank Transfer'),
    ('mobile_money',  'Mobile Money'),
    ('paypal',        'PayPal'),
    ('payoneer',      'Payoneer'),
    ('flutterwave',   'Flutterwave'),
    ('stripe',        'Stripe'),
    ('crypto',        'Cryptocurrency'),
    ('other',         'Other'),
]


class PaymentAccount(models.Model):
    """
    Payment receiving accounts that pharmacy admins can use to pay for
    their subscription.  Superusers manage these via Django admin.
    The Flutter app fetches the active list from GET /api/subscription/payment-accounts/
    and displays them on the upgrade / payment screen.
    """

    account_type   = models.CharField(
        max_length=20,
        choices=PAYMENT_TYPE_CHOICES,
        default='bank_transfer',
        help_text='Payment method / channel type.',
    )
    label          = models.CharField(
        max_length=100,
        help_text='Short display name shown to customers (e.g. "GTBank — NGN Account").',
    )
    account_name   = models.CharField(
        max_length=150,
        help_text='Name of the account holder.',
    )
    bank_name      = models.CharField(
        max_length=150,
        blank=True,
        default='',
        help_text='Bank or provider name (leave blank for PayPal / crypto).',
    )
    account_number = models.CharField(
        max_length=200,
        help_text='Account number, phone number, email address, or wallet address.',
    )
    routing_info   = models.CharField(
        max_length=100,
        blank=True,
        default='',
        help_text='Sort code, routing number, SWIFT / BIC, or branch code (optional).',
    )
    currency       = models.CharField(
        max_length=3,
        default='USD',
        help_text='ISO 4217 currency code (e.g. USD, NGN, GHS, GBP).',
    )
    country        = models.CharField(
        max_length=100,
        blank=True,
        default='',
        help_text='Country or region this account is intended for (optional).',
    )
    instructions   = models.TextField(
        blank=True,
        default='',
        help_text=(
            'Additional payment instructions shown to the customer '
            '(e.g. "Use your org name as the payment reference").'
        ),
    )
    is_active      = models.BooleanField(
        default=True,
        help_text='Only active accounts are shown in the Flutter app.',
    )
    sort_order     = models.PositiveSmallIntegerField(
        default=0,
        help_text='Lower numbers appear first.',
    )
    updated_at     = models.DateTimeField(auto_now=True)
    updated_by     = models.CharField(
        max_length=150,
        blank=True,
        default='',
        help_text='Username of the last superuser to edit this record.',
    )

    class Meta:
        verbose_name        = 'Payment Account'
        verbose_name_plural = 'Payment Accounts'
        ordering            = ['sort_order', 'currency', 'label']

    def __str__(self):
        status = '' if self.is_active else ' [inactive]'
        return f"{self.label} ({self.currency}){status}"

    def to_api_dict(self):
        return {
            'id':             self.pk,
            'account_type':   self.account_type,
            'label':          self.label,
            'account_name':   self.account_name,
            'bank_name':      self.bank_name,
            'account_number': self.account_number,
            'routing_info':   self.routing_info,
            'currency':       self.currency,
            'country':        self.country,
            'instructions':   self.instructions,
        }
