from django.db import models
from django.utils import timezone


# ── Prescriber ────────────────────────────────────────────────────────────────

class Prescriber(models.Model):
    """
    Registered doctor/prescriber. Belongs to one org but optionally shared
    across network pharmacies (is_network_shared=True).
    """
    organization      = models.ForeignKey(
        'authapp.Organization', on_delete=models.CASCADE,
        related_name='prescribers',
    )
    name              = models.CharField(max_length=200)
    license_number    = models.CharField(max_length=100, blank=True, default='')
    specialty         = models.CharField(max_length=100, blank=True, default='')
    phone             = models.CharField(max_length=20, blank=True, default='')
    clinic            = models.CharField(max_length=200, blank=True, default='')
    address           = models.TextField(blank=True, default='')
    is_verified       = models.BooleanField(default=False)
    is_network_shared = models.BooleanField(default=False)
    created_at        = models.DateTimeField(auto_now_add=True)
    updated_at        = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        indexes  = [
            models.Index(fields=['organization', 'name']),
            models.Index(fields=['license_number']),
        ]

    def to_api_dict(self):
        return {
            'id':               self.id,
            'name':             self.name,
            'license_number':   self.license_number or None,
            'specialty':        self.specialty or None,
            'phone':            self.phone or None,
            'clinic':           self.clinic or None,
            'address':          self.address or None,
            'is_verified':      self.is_verified,
            'is_network_shared': self.is_network_shared,
            'created_at':       self.created_at.isoformat(),
        }

    def __str__(self):
        suffix = f' ({self.license_number})' if self.license_number else ''
        return f'{self.name}{suffix}'


# ── Prescription ──────────────────────────────────────────────────────────────

class Prescription(models.Model):
    STATUS_CHOICES = [
        ('pending',   'Pending'),
        ('partial',   'Partial'),
        ('dispensed', 'Dispensed'),
    ]

    organization   = models.ForeignKey(
        'authapp.Organization', on_delete=models.CASCADE,
        related_name='prescriptions',
    )
    branch         = models.ForeignKey(
        'branches.Branch', null=True, blank=True,
        on_delete=models.SET_NULL, related_name='prescriptions',
    )
    # Nullable FK — walk-ins have no Customer record
    customer       = models.ForeignKey(
        'customers.Customer', null=True, blank=True,
        on_delete=models.SET_NULL, related_name='prescriptions',
    )
    customer_name  = models.CharField(max_length=200, default='Walk-in')
    customer_phone = models.CharField(max_length=20, blank=True, default='')
    # Structured prescriber (optional — falls back to free-text doctor_name)
    prescriber     = models.ForeignKey(
        Prescriber, null=True, blank=True,
        on_delete=models.SET_NULL, related_name='prescriptions',
    )
    doctor_name    = models.CharField(max_length=200, blank=True, default='')
    diagnosis      = models.TextField(blank=True, default='')
    notes          = models.TextField(blank=True, default='')
    status         = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_by     = models.ForeignKey(
        'authapp.PharmUser', null=True, blank=True,
        on_delete=models.SET_NULL, related_name='prescriptions_written',
    )
    created_at     = models.DateTimeField(auto_now_add=True)
    dispensed_at   = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes  = [
            models.Index(fields=['organization', 'status']),
            models.Index(fields=['organization', 'created_at']),
            models.Index(fields=['customer_phone']),
        ]

    def recompute_status(self):
        """Recalculate pending/partial/dispensed from child items. Call before save()."""
        items = list(self.medications.all())
        if not items:
            return
        dispensed_count = sum(1 for i in items if i.is_dispensed)
        if dispensed_count == 0:
            self.status = 'pending'
            self.dispensed_at = None
        elif dispensed_count == len(items):
            self.status = 'dispensed'
            if not self.dispensed_at:
                self.dispensed_at = timezone.now()
        else:
            self.status = 'partial'

    def to_api_dict(self):
        return {
            'id':                  self.id,
            'customer_id':         self.customer_id,
            'customer_name':       self.customer_name,
            'customer_phone':      self.customer_phone,
            'prescriber_id':       self.prescriber_id,
            'prescriber_license_no': (
                self.prescriber.license_number if self.prescriber_id else None
            ),
            'doctor_name':         self.doctor_name   or None,
            'diagnosis':           self.diagnosis     or None,
            'notes':               self.notes         or None,
            'status':              self.status,
            'created_at':          self.created_at.isoformat(),
            'dispensed_at':        self.dispensed_at.isoformat() if self.dispensed_at else None,
            'created_by_name':     (
                self.created_by.get_full_name() if self.created_by_id else None
            ),
            'created_by_id':       self.created_by_id,
            'pharmacy_name':       self.organization.name if self.organization_id else None,
            'pharmacy_id':         self.organization_id,
            'branch_name':         self.branch.name if self.branch_id else None,
            'branch_id':           self.branch_id,
            'medications':         [m.to_api_dict() for m in self.medications.all()],
        }

    def __str__(self):
        return f"Rx#{self.id} — {self.customer_name} ({self.status})"


class PrescriptionItem(models.Model):
    prescription  = models.ForeignKey(
        Prescription, on_delete=models.CASCADE, related_name='medications',
    )
    # Optional link to an inventory item
    item          = models.ForeignKey(
        'inventory.Item', null=True, blank=True,
        on_delete=models.SET_NULL, related_name='prescription_items',
    )
    item_name     = models.CharField(max_length=200)
    brand         = models.CharField(max_length=200, blank=True, default='')
    quantity      = models.DecimalField(max_digits=10, decimal_places=2, default=1)
    unit          = models.CharField(max_length=50, default='unit(s)')
    dosage        = models.CharField(max_length=200, blank=True, default='')
    duration      = models.CharField(max_length=100, blank=True, default='')
    instructions  = models.TextField(blank=True, default='')
    is_dispensed  = models.BooleanField(default=False)
    dispensed_at  = models.DateTimeField(null=True, blank=True)
    dispensed_by  = models.ForeignKey(
        'authapp.PharmUser', null=True, blank=True,
        on_delete=models.SET_NULL, related_name='dispensed_rx_items',
    )

    def to_api_dict(self):
        return {
            'id':           self.id,
            'item_id':      self.item_id,
            'item_name':    self.item_name,
            'brand':        self.brand        or None,
            'quantity':     float(self.quantity),
            'unit':         self.unit,
            'dosage':       self.dosage       or None,
            'duration':     self.duration     or None,
            'instructions': self.instructions or None,
            'is_dispensed': self.is_dispensed,
            'dispensed_at': self.dispensed_at.isoformat() if self.dispensed_at else None,
        }

    def __str__(self):
        return f"{self.item_name} × {self.quantity} (Rx#{self.prescription_id})"
