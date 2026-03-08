from django.db import models
from customers.models import Customer
from inventory.models import Item


class Sale(models.Model):
    customer     = models.ForeignKey(Customer, null=True, blank=True,
                                     related_name='sales', on_delete=models.SET_NULL)
    total_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    payment_cash = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    payment_pos  = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    payment_transfer = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    payment_wallet   = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    is_wholesale = models.BooleanField(default=False)
    created      = models.DateTimeField(auto_now_add=True)

    def to_api_dict(self):
        return {
            'id':          self.id,
            'customerId':  self.customer_id,
            'totalAmount': float(self.total_amount),
            'isWholesale': self.is_wholesale,
            'createdAt':   self.created.isoformat(),
            'items': [si.to_api_dict() for si in self.items.all()],
        }


class SaleItem(models.Model):
    sale     = models.ForeignKey(Sale, related_name='items', on_delete=models.CASCADE)
    item     = models.ForeignKey(Item, null=True, on_delete=models.SET_NULL)
    quantity = models.IntegerField(default=1)
    price    = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    barcode  = models.CharField(max_length=100, blank=True, default='')

    def to_api_dict(self):
        return {
            'itemId':   self.item_id,
            'name':     self.item.name if self.item else self.barcode,
            'quantity': self.quantity,
            'price':    float(self.price),
        }
