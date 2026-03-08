from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import Customer, WalletTransaction


@api_view(['GET', 'POST'])
def customer_list(request):
    if request.method == 'GET':
        customers = Customer.objects.all().order_by('name')
        return Response([c.to_list_dict() for c in customers])

    data = request.data
    customer = Customer.objects.create(
        name=data.get('name', ''),
        phone=data.get('phone', ''),
        is_wholesale=data.get('is_wholesale', False),
        email=data.get('email', ''),
        address=data.get('address', ''),
    )
    return Response(customer.to_detail_dict(), status=status.HTTP_201_CREATED)


@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
def customer_detail(request, pk):
    customer = get_object_or_404(Customer, pk=pk)

    if request.method == 'GET':
        return Response(customer.to_detail_dict())

    if request.method in ('PUT', 'PATCH'):
        data = request.data
        customer.name         = data.get('name',         customer.name)
        customer.phone        = data.get('phone',        customer.phone)
        customer.is_wholesale = data.get('is_wholesale', customer.is_wholesale)
        customer.email        = data.get('email',        customer.email)
        customer.address      = data.get('address',      customer.address)
        customer.save()
        return Response(customer.to_detail_dict())

    customer.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(['GET'])
def wallet_transactions(request, pk):
    customer = get_object_or_404(Customer, pk=pk)
    txns = customer.wallet_transactions.order_by('-created')
    return Response([t.to_api_dict() for t in txns])


@api_view(['POST'])
def wallet_topup(request, pk):
    customer = get_object_or_404(Customer, pk=pk)
    amount = float(request.data.get('amount', 0))
    note   = request.data.get('note', '')
    customer.wallet_balance = float(customer.wallet_balance) + amount
    customer.save()
    txn = WalletTransaction.objects.create(
        customer=customer, txn_type='topup', amount=amount, note=note)
    return Response({'walletBalance': float(customer.wallet_balance),
                     'transaction': txn.to_api_dict()})


@api_view(['POST'])
def wallet_deduct(request, pk):
    customer = get_object_or_404(Customer, pk=pk)
    amount = float(request.data.get('amount', 0))
    note   = request.data.get('note', '')
    customer.wallet_balance = float(customer.wallet_balance) - amount
    customer.save()
    txn = WalletTransaction.objects.create(
        customer=customer, txn_type='deduct', amount=amount, note=note)
    return Response({'walletBalance': float(customer.wallet_balance),
                     'transaction': txn.to_api_dict()})


@api_view(['GET'])
def customer_sales(request, pk):
    customer = get_object_or_404(Customer, pk=pk)
    sales = customer.sales.order_by('-created')
    return Response([s.to_api_dict() for s in sales])
