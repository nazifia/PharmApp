from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import Item


@api_view(["GET", "POST"])
def item_list(request):
    if request.method == "GET":
        search = request.query_params.get("search", "").strip()
        items = Item.objects.all().order_by("name")
        if search:
            items = items.filter(name__icontains=search)
        return Response([i.to_api_dict() for i in items])

    # POST — create
    data = request.data
    item = Item.objects.create(
        name=data.get("name", ""),
        brand=data.get("brand", ""),
        dosage_form=data.get("dosageForm", ""),
        price=data.get("price", 0),
        cost_price=data.get("costPrice", 0),
        stock=data.get("stock", 0),
        low_stock_threshold=data.get("lowStockThreshold", 10),
        barcode=data.get("barcode", ""),
        expiry_date=data.get("expiryDate") or None,
    )
    return Response(item.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(["GET", "PUT", "PATCH", "DELETE"])
def item_detail(request, pk):
    item = get_object_or_404(Item, pk=pk)

    if request.method == "GET":
        return Response(item.to_api_dict())

    if request.method in ("PUT", "PATCH"):
        data = request.data
        item.name = data.get("name", item.name)
        item.brand = data.get("brand", item.brand)
        item.dosage_form = data.get("dosageForm", item.dosage_form)
        item.price = data.get("price", item.price)
        item.cost_price = data.get("costPrice", item.cost_price)
        item.stock = data.get("stock", item.stock)
        item.low_stock_threshold = data.get(
            "lowStockThreshold", item.low_stock_threshold
        )
        item.barcode = data.get("barcode", item.barcode)
        item.expiry_date = data.get("expiryDate", item.expiry_date) or None
        item.save()
        return Response(item.to_api_dict())

    # DELETE
    item.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
def adjust_stock(request, pk):
    item = get_object_or_404(Item, pk=pk)
    adjustment = int(request.data.get("adjustment", 0))
    item.stock = max(0, item.stock + adjustment)
    item.save()
    return Response(item.to_api_dict())
