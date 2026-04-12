from django.db import models
from authapp.models import Organization


class Branch(models.Model):
    """
    A physical branch location belonging to an Organization.
    Only Professional (max 3) and Enterprise (unlimited) plans can have
    more than one branch. Enforced at the API layer.
    """
    organization = models.ForeignKey(
        Organization,
        on_delete=models.CASCADE,
        related_name='branches',
    )
    name         = models.CharField(max_length=200)
    address      = models.TextField(blank=True, default='')
    phone        = models.CharField(max_length=30, blank=True, default='')
    email        = models.EmailField(blank=True, default='')
    is_active    = models.BooleanField(
        default=True,
        help_text='Inactive branches are hidden from the app but their data is preserved.',
    )
    is_main      = models.BooleanField(
        default=False,
        help_text='The primary / head-office branch. Only one per org.',
    )
    created_at   = models.DateTimeField(auto_now_add=True)
    updated_at   = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name        = 'Branch'
        verbose_name_plural = 'Branches'
        ordering            = ['-is_main', 'name']
        unique_together     = ('organization', 'name')

    def __str__(self):
        tag = ' [main]' if self.is_main else ''
        return f"{self.organization.name} — {self.name}{tag}"

    def to_api_dict(self):
        return {
            'id':         self.pk,
            'name':       self.name,
            'address':    self.address,
            'phone':      self.phone,
            'email':      self.email,
            'isActive':   self.is_active,
            'isMain':     self.is_main,
            'createdAt':  self.created_at.isoformat(),
        }
