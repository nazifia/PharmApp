from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from inventory.models import Item
from customers.models import Customer, WalletTransaction
from .models import Sale, SaleItem


@api_view(['POST'])
def checkout(request):
    """
    Expected payload (camelCase from Flutter):
    {
      "customerId": 1,          // optional
      "isWholesale": false,
      "items": [
        {"barcode": "...", "itemId": 1, "quantity": 2, "price": 50.0}
      ],
      "payment": {
        "cash": 100,
        "pos": 0,
        "bankTransfer": 0,
        "wallet": 0
      }
    }
    """
    data        = request.data
    customer_id = data.get('customerId')
    is_wholesale = data.get('isWholesale', False)
    items_data  = data.get('items', [])
    payment     = data.get('payment', {})

    customer = None
    if customer_id:
        try:
            customer = Customer.objects.get(pk=customer_id)
        except Customer.DoesNotExist:
            pass

    # Calculate total
    total = sum(float(i.get('price', 0)) * int(i.get('quantity', 1)) for i in items_data)

    # Create sale
    sale = Sale.objects.create(
        customer=customer,
        total_amount=total,
        payment_cash=float(payment.get('cash', 0)),
        payment_pos=float(payment.get('pos', 0)),
        payment_transfer=float(payment.get('bankTransfer', 0)),
        payment_wallet=float(payment.get('wallet', 0)),
        is_wholesale=is_wholesale,
    )

    # Create sale items and deduct stock
    for i_data in items_data:
        item = None
        item_id = i_data.get('itemId')
        barcode  = i_data.get('barcode', '')
        qty      = int(i_data.get('quantity', 1))
        price    = float(i_data.get('price', 0))

        if item_id:
            try:
                item = Item.objects.get(pk=item_id)
            except Item.DoesNotExist:
                pass
        elif barcode:
            item = Item.objects.filter(barcode=barcode).first()

        if item:
            item.stock = max(0, item.stock - qty)
            item.save()

        SaleItem.objects.create(
            sale=sale, item=item, quantity=qty, price=price,
            barcode=barcode,
        )

    # Handle wallet payment
    wallet_used = float(payment.get('wallet', 0))
    if customer and wallet_used > 0:
        customer.wallet_balance = float(customer.wallet_balance) - wallet_used
        customer.last_visit = timezone.now().date()
        customer.save()
        WalletTransaction.objects.create(
            customer=customer, txn_type='purchase',
            amount=wallet_used, note=f'Sale #{sale.id}')

    return Response(sale.to_api_dict(), status=status.HTTP_201_CREATED)
