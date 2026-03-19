from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import Customer, WalletTransaction


@api_view(["GET", "POST"])
def customer_list(request):
    if request.method == "GET":
        search = request.query_params.get("search", "").strip()
        customers = Customer.objects.all().order_by("name")
        if search:
            customers = customers.filter(name__icontains=search)
        return Response([c.to_list_dict() for c in customers])

    data = request.data
    name = data.get("name", "").strip()
    phone = data.get("phone", "").strip()
    if not name:
        return Response(
            {"detail": "Name is required"}, status=status.HTTP_400_BAD_REQUEST
        )
    if not phone:
        return Response(
            {"detail": "Phone is required"}, status=status.HTTP_400_BAD_REQUEST
        )
    if Customer.objects.filter(phone=phone).exists():
        return Response(
            {"detail": "A customer with this phone number already exists"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    customer = Customer.objects.create(
        name=name,
        phone=phone,
        is_wholesale=data.get("is_wholesale", False),
        email=data.get("email", ""),
        address=data.get("address", ""),
    )
    return Response(customer.to_detail_dict(), status=status.HTTP_201_CREATED)


@api_view(["GET", "PUT", "PATCH", "DELETE"])
def customer_detail(request, pk):
    customer = get_object_or_404(Customer, pk=pk)

    if request.method == "GET":
        return Response(customer.to_detail_dict())

    if request.method in ("PUT", "PATCH"):
        data = request.data
        customer.name = data.get("name", customer.name)
        customer.phone = data.get("phone", customer.phone)
        customer.is_wholesale = data.get("is_wholesale", customer.is_wholesale)
        customer.email = data.get("email", customer.email)
        customer.address = data.get("address", customer.address)
        customer.save()
        return Response(customer.to_detail_dict())

    customer.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["GET"])
def wallet_transactions(request, pk):
    customer = get_object_or_404(Customer, pk=pk)
    txns = customer.wallet_transactions.order_by("-created")
    return Response([t.to_api_dict() for t in txns])


@api_view(["POST"])
def wallet_topup(request, pk):
    customer = get_object_or_404(Customer, pk=pk)
    amount = float(request.data.get("amount", 0))
    note = request.data.get("note", "")

    if amount <= 0:
        return Response(
            {"detail": "Amount must be positive"}, status=status.HTTP_400_BAD_REQUEST
        )
    if amount > 10000000:
        return Response(
            {"detail": "Amount exceeds maximum limit"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    with transaction.atomic():
        customer.wallet_balance = float(customer.wallet_balance) + amount
        customer.save()
        txn = WalletTransaction.objects.create(
            customer=customer, txn_type="topup", amount=amount, note=note
        )
    return Response(
        {
            "walletBalance": float(customer.wallet_balance),
            "transaction": txn.to_api_dict(),
        }
    )


@api_view(["POST"])
def wallet_deduct(request, pk):
    customer = get_object_or_404(Customer, pk=pk)
    amount = float(request.data.get("amount", 0))
    note = request.data.get("note", "")

    if amount <= 0:
        return Response(
            {"detail": "Amount must be positive"}, status=status.HTTP_400_BAD_REQUEST
        )

    with transaction.atomic():
        # Re-read within transaction to avoid race condition
        customer = Customer.objects.select_for_update().get(pk=pk)
        if float(customer.wallet_balance) < amount:
            return Response(
                {
                    "detail": f"Insufficient balance: {float(customer.wallet_balance)} available"
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        customer.wallet_balance = float(customer.wallet_balance) - amount
        customer.save()
        txn = WalletTransaction.objects.create(
            customer=customer, txn_type="deduct", amount=amount, note=note
        )
    return Response(
        {
            "walletBalance": float(customer.wallet_balance),
            "transaction": txn.to_api_dict(),
        }
    )


@api_view(["GET"])
def customer_sales(request, pk):
    customer = get_object_or_404(Customer, pk=pk)
    sales = customer.sales.order_by("-created")
    return Response([s.to_api_dict() for s in sales])


@api_view(["POST"])
def wallet_reset(request, pk):
    customer = get_object_or_404(Customer, pk=pk)
    old_balance = float(customer.wallet_balance)
    with transaction.atomic():
        customer.wallet_balance = 0
        customer.save()
        if old_balance != 0:
            txn_type = "deduct" if old_balance > 0 else "topup"
            WalletTransaction.objects.create(
                customer=customer,
                txn_type=txn_type,
                amount=abs(old_balance),
                note="Wallet reset",
            )
    return Response({"walletBalance": 0.0})


@api_view(["POST"])
def record_payment(request, pk):
    customer = get_object_or_404(Customer, pk=pk)
    amount = float(request.data.get("amount", 0))
    method = request.data.get("method", "cash")
    if amount <= 0:
        return Response(
            {"detail": "Amount must be positive"}, status=status.HTTP_400_BAD_REQUEST
        )
    if float(customer.outstanding_debt) < amount:
        return Response(
            {"detail": f"Payment exceeds debt of {customer.outstanding_debt}"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    with transaction.atomic():
        customer.outstanding_debt = float(customer.outstanding_debt) - amount
        customer.save()
        WalletTransaction.objects.create(
            customer=customer,
            txn_type="deduct",
            amount=amount,
            note=f"Debt payment via {method}",
        )
    return Response({"outstandingDebt": float(customer.outstanding_debt)})
