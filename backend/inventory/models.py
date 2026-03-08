from django.db import models


class Item(models.Model):
    name                = models.CharField(max_length=200)
    brand               = models.CharField(max_length=200, blank=True, default='')
    dosage_form         = models.CharField(max_length=100, blank=True, default='')
    price               = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    stock               = models.IntegerField(default=0)
    low_stock_threshold = models.IntegerField(default=10)
    barcode             = models.CharField(max_length=100, blank=True, default='')
    expiry_date         = models.DateField(null=True, blank=True)

    def to_api_dict(self):
        return {
            'id':                self.id,
            'name':              self.name,
            'brand':             self.brand,
            'dosageForm':        self.dosage_form,
            'price':             float(self.price),
            'stock':             self.stock,
            'lowStockThreshold': self.low_stock_threshold,
            'barcode':           self.barcode,
            'expiryDate':        self.expiry_date.isoformat() if self.expiry_date else None,
        }

    def __str__(self):
        return self.name
