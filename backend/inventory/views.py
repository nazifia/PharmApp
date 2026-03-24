from django.shortcuts import get_object_or_404
from django.utils.dateparse import parse_date
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import Item
from authapp.utils import require_org


@api_view(["GET", "POST"])
def item_list(request):
    org, err = require_org(request)
    if err:
        return err

    if request.method == "GET":
        search = request.query_params.get("search", "").strip()
        store = request.query_params.get("store", "").strip()
        items = Item.objects.filter(organization=org).order_by("name")
        if search:
            items = items.filter(name__icontains=search)
        if store in ("retail", "wholesale"):
            items = items.filter(store=store)
        return Response([i.to_api_dict() for i in items])

    # POST — create
    data = request.data
    name = (data.get("name") or "").strip()
    if not name:
        return Response({"detail": "Name is required"}, status=status.HTTP_400_BAD_REQUEST)
    try:
        price = float(data.get("price", 0))
        cost = float(data.get("costPrice", 0))
        stock = int(data.get("stock", 0))
        low_stock_threshold = int(data.get("lowStockThreshold", 10))
    except (ValueError, TypeError):
        return Response({"detail": "Invalid numeric value"}, status=status.HTTP_400_BAD_REQUEST)
    if price < 0 or cost < 0 or stock < 0 or low_stock_threshold < 0:
        return Response({"detail": "Price, cost, and stock must be non-negative"}, status=status.HTTP_400_BAD_REQUEST)
    item = Item.objects.create(
        organization=org,
        name=name,
        brand=data.get("brand", ""),
        dosage_form=data.get("dosageForm", ""),
        price=price,
        cost=cost,
        stock=stock,
        low_stock_threshold=low_stock_threshold,
        barcode=data.get("barcode", ""),
        expiry_date=data.get("expiryDate") or None,
        store=data.get("store", "retail"),
    )
    return Response(item.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(["GET", "PUT", "PATCH", "DELETE"])
def item_detail(request, pk):
    org, err = require_org(request)
    if err:
        return err
    item = get_object_or_404(Item, pk=pk, organization=org)

    if request.method == "GET":
        return Response(item.to_api_dict())

    if request.method in ("PUT", "PATCH"):
        data = request.data
        name = (data.get("name") or item.name or "").strip()
        if not name:
            return Response({"detail": "Name is required"}, status=status.HTTP_400_BAD_REQUEST)
        try:
            price = float(data.get("price", item.price))
            cost = float(data.get("costPrice", item.cost))
            stock = int(data.get("stock", item.stock))
            low_stock_threshold = int(data.get("lowStockThreshold", item.low_stock_threshold))
        except (ValueError, TypeError):
            return Response({"detail": "Invalid numeric value"}, status=status.HTTP_400_BAD_REQUEST)
        if price < 0 or cost < 0 or stock < 0 or low_stock_threshold < 0:
            return Response({"detail": "Price, cost, and stock must be non-negative"}, status=status.HTTP_400_BAD_REQUEST)
        item.name = name
        item.brand = data.get("brand", item.brand)
        item.dosage_form = data.get("dosageForm", item.dosage_form)
        item.price = price
        item.cost = cost
        item.stock = stock
        item.low_stock_threshold = low_stock_threshold
        item.barcode = data.get("barcode", item.barcode)
        expiry_raw = data.get("expiryDate", item.expiry_date) or None
        item.expiry_date = parse_date(expiry_raw) if isinstance(expiry_raw, str) else expiry_raw
        item.save()
        return Response(item.to_api_dict())

    # DELETE
    item.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
def adjust_stock(request, pk):
    org, err = require_org(request)
    if err:
        return err
    item = get_object_or_404(Item, pk=pk, organization=org)
    try:
        adjustment = int(request.data.get("adjustment", 0))
    except (ValueError, TypeError):
        return Response({"detail": "Invalid adjustment value"}, status=status.HTTP_400_BAD_REQUEST)
    item.stock = max(0, item.stock + adjustment)
    item.save()
    return Response(item.to_api_dict())
