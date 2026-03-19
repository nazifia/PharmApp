import uuid
from django.db import models
from django.utils import timezone

DOSAGE_FORM_CHOICES = [
    ("Tablet", "Tablet"),
    ("Capsule", "Capsule"),
    ("Cream", "Cream"),
    ("Consumable", "Consumable"),
    ("Galenical", "Galenical"),
    ("Injection", "Injection"),
    ("Infusion", "Infusion"),
    ("Inhaler", "Inhaler"),
    ("Suspension", "Suspension"),
    ("Syrup", "Syrup"),
    ("Drops", "Drops"),
    ("Solution", "Solution"),
    ("Eye-drop", "Eye-drop"),
    ("Ear-drop", "Ear-drop"),
    ("Eye-ointment", "Eye-ointment"),
    ("Rectal", "Rectal"),
    ("Vaginal", "Vaginal"),
    ("Detergent", "Detergent"),
    ("Drinks", "Drinks"),
    ("Paste", "Paste"),
    ("Patch", "Patch"),
    ("Table-water", "Table-water"),
    ("Food-item", "Food-item"),
    ("Sweets", "Sweets"),
    ("Soaps", "Soaps"),
    ("Biscuits", "Biscuits"),
]

UNIT_CHOICES = [
    ("Amp", "Amp"),
    ("Bottle", "Bottle"),
    ("Tab", "Tab"),
    ("Drops", "Drops"),
    ("Tin", "Tin"),
    ("Can", "Can"),
    ("Caps", "Caps"),
    ("Card", "Card"),
    ("Carton", "Carton"),
    ("Pack", "Pack"),
    ("Sachets", "Sachets"),
    ("Pcs", "Pcs"),
    ("Roll", "Roll"),
    ("Vail", "Vail"),
    ("1L", "1L"),
    ("2L", "2L"),
    ("4L", "4L"),
]

BARCODE_TYPE_CHOICES = [
    ("UPC", "UPC"),
    ("EAN13", "EAN-13"),
    ("CODE128", "Code 128"),
    ("QR", "QR Code"),
    ("OTHER", "Other"),
]

STATUS_ACTIVE = "active"
STATUS_INACTIVE = "inactive"


class Item(models.Model):
    name = models.CharField(max_length=200)
    brand = models.CharField(max_length=200, blank=True, default="")
    dosage_form = models.CharField(
        max_length=50, choices=DOSAGE_FORM_CHOICES, blank=True, default=""
    )
    unit = models.CharField(
        max_length=20, choices=UNIT_CHOICES, blank=True, default="Pcs"
    )
    cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    price = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    markup = models.DecimalField(
        max_digits=5, decimal_places=2, default=0, help_text="Markup percentage 0-100"
    )
    stock = models.IntegerField(default=0)
    low_stock_threshold = models.IntegerField(default=10)
    barcode = models.CharField(max_length=100, blank=True, default="", db_index=True)
    barcode_type = models.CharField(
        max_length=20, choices=BARCODE_TYPE_CHOICES, blank=True, default=""
    )
    gtin = models.CharField(max_length=50, blank=True, default="")
    batch_number = models.CharField(max_length=50, blank=True, default="")
    serial_number = models.CharField(max_length=50, blank=True, default="")
    expiry_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=20, default=STATUS_ACTIVE)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]

    def save(self, *args, **kwargs):
        if self.markup and not self.pk:
            from decimal import Decimal

            self.price = self.cost + (self.cost * self.markup / Decimal("100"))
        super().save(*args, **kwargs)

    def to_api_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "brand": self.brand,
            "dosageForm": self.dosage_form,
            "unit": self.unit,
            "cost": float(self.cost),
            "price": float(self.price),
            "markup": float(self.markup),
            "stock": self.stock,
            "lowStockThreshold": self.low_stock_threshold,
            "barcode": self.barcode,
            "barcodeType": self.barcode_type,
            "gtin": self.gtin,
            "batchNumber": self.batch_number,
            "serialNumber": self.serial_number,
            "expiryDate": self.expiry_date.isoformat() if self.expiry_date else None,
            "status": self.status,
        }

    def __str__(self):
        return f"{self.name} ({self.brand})" if self.brand else self.name
