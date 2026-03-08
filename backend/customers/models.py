from django.db import models
from django.utils import timezone


class Customer(models.Model):
    name             = models.CharField(max_length=200)
    phone            = models.CharField(max_length=20, unique=True)
    is_wholesale     = models.BooleanField(default=False)
    wallet_balance   = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    outstanding_debt = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    email            = models.EmailField(blank=True, default='')
    address          = models.TextField(blank=True, default='')
    join_date        = models.DateField(default=timezone.now)
    last_visit       = models.DateField(null=True, blank=True)

    def total_purchases(self):
        return float(self.sales.aggregate(
            total=models.Sum('total_amount'))['total'] or 0)

    def total_spent(self):
        return self.total_purchases()

    def to_list_dict(self):
        return {
            'id':               self.id,
            'name':             self.name,
            'phone':            self.phone,
            'is_wholesale':     self.is_wholesale,
            'wallet_balance':   float(self.wallet_balance),
            'total_purchases':  self.total_purchases(),
            'outstanding_debt': float(self.outstanding_debt),
        }

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

    def __str__(self):
        return self.name


class WalletTransaction(models.Model):
    TYPES = [('topup', 'Top-up'), ('deduct', 'Deduction'), ('purchase', 'Purchase')]

    customer  = models.ForeignKey(Customer, related_name='wallet_transactions',
                                  on_delete=models.CASCADE)
    txn_type  = models.CharField(max_length=20, choices=TYPES)
    amount    = models.DecimalField(max_digits=12, decimal_places=2)
    note      = models.CharField(max_length=300, blank=True, default='')
    created   = models.DateTimeField(auto_now_add=True)

    def to_api_dict(self):
        return {
            'id':        self.id,
            'type':      self.txn_type,
            'amount':    float(self.amount),
            'note':      self.note,
            'createdAt': self.created.isoformat(),
        }
