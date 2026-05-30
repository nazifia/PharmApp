from django.shortcuts import get_object_or_404
from django.utils.dateparse import parse_date
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from .models import Item, STATUS_ACTIVE
from authapp.utils import require_org, log_activity
from authapp.permissions import IsInventoryEditor, LOW_STOCK_ALERT_ROLES, require_role


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated, IsInventoryEditor])
def item_list(request):
    org, err = require_org(request)
    if err:
        return err

    if request.method == "GET":
        search = request.query_params.get("search", "").strip()
        store = request.query_params.get("store", "").strip()
        low_stock = request.query_params.get("low_stock", "").strip().lower() == "true"
        expiry_soon = (
            request.query_params.get("expiry_soon", "").strip().lower() == "true"
        )
        branch_id_str = request.query_params.get("branch_id", "").strip()
        items = Item.objects.filter(organization=org).order_by("name")
        if branch_id_str and branch_id_str.isdigit() and int(branch_id_str) > 0:
            items = items.filter(branch_id=int(branch_id_str))
        if search:
            items = items.filter(name__icontains=search)
        if store in ("retail", "wholesale"):
            items = items.filter(store=store)
        if low_stock:
            from django.db.models import F

            items = items.filter(stock__lte=F("low_stock_threshold"))
        if expiry_soon:
            from django.utils import timezone

            today = timezone.now().date()
            soon = today + timezone.timedelta(days=90)
            items = items.filter(
                expiry_date__isnull=False, expiry_date__lte=soon, stock__gt=0
            )
        return Response([i.to_api_dict() for i in items])

    # POST — create
    data = request.data
    name = (data.get("name") or "").strip()
    if not name:
        return Response(
            {"detail": "Name is required"}, status=status.HTTP_400_BAD_REQUEST
        )
    try:
        price = float(data.get("price", 0))
        cost = float(data.get("costPrice", 0))
        stock = float(data.get("stock", 0))
        low_stock_threshold = int(data.get("lowStockThreshold", 10))
    except (ValueError, TypeError):
        return Response(
            {"detail": "Invalid numeric value"}, status=status.HTTP_400_BAD_REQUEST
        )
    if price < 0 or cost < 0 or stock < 0 or low_stock_threshold < 0:
        return Response(
            {"detail": "Price, cost, and stock must be non-negative"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if "lowStockThreshold" in data:
        err = require_role(request, LOW_STOCK_ALERT_ROLES,
                           "Only Admin or Manager can set the low stock alert threshold.")
        if err:
            return err
    branch_id = data.get("branch_id") or data.get("branchId")
    branch = None
    if branch_id:
        try:
            from branches.models import Branch
            branch = Branch.objects.get(pk=int(branch_id), organization=org)
        except (Branch.DoesNotExist, ValueError, TypeError):
            branch = None

    item = Item.objects.create(
        organization=org,
        branch=branch,
        name=name,
        brand=data.get("brand", ""),
        dosage_form=data.get("dosageForm", ""),
        unit=data.get("unitOfDispensing", "Pcs"),
        price=price,
        cost=cost,
        stock=stock,
        low_stock_threshold=low_stock_threshold,
        barcode=data.get("barcode", ""),
        expiry_date=data.get("expiryDate") or None,
        store=data.get("store", "retail"),
    )
    log_activity(request, action='Add Item', category='inventory',
                 description=f'Added "{item.name}" to {item.store} inventory')
    return Response(item.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(["GET", "PUT", "PATCH", "DELETE"])
@permission_classes([IsAuthenticated, IsInventoryEditor])
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
            return Response(
                {"detail": "Name is required"}, status=status.HTTP_400_BAD_REQUEST
            )
        try:
            price = float(data.get("price", item.price))
            cost = float(data.get("costPrice", item.cost))
            stock = float(data.get("stock", item.stock))
            low_stock_threshold = int(
                data.get("lowStockThreshold", item.low_stock_threshold)
            )
        except (ValueError, TypeError):
            return Response(
                {"detail": "Invalid numeric value"}, status=status.HTTP_400_BAD_REQUEST
            )
        if price < 0 or cost < 0 or stock < 0 or low_stock_threshold < 0:
            return Response(
                {"detail": "Price, cost, and stock must be non-negative"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if "lowStockThreshold" in data and low_stock_threshold != item.low_stock_threshold:
            err = require_role(request, LOW_STOCK_ALERT_ROLES,
                               "Only Admin or Manager can change the low stock alert threshold.")
            if err:
                return err

        # Capture what changed for the audit trail.
        changes = []
        old_price = float(item.price)
        old_cost  = float(item.cost)
        old_stock = float(item.stock)
        if price != old_price:
            changes.append(f'price ₦{old_price:,.2f}→₦{price:,.2f}')
        if cost != old_cost:
            changes.append(f'cost ₦{old_cost:,.2f}→₦{cost:,.2f}')
        if stock != old_stock:
            changes.append(f'stock {old_stock:g}→{stock:g}')
        if name != item.name:
            changes.append(f'name "{item.name}"→"{name}"')
        audit_desc = f'Updated "{name}": {"; ".join(changes)}' if changes else f'Updated "{name}" (no field changes)'

        item.name = name
        item.brand = data.get("brand", item.brand)
        item.dosage_form = data.get("dosageForm", item.dosage_form)
        item.unit = data.get("unitOfDispensing", item.unit)
        item.price = price
        item.cost = cost
        item.stock = stock
        item.low_stock_threshold = low_stock_threshold
        item.barcode = data.get("barcode", item.barcode)
        expiry_raw = data.get("expiryDate", item.expiry_date) or None
        item.expiry_date = (
            parse_date(expiry_raw) if isinstance(expiry_raw, str) else expiry_raw
        )
        item.save()
        log_activity(request, action='Update Item', category='inventory',
                     description=audit_desc)
        return Response(item.to_api_dict())

    # DELETE
    item_name = item.name
    item.delete()
    log_activity(request, action='Delete Item', category='inventory',
                 description=f'Deleted "{item_name}"')
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def medication_availability(request):
    """Cross-pharmacy stock lookup for a given medication name.

    GET /inventory/availability/?name=Amoxicillin&brand=Amoxil

    Returns one entry per pharmacy that carries the item with stock > 0,
    showing the highest-stocked matching item's quantity and price.
    Any authenticated user can call this (read-only, cross-org).
    """
    name = request.query_params.get("name", "").strip()
    brand = request.query_params.get("brand", "").strip()

    if not name:
        return Response(
            {"detail": "name query parameter is required"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    qs = (
        Item.objects
        .filter(name__icontains=name, stock__gt=0, status=STATUS_ACTIVE)
        .select_related("organization")
        .order_by("organization_id", "-stock")
    )
    if brand:
        qs = qs.filter(brand__icontains=brand)

    # One entry per pharmacy — pick the item with the highest stock.
    seen_orgs = set()
    results = []
    for item in qs:
        if item.organization_id is None or item.organization_id in seen_orgs:
            continue
        seen_orgs.add(item.organization_id)
        org = item.organization
        results.append({
            "pharmacy_name": org.name,
            "pharmacy_id": org.id,
            "stock_quantity": int(item.stock),
            "address": org.address or "",
            "phone": org.phone or "",
        })

    # Sort by most stock first so the most-stocked pharmacy appears at the top.
    results.sort(key=lambda x: -x["stock_quantity"])
    return Response(results)


@api_view(["POST"])
@permission_classes([IsAuthenticated, IsInventoryEditor])
def adjust_stock(request, pk):
    org, err = require_org(request)
    if err:
        return err
    item = get_object_or_404(Item, pk=pk, organization=org)
    try:
        from decimal import Decimal
        adjustment = Decimal(str(request.data.get("adjustment", 0)))
    except (ValueError, TypeError):
        return Response(
            {"detail": "Invalid adjustment value"}, status=status.HTTP_400_BAD_REQUEST
        )
    old_stock = float(item.stock)
    item.stock = max(0, item.stock + adjustment)
    item.save()
    sign = '+' if adjustment >= 0 else ''
    reason = request.data.get('reason', '')
    reason_part = f' — reason: {reason}' if reason else ''
    log_activity(request, action='Adjust Stock', category='inventory',
                 description=f'Stock for "{item.name}": {old_stock:g}→{float(item.stock):g} ({sign}{adjustment}){reason_part}')
    return Response(item.to_api_dict())
