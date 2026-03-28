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
    plan   = models.CharField(max_length=20, choices=PLAN_CHOICES, default='trial')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='trial')

    trial_ends_at      = models.DateTimeField(null=True, blank=True)
    current_period_end = models.DateTimeField(null=True, blank=True)

    # Optional reference to an external payment provider (Stripe, Flutterwave, etc.)
    external_subscription_id = models.CharField(max_length=200, blank=True, default='')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name        = 'Subscription'
        verbose_name_plural = 'Subscriptions'

    # ── Status refresh ────────────────────────────────────────────────────────

    def refresh_status(self):
        """Recalculate status from dates — call before reading status."""
        # Never auto-override a manually-set terminal status
        if self.status in ('suspended', 'cancelled'):
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

        return {
            'users_count':             users_count,
            'items_count':             items_count,
            'transactions_this_month': tx_count,
            'branches_count':          1,
        }

    # ── API serialization ─────────────────────────────────────────────────────

    def to_api_dict(self):
        self.refresh_status()
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
        return {
            'plan':               self.plan,
            'status':             self.status,
            'trial_ends_at':      self.trial_ends_at.isoformat()      if self.trial_ends_at      else None,
            'current_period_end': self.current_period_end.isoformat() if self.current_period_end else None,
            'usage':              self._usage(),
            'plan_pricing':       pricing,
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
