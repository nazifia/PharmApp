from django.db import models as _m, transaction
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from authapp.utils import require_org, log_activity
from authapp.permissions import IsPrescriptionUser, PRESCRIPTIONS_WRITE
from .models import Prescription, PrescriptionItem


# ── Helpers ───────────────────────────────────────────────────────────────────

def _resolve_item(org, item_name: str, brand: str = '') -> int | None:
    """Return the inventory Item pk that best matches name+brand within org, or None."""
    from inventory.models import Item
    qs = Item.objects.filter(organization=org, name__iexact=item_name.strip())
    if brand:
        exact = qs.filter(brand__iexact=brand.strip())
        if exact.exists():
            return exact.first().pk
    return qs.first().pk if qs.exists() else None


# ── List / Create ─────────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated, IsPrescriptionUser])
def prescription_list(request):
    org, err = require_org(request)
    if err:
        return err

    if request.method == 'GET':
        qs = Prescription.objects.filter(organization=org).prefetch_related('medications')

        # Status filter — 'undispensed' is a convenience alias for pending+partial
        rx_status = request.query_params.get('status', '').strip()
        if rx_status == 'undispensed':
            qs = qs.filter(status__in=['pending', 'partial'])
        elif rx_status in ('pending', 'partial', 'dispensed'):
            qs = qs.filter(status=rx_status)

        # Branch filter
        branch_id = request.query_params.get('branch_id', '')
        if branch_id.isdigit() and int(branch_id) > 0:
            qs = qs.filter(branch_id=int(branch_id))

        # Customer filter
        customer_id = request.query_params.get('customer_id', '')
        if customer_id.isdigit():
            qs = qs.filter(customer_id=int(customer_id))

        # Text search — name or phone
        search = request.query_params.get('search', '').strip()
        if search:
            qs = qs.filter(
                _m.Q(customer_name__icontains=search) |
                _m.Q(customer_phone__icontains=search)
            )

        return Response([rx.to_api_dict() for rx in qs])

    # ── POST: create prescription ─────────────────────────────────────────────

    data = request.data
    customer_name  = (data.get('customer_name') or '').strip()
    customer_phone = (data.get('customer_phone') or '').strip()
    medications_data = data.get('medications') or []

    if not customer_name:
        return Response({'detail': 'customer_name is required'},
                        status=status.HTTP_400_BAD_REQUEST)
    if not medications_data:
        return Response({'detail': 'At least one medication is required'},
                        status=status.HTTP_400_BAD_REQUEST)

    # Resolve customer FK — must belong to this org
    customer_obj = None
    customer_id  = data.get('customer_id')
    if customer_id:
        try:
            from customers.models import Customer
            customer_obj = Customer.objects.get(pk=customer_id, organization=org)
        except Exception:
            pass  # walk-in or cross-pharmacy patient

    branch_id = data.get('branch_id')

    with transaction.atomic():
        rx = Prescription.objects.create(
            organization   = org,
            branch_id      = branch_id if branch_id else None,
            customer       = customer_obj,
            customer_name  = customer_name,
            customer_phone = customer_phone,
            doctor_name    = (data.get('doctor_name')  or '').strip(),
            diagnosis      = (data.get('diagnosis')    or '').strip(),
            notes          = (data.get('notes')        or '').strip(),
            created_by     = request.user,
            status         = 'pending',
        )
        for med in medications_data:
            item_name = (med.get('item_name') or med.get('name') or '').strip()
            if not item_name:
                continue
            brand    = (med.get('brand') or '').strip()
            # Use explicit item_id when provided; otherwise try to auto-link by name.
            item_id  = med.get('item_id') or _resolve_item(org, item_name, brand)
            PrescriptionItem.objects.create(
                prescription = rx,
                item_id      = item_id,
                item_name    = item_name,
                brand        = brand,
                quantity     = float(med.get('quantity', 1)),
                unit         = (med.get('unit')         or 'unit(s)').strip(),
                dosage       = (med.get('dosage')       or '').strip(),
                duration     = (med.get('duration')     or '').strip(),
                instructions = (med.get('instructions') or '').strip(),
            )

    log_activity(
        request,
        action='Write Prescription',
        category='customers',
        description=(
            f'Prescription for "{customer_name}" ({customer_phone}) '
            f'with {len(medications_data)} medication(s)'
        ),
    )
    return Response(rx.to_api_dict(), status=status.HTTP_201_CREATED)


# ── Retrieve / Update / Delete ────────────────────────────────────────────────

