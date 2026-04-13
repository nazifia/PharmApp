import os
from pathlib import Path
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models
from django.conf import settings
from django.utils.text import slugify


class Organization(models.Model):
    """A pharmacy organization — all data is scoped to one."""
    name    = models.CharField(max_length=200)
    slug    = models.SlugField(max_length=220, unique=True, blank=True)
    address = models.TextField(blank=True, default='')
    phone   = models.CharField(max_length=20, blank=True, default='')
    logo    = models.ImageField(upload_to='org_logos/', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        if not self.slug:
            base = slugify(self.name)
            slug = base
            n = 1
            while Organization.objects.filter(slug=slug).exclude(pk=self.pk).exists():
                slug = f"{base}-{n}"
                n += 1
            self.slug = slug
        super().save(*args, **kwargs)

    def to_api_dict(self):
        return {
            'id':      self.id,
            'name':    self.name,
            'slug':    self.slug,
            'address': self.address,
            'phone':   self.phone,
            'logoUrl': self.logo.url if self.logo else None,
        }

    def __str__(self):
        return self.name


def _get_user_permissions(user):
    """Deferred import to avoid circular import at module load."""
    try:
        from authapp.permissions import get_effective_permissions
        return get_effective_permissions(user)
    except Exception:
        return {}


ROLE_CHOICES = [
    ('Admin', 'Admin'),
    ('Manager', 'Manager'),
    ('Pharmacist', 'Pharmacist'),
    ('Pharm-Tech', 'Pharm-Tech'),
    ('Salesperson', 'Salesperson'),
    ('Cashier', 'Cashier'),
    ('Wholesale Manager', 'Wholesale Manager'),
    ('Wholesale Operator', 'Wholesale Operator'),
    ('Wholesale Salesperson', 'Wholesale Salesperson'),
]

class PharmUserManager(BaseUserManager):
    def create_user(self, phone_number, password, role='Pharmacist', **extra):
        user = self.model(phone_number=phone_number, role=role, **extra)
        user.set_password(password)
        user.save()
        return user

    def create_superuser(self, phone_number, password, **extra):
        return self.create_user(phone_number, password, role='Admin',
                                is_staff=True, is_superuser=True, **extra)

class PharmUser(AbstractBaseUser, PermissionsMixin):
    phone_number         = models.CharField(max_length=20, unique=True)
    full_name            = models.CharField(max_length=200, blank=True, default="")
    role                 = models.CharField(max_length=30, choices=ROLE_CHOICES, default='Pharmacist')
    is_active            = models.BooleanField(default=True)
    is_staff             = models.BooleanField(default=False)
    is_wholesale_operator = models.BooleanField(default=False)
    organization         = models.ForeignKey(
        Organization, null=True, blank=True,
        on_delete=models.SET_NULL, related_name='users'
    )

    USERNAME_FIELD  = 'phone_number'
    REQUIRED_FIELDS = []
    objects = PharmUserManager()

    def get_full_name(self):
        return self.full_name or self.phone_number

    def to_api_dict(self):
        org = self.organization
        return {
            'id':                   self.id,
            'phoneNumber':          self.phone_number,
            'username':             self.full_name or '',
            'fullName':             self.full_name,
            'role':                 self.role,
            'isActive':             self.is_active,
            'isWholesaleOperator':  self.is_wholesale_operator,
            'isSuperuser':          self.is_superuser,
            'organizationId':       org.id      if org else 0,
            'organizationName':     org.name    if org else '',
            'organizationSlug':     org.slug    if org else '',
            'organizationAddress':  org.address if org else '',
            'organizationPhone':    org.phone   if org else '',
            'organizationLogo':     org.logo.url if org and org.logo else '',
            'permissions':          _get_user_permissions(self),
        }

    def __str__(self):
        return f"{self.full_name or self.phone_number} ({self.role})"


ALL_PERMISSIONS = [
    'viewReports', 'manageUsers', 'manageSettings', 'viewNotifications',
    'viewSubscription', 'retailPOS', 'wholesalePOS', 'viewWholesale',
    'readInventory', 'writeInventory', 'readCustomers', 'writeCustomers',
    'manageExpenses', 'manageSuppliers', 'processPayments', 'manageTransfers',
]


class UserPermissionOverride(models.Model):
    """
    Per-user permission override.
    granted=True  → explicitly GRANT this permission (even if role doesn't have it)
    granted=False → explicitly REVOKE this permission (even if role normally has it)
    """
    PERMISSION_CHOICES = [(p, p) for p in ALL_PERMISSIONS]

    user       = models.ForeignKey(
        PharmUser, on_delete=models.CASCADE, related_name='permission_overrides'
    )
    permission = models.CharField(max_length=50, choices=PERMISSION_CHOICES)
    granted    = models.BooleanField(
        default=True,
        help_text='True = grant (even if role lacks it). False = revoke (even if role has it).'
    )
    note       = models.CharField(max_length=200, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'permission')
        ordering        = ('permission',)

    def __str__(self):
        verb = 'GRANT' if self.granted else 'REVOKE'
        return f"{verb} {self.permission} → {self.user}"


# ── Site Configuration (singleton) ────────────────────────────────────────────

_ENV_FILE = Path(__file__).resolve().parent.parent / '.active_env'

SETTINGS_MAP = {
    'dev':  'pharmapi.settings.dev',
    'prod': 'pharmapi.settings.prod',
}


class SiteConfig(models.Model):
    """
    Singleton (pk=1) — controls which settings module loads on next restart.
    Saving this record writes the chosen module to .active_env so manage.py
    and wsgi.py pick it up automatically on the next server start.
    """
    ENV_CHOICES = [('dev', 'Development'), ('prod', 'Production')]

    active_environment = models.CharField(
        max_length=10,
        choices=ENV_CHOICES,
        default='dev',
        help_text='Desired environment. Takes effect after server restart.',
    )
    maintenance_mode = models.BooleanField(
        default=False,
        help_text='Block all API traffic with a 503 response.',
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name        = 'Site Configuration'
        verbose_name_plural = 'Site Configuration'

    # ── Singleton enforcement ─────────────────────────────────────────────────

    def save(self, *args, **kwargs):
        self.pk = 1
        super().save(*args, **kwargs)
        _ENV_FILE.write_text(SETTINGS_MAP[self.active_environment])

    @classmethod
    def get_solo(cls):
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj

    # ── Environment helpers ───────────────────────────────────────────────────

    @staticmethod
    def running_module():
        """Settings module currently loaded in this process."""
        return os.environ.get('DJANGO_SETTINGS_MODULE', 'pharmapi.settings.dev')

    @staticmethod
    def pending_module():
        """Settings module that will load after next restart."""
        if _ENV_FILE.exists():
            return _ENV_FILE.read_text().strip()
        return 'pharmapi.settings.dev'

    @classmethod
    def running_env(cls):
        return 'prod' if 'prod' in cls.running_module() else 'dev'

    @classmethod
    def pending_env(cls):
        return 'prod' if 'prod' in cls.pending_module() else 'dev'

    @classmethod
    def restart_needed(cls):
        return cls.running_module() != cls.pending_module()

    def __str__(self):
        return 'Site Configuration'
