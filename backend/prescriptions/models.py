from django.db import models
from django.utils import timezone


# ── Hospital ──────────────────────────────────────────────────────────────────

class Hospital(models.Model):
    """
    A clinic or hospital where prescribers (doctors) are based.
    Global entity — not tied to any pharmacy organization or subscription.
    """
    name       = models.CharField(max_length=200)
    address    = models.TextField(blank=True, default='')
    phone      = models.CharField(max_length=30, blank=True, default='')
    city       = models.CharField(max_length=100, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def to_api_dict(self):
        return {
            'id':      self.id,
            'name':    self.name,
            'address': self.address or None,
            'phone':   self.phone or None,
            'city':    self.city or None,
        }

    def __str__(self):
        return self.name


# ── Prescriber ────────────────────────────────────────────────────────────────

class Prescriber(models.Model):
    """
    Registered doctor/prescriber. Linked to a Hospital (optional).
    Global — visible to all authenticated pharmacies; no org/subscription needed.
    """
    organization      = models.ForeignKey(
        'authapp.Organization', null=True, blank=True,
        on_delete=models.CASCADE,
        related_name='prescribers',
    )
    hospital          = models.ForeignKey(
        Hospital, null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='prescribers',
    )
    name              = models.CharField(max_length=200)
    license_number    = models.CharField(max_length=100, blank=True, default='')
    specialty         = models.CharField(max_length=100, blank=True, default='')
    phone             = models.CharField(max_length=20, blank=True, default='')
    clinic            = models.CharField(max_length=200, blank=True, default='')
    address           = models.TextField(blank=True, default='')
    password          = models.CharField(max_length=128, blank=True, default='')
    is_verified       = models.BooleanField(default=False)
    is_network_shared = models.BooleanField(default=False)
    commission_rate   = models.DecimalField(
        max_digits=5, decimal_places=2, default=0,
        help_text='Commission percentage (0–100) earned on dispensed prescription sales',
    )
    # Consultation fee bands — prescriber-editable default amount per category A–E.
    # A pharmacy may override the snapshot fee on an individual prescription.
    consult_fee_a     = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    consult_fee_b     = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    consult_fee_c     = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    consult_fee_d     = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    consult_fee_e     = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    created_at        = models.DateTimeField(auto_now_add=True)
    updated_at        = models.DateTimeField(auto_now=True)

    # Category letters supported for consultation-fee bands.
    CONSULT_CATEGORIES = ['A', 'B', 'C', 'D', 'E']

    def consultation_fees_dict(self):
        """Return {'A': fee, ...} as floats for the API."""
        return {
            'A': float(self.consult_fee_a),
            'B': float(self.consult_fee_b),
            'C': float(self.consult_fee_c),
            'D': float(self.consult_fee_d),
            'E': float(self.consult_fee_e),
        }

    def fee_for_category(self, category):
        """Return the Decimal fee for a category letter, or 0 if unknown."""
        field = {
            'A': self.consult_fee_a, 'B': self.consult_fee_b,
            'C': self.consult_fee_c, 'D': self.consult_fee_d,
            'E': self.consult_fee_e,
        }.get((category or '').strip().upper())
        return field if field is not None else 0

    class Meta:
        ordering = ['name']
        indexes  = [
            models.Index(fields=['name']),
            models.Index(fields=['license_number']),
        ]

    def to_api_dict(self):
        hospital_name = (
            self.hospital.name if self.hospital_id else self.clinic or None
        )
        return {
            'id':              self.id,
            'name':            self.name,
            'license_number':  self.license_number or None,
            'specialty':       self.specialty or None,
            'phone':           self.phone or None,
            'hospital_id':     self.hospital_id,
            'hospital_name':   hospital_name,
            'address':         self.address or None,
            'is_verified':     self.is_verified,
            'commission_rate': float(self.commission_rate),
            'consultation_fees': self.consultation_fees_dict(),
            'created_at':      self.created_at.isoformat(),
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
        'authapp.Organization', null=True, blank=True,
        on_delete=models.CASCADE, related_name='prescriptions',
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
    # Consultation fee band selected by the prescriber (A–E) plus the snapshot
    # amount at write-time. The fee is added as a silent surcharge at POS and is
    # never itemised on the customer receipt.
    consultation_category = models.CharField(max_length=1, blank=True, default='')
    consultation_fee      = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status         = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    source         = models.CharField(max_length=30, blank=True, default='pharmacy')  # 'pharmacy' | 'portal'
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
            'consultation_category': self.consultation_category or None,
            'consultation_fee':      float(self.consultation_fee),
            'status':              self.status,
            'source':              self.source or 'pharmacy',
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


# ── Prescriber Commission ─────────────────────────────────────────────────────

class PrescriberCommission(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('paid',    'Paid'),
    ]

    prescriber        = models.ForeignKey(
        Prescriber, on_delete=models.CASCADE, related_name='commissions',
    )
    prescription      = models.ForeignKey(
        Prescription, on_delete=models.CASCADE, related_name='commissions',
    )
    # Snapshot fields — preserve values even if items/prices change later
    patient_name      = models.CharField(max_length=200, default='Unknown')
    sales_amount      = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    commission_rate   = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    commission_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status            = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    paid_at           = models.DateTimeField(null=True, blank=True)
    created_at        = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes  = [
            models.Index(fields=['prescriber', 'status']),
            models.Index(fields=['prescription']),
        ]

    def to_api_dict(self):
        return {
            'id':                self.id,
            'prescriber_id':     self.prescriber_id,
            'prescriber_name':   self.prescriber.name,
            'prescription_id':   self.prescription_id,
            'patient_name':      self.patient_name,
            'sales_amount':      float(self.sales_amount),
            'commission_rate':   float(self.commission_rate),
            'commission_amount': float(self.commission_amount),
            'status':            self.status,
            'paid_at':           self.paid_at.isoformat() if self.paid_at else None,
            'created_at':        self.created_at.isoformat(),
        }

    def __str__(self):
        return (
            f"Commission #{self.id} — {self.prescriber.name} "
            f"({self.commission_rate}%) on Rx#{self.prescription_id}"
        )


# ── Consultation Payout ───────────────────────────────────────────────────────

class ConsultationPayout(models.Model):
    """
    A consultation fee charged silently at POS but owed to the prescriber.
    One record per dispensed prescription that carried a consultation surcharge.
    The org-admin settles it (single / Pay All) and the prescriber is notified
    of the running total paid out.
    """
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('paid',    'Paid'),
    ]

    prescriber   = models.ForeignKey(
        Prescriber, on_delete=models.CASCADE, related_name='consultation_payouts',
    )
    # OneToOne — a prescription's flat consultation fee is owed exactly once,
    # regardless of partial dispensing.
    prescription = models.OneToOneField(
        Prescription, on_delete=models.CASCADE, related_name='consultation_payout',
    )
    # Snapshot fields — preserve values even if the prescription changes later
    patient_name          = models.CharField(max_length=200, default='Unknown')
    consultation_category = models.CharField(max_length=1, blank=True, default='')
    consultation_fee      = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status                = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    paid_at               = models.DateTimeField(null=True, blank=True)
    created_at            = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes  = [
            models.Index(fields=['prescriber', 'status']),
        ]

    def to_api_dict(self):
        return {
            'id':                    self.id,
            'prescriber_id':         self.prescriber_id,
            'prescriber_name':       self.prescriber.name,
            'prescription_id':       self.prescription_id,
            'patient_name':          self.patient_name,
            'consultation_category': self.consultation_category or None,
            'consultation_fee':      float(self.consultation_fee),
            'status':                self.status,
            'paid_at':               self.paid_at.isoformat() if self.paid_at else None,
            'created_at':            self.created_at.isoformat(),
        }

    def __str__(self):
        return (
            f"Consultation payout #{self.id} — {self.prescriber.name} "
            f"(NGN {self.consultation_fee}) on Rx#{self.prescription_id}"
        )