@api_view(['GET', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated, IsPrescriptionUser])
def prescription_detail(request, pk):
    org, err = require_org(request)
    if err:
        return err

    try:
        rx = (Prescription.objects
              .prefetch_related('medications')
              .get(pk=pk, organization=org))
    except Prescription.DoesNotExist:
        return Response({'detail': 'Prescription not found'},
                        status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        return Response(rx.to_api_dict())

    if request.method == 'PATCH':
        # Only write-permission roles may edit prescription metadata.
        if request.user.role not in PRESCRIPTIONS_WRITE:
            return Response(
                {'detail': 'You do not have permission to edit prescriptions.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        data = request.data
        changed = False

        if 'doctor_name' in data:
            rx.doctor_name = (data['doctor_name'] or '').strip()
            changed = True
        if 'diagnosis' in data:
            rx.diagnosis = (data['diagnosis'] or '').strip()
            changed = True
        if 'notes' in data:
            rx.notes = (data['notes'] or '').strip()
            changed = True
        if 'status' in data and data['status'] in ('pending', 'partial', 'dispensed'):
            rx.status = data['status']
            # Keep dispensed_at in sync when manually setting status.
            if data['status'] == 'dispensed' and not rx.dispensed_at:
                rx.dispensed_at = timezone.now()
            elif data['status'] in ('pending', 'partial'):
                rx.dispensed_at = None
            changed = True

        if changed:
            rx.save()
            log_activity(
                request,
                action='Update Prescription',
                category='customers',
                description=f'Updated metadata on Rx#{pk} for "{rx.customer_name}"',
            )

        # Return fresh serialisation (medications prefetched by the initial get).
        return Response(rx.to_api_dict())

    # DELETE
    rx.delete()
    log_activity(request, action='Delete Prescription', category='customers',
                 description=f'Deleted prescription #{pk}')
    return Response(status=status.HTTP_204_NO_CONTENT)


# ── Dispense ──────────────────────────────────────────────────────────────────

@api_view(['PATCH'])
@permission_classes([IsAuthenticated, IsPrescriptionUser])
def dispense_prescription(request, pk):
    """
    Mark medications as dispensed.
    Body (all optional):
        { "item_indices": [0, 2] }   → dispense items at those list positions
        { }                          → dispense ALL remaining undispensed items
    """
    org, err = require_org(request)
    if err:
        return err

    try:
        rx = (Prescription.objects
              .prefetch_related('medications')
              .get(pk=pk, organization=org))
    except Prescription.DoesNotExist:
        return Response({'detail': 'Prescription not found'},
                        status=status.HTTP_404_NOT_FOUND)

    if rx.status == 'dispensed':
        return Response({'detail': 'All medications are already dispensed.'},
                        status=status.HTTP_400_BAD_REQUEST)

    item_indices = request.data.get('item_indices')  # list[int] or None
    medications  = list(rx.medications.all())
    now          = timezone.now()

    with transaction.atomic():
        if item_indices:
            # Dispense only the items at the given 0-based positions
            for i in item_indices:
                if 0 <= i < len(medications) and not medications[i].is_dispensed:
                    med = medications[i]
                    med.is_dispensed = True
                    med.dispensed_at = now
                    med.dispensed_by = request.user
                    med.save()
        else:
            # Dispense everything still pending
            for med in medications:
                if not med.is_dispensed:
                    med.is_dispensed = True
                    med.dispensed_at = now
                    med.dispensed_by = request.user
                    med.save()

        # Recompute aggregate status
        rx.refresh_from_db()
        rx.recompute_status()
        rx.save()

    log_activity(
        request,
        action='Dispense Prescription',
        category='customers',
        description=f'Dispensed medications on Rx#{pk} for "{rx.customer_name}"',
    )

    # Return fresh data with prefetched medications
    rx = (Prescription.objects
          .prefetch_related('medications')
          .get(pk=pk))
    return Response(rx.to_api_dict())


# ── Undispensed prescriptions for a specific customer ────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated, IsPrescriptionUser])
def customer_prescriptions(request, customer_pk):
    """
    GET /api/prescriptions/customer/<customer_pk>/
    Returns all prescriptions belonging to the given customer.
    Pass ?undispensed=1 to restrict to those with outstanding medications.
    """
    org, err = require_org(request)
    if err:
        return err

    try:
        from customers.models import Customer
        customer = Customer.objects.get(pk=customer_pk, organization=org)
    except Exception:
        return Response({'detail': 'Customer not found'},
                        status=status.HTTP_404_NOT_FOUND)

    qs = (Prescription.objects
          .filter(organization=org, customer=customer)
          .prefetch_related('medications'))

    undispensed_only = request.query_params.get('undispensed', '').lower() in ('1', 'true')
    if undispensed_only:
        qs = qs.filter(status__in=['pending', 'partial'])

    return Response([rx.to_api_dict() for rx in qs])


# ── Lookup by customer phone (for cross-pharmacy POS dispensing) ──────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated, IsPrescriptionUser])
def prescriptions_by_phone(request):
    """
    GET /api/prescriptions/by-phone/?phone=<number>[&undispensed=1]
    Returns prescriptions linked to the given phone number within this org.
    Useful when scanning a walk-in patient's number at the dispense counter.
    """
    org, err = require_org(request)
    if err:
        return err

    phone = request.query_params.get('phone', '').strip()
    if not phone:
        return Response({'detail': 'phone query parameter is required'},
                        status=status.HTTP_400_BAD_REQUEST)

    qs = (Prescription.objects
          .filter(organization=org, customer_phone=phone)
          .prefetch_related('medications'))

    undispensed_only = request.query_params.get('undispensed', '').lower() in ('1', 'true')
    if undispensed_only:
        qs = qs.filter(status__in=['pending', 'partial'])

    return Response([rx.to_api_dict() for rx in qs])
