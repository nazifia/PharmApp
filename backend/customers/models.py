from django.db import models
from django.utils import timezone


class Customer(models.Model):
    organization     = models.ForeignKey(
        'authapp.Organization', null=True, blank=True,
        on_delete=models.CASCADE, related_name='customers'
    )
    name             = models.CharField(max_length=200)
    phone            = models.CharField(max_length=20)
    is_wholesale     = models.BooleanField(default=False)
    wallet_balance   = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    outstanding_debt = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    email              = models.EmailField(blank=True, default='')
    address            = models.TextField(blank=True, default='')
    join_date          = models.DateField(default=timezone.now)
    last_visit         = models.DateField(null=True, blank=True)
    is_network_patient = models.BooleanField(
        default=False,
        help_text='Visible to all pharmacies in the same network for prescription lookup.',
    )
    prescriber = models.ForeignKey(
        'prescriptions.Prescriber',
        null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='patients',
    )
    blood_group        = models.CharField(max_length=5, blank=True, default='')
    date_of_birth      = models.DateField(null=True, blank=True)
    allergies            = models.JSONField(default=list, blank=True)
    chronic_conditions   = models.JSONField(default=list, blank=True)
    current_medications  = models.JSONField(default=list, blank=True)

    # HMO / Insurance
    hmo_provider        = models.CharField(max_length=100, blank=True, default='')
    hmo_plan_name       = models.CharField(max_length=100, blank=True, default='')
    hmo_card_number     = models.CharField(max_length=100, blank=True, default='')
    hmo_coverage_percent = models.DecimalField(
        max_digits=5, decimal_places=2, null=True, blank=True,
        help_text='Percentage (0–100) of sale total covered by HMO'
    )
    hmo_expiry_date     = models.DateField(null=True, blank=True)

    def total_purchases(self):
        return float(self.sales.aggregate(
            total=models.Sum('total_amount'))['total'] or 0)

    def total_spent(self):
        return self.total_purchases()

    def _hmo_dict(self):
        return {
            'hmo_provider':         self.hmo_provider or None,
            'hmo_plan_name':        self.hmo_plan_name or None,
            'hmo_card_number':      self.hmo_card_number or None,
            'hmo_coverage_percent': float(self.hmo_coverage_percent) if self.hmo_coverage_percent is not None else None,
            'hmo_expiry_date':      self.hmo_expiry_date.isoformat() if self.hmo_expiry_date else None,
        }

    def to_list_dict(self):
        d = {
            'id':                  self.id,
            'name':                self.name,
            'phone':               self.phone,
            'is_wholesale':        self.is_wholesale,
            'is_network_patient':  self.is_network_patient,
            'wallet_balance':      float(self.wallet_balance),
            'total_purchases':     self.total_purchases(),
            'outstanding_debt':    float(self.outstanding_debt),
            'blood_group':         self.blood_group or None,
            'date_of_birth':       self.date_of_birth.isoformat() if self.date_of_birth else None,
            'allergies':            self.allergies or [],
            'chronic_conditions':   self.chronic_conditions or [],
            'current_medications':  self.current_medications or [],
        }
        d.update(self._hmo_dict())
        return d

    def to_detail_dict(self):
        d = self.to_list_dict()
        d.update({
            'email':      self.email,
            'address':    self.address,
            'total_spent': self.total_spent(),
            'join_date':  self.join_date.isoformat() if self.join_date else None,
            'last_visit': self.last_visit.isoformat() if self.last_visit else None,
        })
        return d

    class Meta:
        unique_together = [('organization', 'phone')]

    def __str__(self):
        return self.name


class WalletTransaction(models.Model):
    TYPES = [('topup', 'Top-up'), ('deduct', 'Deduction'), ('purchase', 'Purchase')]
    METHODS = [('cash', 'Cash'), ('pos', 'POS'), ('transfer', 'Transfer')]

    customer  = models.ForeignKey(Customer, related_name='wallet_transactions',
                                  on_delete=models.CASCADE)
    txn_type  = models.CharField(max_length=20, choices=TYPES)
    # Funding method for top-ups (how the money came in). Blank for other types
    # and for legacy top-ups recorded before this field existed.
    method    = models.CharField(max_length=20, choices=METHODS, blank=True, default='')
    amount    = models.DecimalField(max_digits=12, decimal_places=2)
    note      = models.CharField(max_length=300, blank=True, default='')
    created   = models.DateTimeField(auto_now_add=True)

    def to_api_dict(self):
        return {
            'id':        self.id,
            'type':      self.txn_type,
            'method':    self.method or None,
            'amount':    float(self.amount),
            'note':      self.note,
            'createdAt': self.created.isoformat(),
        }
