from datetime import timedelta
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
        from customers.models import Customer

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
                created_at__gte=month_start,
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
        return {
            'plan':               self.plan,
            'status':             self.status,
            'trial_ends_at':      self.trial_ends_at.isoformat()      if self.trial_ends_at      else None,
            'current_period_end': self.current_period_end.isoformat() if self.current_period_end else None,
            'usage':              self._usage(),
        }

    def __str__(self):
        return f"{self.organization.name} — {self.plan} ({self.status})"

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
