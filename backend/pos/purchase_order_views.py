"""Purchase orders: draft -> submitted -> partial/received (or cancelled).

Receiving a line adds the received quantity to the linked inventory Item's stock.
"""
from datetime import date
from decimal import Decimal, InvalidOperation

from django.db import transaction
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from authapp.utils import require_org, log_activity
from inventory.models import Item
from .models import PurchaseOrder, PurchaseOrderItem, Supplier


def _bad(detail):
    return Response({"detail": detail}, status=status.HTTP_400_BAD_REQUEST)


def _qs(org):
    return (
        PurchaseOrder.objects.filter(organization=org)
        .select_related("supplier")
        .prefetch_related("items")
    )


def _parse_lines(org, raw):
    """Validate item lines from the request. Returns (list_of_kwargs, error_message)."""
    if not isinstance(raw, list) or not raw:
        return None, "Add at least one item."
    lines = []
    for r in raw:
        if not isinstance(r, dict):
            return None, "Invalid item line."
        try:
            qty = int(r.get("quantity_ordered") or 0)
            cost = Decimal(str(r.get("unit_cost") or 0))
        except (TypeError, ValueError, InvalidOperation):
            return None, "Invalid quantity or unit cost."
        if qty <= 0 or cost < 0:
            return None, "Quantity must be above 0 and unit cost cannot be negative."
        item = None
        if r.get("item_id"):
            item = Item.objects.filter(pk=r["item_id"], organization=org).first()
            if item is None:
                return None, f"Item {r['item_id']} not found."
        name = str(r.get("item_name") or (item.name if item else "")).strip()[:200]
        if not name:
            return None, "Each line needs an item."
        lines.append(dict(item=item, item_name=name, quantity_ordered=qty, unit_cost=cost))
    return lines, None


def _apply_header(po, data):
    """Copy expected_delivery/notes from the request onto po. Returns an error message or None."""
    if "expected_delivery" in data:
        val = data.get("expected_delivery")
        try:
            po.expected_delivery = date.fromisoformat(str(val)[:10]) if val else None
        except ValueError:
            return "Invalid expected_delivery date."
    if "notes" in data:
        po.notes = str(data.get("notes") or "")
    return None


def _create_lines(po, lines):
    PurchaseOrderItem.objects.bulk_create(
        PurchaseOrderItem(purchase_order=po, **line) for line in lines
    )


@api_view(["GET", "POST"])
def purchase_order_list(request):
    org, err = require_org(request)
    if err:
        return err

    if request.method == "GET":
        qs = _qs(org)
        supplier_id = request.query_params.get("supplier_id", "")
        if supplier_id.isdigit():
            qs = qs.filter(supplier_id=supplier_id)
        if request.query_params.get("status"):
            qs = qs.filter(status=request.query_params["status"])
        # ponytail: capped at 200, no pagination; add it when an org outgrows that
        return Response([po.to_api_dict() for po in qs[:200]])

    data = request.data
    supplier = Supplier.objects.filter(pk=data.get("supplier_id"), organization=org).first()
    if supplier is None:
        return _bad("Select a valid supplier.")
    lines, msg = _parse_lines(org, data.get("items"))
    if msg:
        return _bad(msg)
    po = PurchaseOrder(organization=org, supplier=supplier, created_by=request.user)
    msg = _apply_header(po, data)
    if msg:
        return _bad(msg)
    with transaction.atomic():
        po.save()
        _create_lines(po, lines)
    log_activity(request, action="Create Purchase Order", category="inventory",
                 description=f"PO#{po.pk} for {supplier.name}")
    return Response(_qs(org).get(pk=po.pk).to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(["GET", "PATCH", "DELETE"])
def purchase_order_detail(request, pk):
    org, err = require_org(request)
    if err:
        return err
    po = get_object_or_404(_qs(org), pk=pk)

    if request.method == "GET":
        return Response(po.to_api_dict())

    if request.method == "DELETE":
        if po.status != "draft":
            return _bad("Only draft orders can be deleted.")
        po.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    data = request.data
    # Cancelling is allowed until goods have arrived.
    if data.get("status") == "cancelled":
        if po.status not in ("draft", "submitted"):
            return _bad("Orders that have received stock cannot be cancelled.")
        po.status = "cancelled"
        po.save(update_fields=["status", "updated_at"])
        return Response(po.to_api_dict())

    if po.status != "draft":
        return _bad("Only draft orders can be edited.")
    msg = _apply_header(po, data)
    if msg:
        return _bad(msg)
    if "supplier_id" in data:
        supplier = Supplier.objects.filter(pk=data["supplier_id"], organization=org).first()
        if supplier is None:
            return _bad("Select a valid supplier.")
        po.supplier = supplier
    lines = None
    if "items" in data:
        lines, msg = _parse_lines(org, data["items"])
        if msg:
            return _bad(msg)
    with transaction.atomic():
        po.save()
        if lines is not None:
            po.items.all().delete()
            _create_lines(po, lines)
    return Response(_qs(org).get(pk=po.pk).to_api_dict())


@api_view(["POST"])
def purchase_order_submit(request, pk):
    org, err = require_org(request)
    if err:
        return err
    po = get_object_or_404(_qs(org), pk=pk)
    if po.status != "draft":
        return _bad("Only draft orders can be submitted.")
    po.status = "submitted"
    po.save(update_fields=["status", "updated_at"])
    return Response(po.to_api_dict())


@api_view(["POST"])
def purchase_order_receive(request, pk):
    """Body: {items: [{id | item_id, quantity_received}]} — quantities in THIS delivery.

    Each line is capped at what is still outstanding, so a re-sent request can
    never push stock beyond the ordered amount.
    """
    org, err = require_org(request)
    if err:
        return err
    raw = request.data.get("items")
    if not isinstance(raw, list) or not raw:
        return _bad("No received items supplied.")

    with transaction.atomic():
        po = get_object_or_404(
            PurchaseOrder.objects.select_for_update().filter(organization=org), pk=pk
        )
        if po.status not in ("submitted", "partial"):
            return _bad("Only submitted orders can be received.")
        lines = {line.id: line for line in po.items.select_for_update()}
        by_item = {line.item_id: line for line in lines.values() if line.item_id}
        received_any = False
        for r in raw:
            if not isinstance(r, dict):
                return _bad("Invalid received line.")
            line = lines.get(r.get("id")) or by_item.get(r.get("item_id"))
            if line is None:
                return _bad("Received line does not belong to this order.")
            try:
                qty = int(r.get("quantity_received") or 0)
            except (TypeError, ValueError):
                return _bad("Invalid received quantity.")
            if qty < 0:
                return _bad("Received quantity cannot be negative.")
            qty = min(qty, line.quantity_ordered - line.quantity_received)
            if qty == 0:
                continue
            received_any = True
            line.quantity_received += qty
            line.save(update_fields=["quantity_received"])
            if line.item_id:
                item = Item.objects.select_for_update().get(pk=line.item_id)
                item.stock += qty
                if line.unit_cost:
                    item.cost = line.unit_cost
                item.save()
        if not received_any:
            return _bad("Nothing to receive: quantities are zero or already received.")
        done = all(line.quantity_received >= line.quantity_ordered for line in lines.values())
        po.status = "received" if done else "partial"
        po.save(update_fields=["status", "updated_at"])

    log_activity(request, action="Receive Purchase Order", category="inventory",
                 description=f"PO#{po.pk} now {po.status}")
    return Response(_qs(org).get(pk=po.pk).to_api_dict())
