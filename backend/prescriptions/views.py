from django.core import signing
from django.db import models as _m, transaction
from django.db.models import Count, Case, When, IntegerField, F
from django.utils import timezone
from django.contrib.auth.hashers import make_password, check_password
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

_PRESCRIBER_TOKEN_SALT = 'prescriber-portal-auth'
_PRESCRIBER_TOKEN_MAX_AGE = 60 * 60 * 24 * 30  # 30 days


def _issue_prescriber_token(prescriber_id: int) -> str:
    return signing.dumps({'prescriber_id': prescriber_id}, salt=_PRESCRIBER_TOKEN_SALT)


def _verify_prescriber_token(token: str):
    """Return Prescriber instance or None."""
    try:
        data = signing.loads(token, salt=_PRESCRIBER_TOKEN_SALT, max_age=_PRESCRIBER_TOKEN_MAX_AGE)
        return Prescriber.objects.get(pk=data['prescriber_id'])
    except Exception:
        return None


def _portal_token_owner(request, prescriber) -> bool:
    """True only if the X-Prescriber-Token in the request belongs to `prescriber`.

    Object-level auth: a valid token for prescriber A must NOT grant access to
    prescriber B's records.
    """
    token = (request.META.get('HTTP_X_PRESCRIBER_TOKEN') or '').strip()
    tok_presc = _verify_prescriber_token(token) if token else None
    return tok_presc is not None and tok_presc.pk == prescriber.pk

from authapp.utils import require_org, log_activity
from authapp.permissions import IsPrescriptionUser, PRESCRIPTIONS_WRITE
from authapp.models import PharmacyNetworkMembership
from .models import (
    Prescription, PrescriptionItem, Prescriber, Hospital,
    PrescriberCommission, ConsultationPayout,
)


# ── Helpers ───────────────────────────────────────────────────────────────────

def _get_peer_org_ids(org) -> set:
    """Return set of org IDs (own + active network peers) for cross-org queries."""
    my_network_ids = list(
        PharmacyNetworkMembership.objects
        .filter(organization=org, status='active')
        .values_list('network_id', flat=True)
    )
    peer_ids = {org.id}
    if my_network_ids:
        peer_ids.update(
            PharmacyNetworkMembership.objects
            .filter(network_id__in=my_network_ids, status='active')
            .values_list('organization_id', flat=True)
        )
    return peer_ids


_CONSULT_FEE_FIELDS = {
    'A': 'consult_fee_a', 'B': 'consult_fee_b', 'C': 'consult_fee_c',
    'D': 'consult_fee_d', 'E': 'consult_fee_e',
}


def _apply_consult_fees(prescriber, data) -> bool:
    """
    Apply A–E consultation-fee bands from request data onto a Prescriber.
    Accepts either a nested {'consultation_fees': {'A': 1000, ...}} dict or
    flat keys (consult_fee_a, ...). Returns True if anything changed.
    """
    fees = data.get('consultation_fees')
    changed = False
    for letter, field in _CONSULT_FEE_FIELDS.items():
        raw = None
        if isinstance(fees, dict):
            if letter in fees:
                raw = fees[letter]
            elif letter.lower() in fees:
                raw = fees[letter.lower()]
        if raw is None and field in data:
            raw = data[field]
        if raw is None:
            continue
        try:
            val = float(raw or 0)
        except (TypeError, ValueError):
            continue
        if val < 0:
            continue
        setattr(prescriber, field, val)
        changed = True
    return changed


def _resolve_consultation(prescriber_obj, data):
    """
    Return (category, fee) for a prescription. Category is one of A–E or ''.
    The fee is taken from an explicit `consultation_fee` in the request when
    provided (pharmacy override); otherwise derived from the prescriber's band.
    """
    from decimal import Decimal, InvalidOperation
    category = (data.get('consultation_category') or '').strip().upper()
    if category not in _CONSULT_FEE_FIELDS:
        category = ''

    fee = None
    raw_fee = data.get('consultation_fee')
    if raw_fee is not None and raw_fee != '':
        try:
            fee = Decimal(str(raw_fee))
        except (InvalidOperation, TypeError, ValueError):
            fee = None
    if fee is None:
        if prescriber_obj and category:
            fee = Decimal(str(prescriber_obj.fee_for_category(category)))
        else:
            fee = Decimal('0')
    if fee < 0:
        fee = Decimal('0')
    return category, fee


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
        source = request.query_params.get('source', '').strip()

        # Portal prescriptions are written by global prescribers (no org binding).
        # Any authenticated pharmacy can view and dispense them, so drop the org
        # filter when source=portal is explicitly requested.
        if source == 'portal':
            qs = (Prescription.objects
                  .filter(source='portal')
                  .select_related('organization', 'created_by', 'branch')
                  .prefetch_related('medications'))
        else:
            qs = (Prescription.objects
                  .filter(organization=org)
                  .select_related('organization', 'created_by', 'branch')
                  .prefetch_related('medications'))
            if source:
                qs = qs.filter(source=source)

        # Status filter — 'undispensed' is a convenience alias for pending+partial
        rx_status = request.query_params.get('status', '').strip()
        if rx_status == 'undispensed':
            qs = qs.filter(status__in=['pending', 'partial'])
        elif rx_status in ('pending', 'partial', 'dispensed'):
            qs = qs.filter(status=rx_status)

        # network_wide=true → show all branches; branch_id → scope to one branch.
        # The two are mutually exclusive; network_wide takes precedence.
        network_wide = request.query_params.get('network_wide', '').lower() in ('1', 'true')
        branch_filtered = False
        if source != 'portal' and not network_wide:
            branch_id = request.query_params.get('branch_id', '')
            branch_filtered = branch_id.isdigit() and int(branch_id) > 0
            if branch_filtered:
                qs = qs.filter(branch_id=int(branch_id))

        # Customer filter
        customer_id = request.query_params.get('customer_id', '')
        if customer_id.isdigit():
            qs = qs.filter(customer_id=int(customer_id))

        # Text search — name, phone, doctor, diagnosis
        search = request.query_params.get('search', '').strip()
        if search:
            qs = qs.filter(
                _m.Q(customer_name__icontains=search) |
                _m.Q(customer_phone__icontains=search) |
                _m.Q(doctor_name__icontains=search) |
                _m.Q(diagnosis__icontains=search)
            )

        # network_wide: group by branch then newest first (grouped display).
        # Single branch or no filter: flat newest-first.
        if network_wide:
            qs = qs.order_by(
                F('branch__name').asc(nulls_last=True),
                '-created_at',
            )
        elif not branch_filtered:
            qs = qs.order_by('-created_at')

        # Pagination — page_size=50; Flutter client handles {'count', 'results'} format.
        page_size = 50
        try:
            page = max(1, int(request.query_params.get('page', '1')))
        except (ValueError, TypeError):
            page = 1
        total = qs.count()
        offset = (page - 1) * page_size
        page_qs = qs[offset:offset + page_size]

        return Response({'count': total, 'results': [rx.to_api_dict() for rx in page_qs]})

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

    # Resolve structured prescriber FK (optional) — global, no org filter
    prescriber_obj = None
    prescriber_id  = data.get('prescriber_id')
    if prescriber_id:
        try:
            prescriber_obj = Prescriber.objects.get(pk=prescriber_id)
        except Prescriber.DoesNotExist:
            pass  # non-fatal — fallback to doctor_name text

    # Derive doctor_name: prefer prescriber name; fallback to free-text field
    doctor_name_raw = (data.get('doctor_name') or '').strip()
    if prescriber_obj and not doctor_name_raw:
        doctor_name_raw = prescriber_obj.name

    consult_category, consult_fee = _resolve_consultation(prescriber_obj, data)

    with transaction.atomic():
        rx = Prescription.objects.create(
            organization   = org,
            branch_id      = branch_id if branch_id else None,
            customer       = customer_obj,
            customer_name  = customer_name,
            customer_phone = customer_phone,
            prescriber     = prescriber_obj,
            doctor_name    = doctor_name_raw,
            diagnosis      = (data.get('diagnosis')    or '').strip(),
            notes          = (data.get('notes')        or '').strip(),
            consultation_category = consult_category,
            consultation_fee      = consult_fee,
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

    if request.method == 'GET':
        # Network peer orgs and any pharmacy may view portal prescriptions.
        try:
            rx = (Prescription.objects
                  .select_related('organization', 'created_by', 'branch')
                  .prefetch_related('medications')
                  .get(pk=pk, organization=org))
        except Prescription.DoesNotExist:
            peer_org_ids = _get_peer_org_ids(org)
            rx = (Prescription.objects
                  .select_related('organization', 'created_by', 'branch')
                  .prefetch_related('medications')
                  .filter(pk=pk)
                  .filter(_m.Q(organization_id__in=peer_org_ids) | _m.Q(source='portal'))
                  .first())
            if rx is None:
                return Response({'detail': 'Prescription not found'},
                                status=status.HTTP_404_NOT_FOUND)
        return Response(rx.to_api_dict())

    # PATCH / DELETE — restricted to the owning org only.
    try:
        rx = (Prescription.objects
              .select_related('organization', 'created_by', 'branch')
              .prefetch_related('medications')
              .get(pk=pk, organization=org))
    except Prescription.DoesNotExist:
        return Response({'detail': 'Prescription not found'},
                        status=status.HTTP_404_NOT_FOUND)

    if request.method == 'PATCH':
        # Only write-permission roles may edit prescription metadata.
        if request.user.role not in PRESCRIPTIONS_WRITE:
            return Response(
                {'detail': 'You do not have permission to edit prescriptions.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        data = request.data
        changed = False

        if 'prescriber_id' in data:
            pid = data['prescriber_id']
            if pid:
                try:
                    rx.prescriber = Prescriber.objects.get(pk=pid)
                    if not data.get('doctor_name'):
                        rx.doctor_name = rx.prescriber.name
                except Prescriber.DoesNotExist:
                    pass
            else:
                rx.prescriber = None
            changed = True
        if 'doctor_name' in data:
            rx.doctor_name = (data['doctor_name'] or '').strip()
            changed = True
        if 'diagnosis' in data:
            rx.diagnosis = (data['diagnosis'] or '').strip()
            changed = True
        if 'notes' in data:
            rx.notes = (data['notes'] or '').strip()
            changed = True
        if 'consultation_category' in data or 'consultation_fee' in data:
            # Re-resolve against the (possibly updated) prescriber band, honoring
            # an explicit consultation_fee as a pharmacy override.
            cat, fee = _resolve_consultation(rx.prescriber, data)
            if 'consultation_category' in data:
                rx.consultation_category = cat
            rx.consultation_fee = fee
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
              .select_related('organization', 'created_by', 'branch', 'prescriber')
              .prefetch_related('medications')
              .get(pk=pk, organization=org))
    except Prescription.DoesNotExist:
        # Allow network peer orgs and any pharmacy to dispense portal Rxs.
        peer_org_ids = _get_peer_org_ids(org)
        rx = (Prescription.objects
              .select_related('organization', 'created_by', 'branch', 'prescriber')
              .prefetch_related('medications')
              .filter(pk=pk)
              .filter(_m.Q(organization_id__in=peer_org_ids) | _m.Q(source='portal'))
              .first())
        if rx is None:
            return Response({'detail': 'Prescription not found'},
                            status=status.HTTP_404_NOT_FOUND)

    if rx.status == 'dispensed':
        return Response({'detail': 'All medications are already dispensed.'},
                        status=status.HTTP_400_BAD_REQUEST)

    item_indices    = request.data.get('item_indices')  # list[int] or None
    medications     = list(rx.medications.all())
    now             = timezone.now()
    newly_dispensed = []

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
                    newly_dispensed.append(med)
        else:
            # Dispense everything still pending
            for med in medications:
                if not med.is_dispensed:
                    med.is_dispensed = True
                    med.dispensed_at = now
                    med.dispensed_by = request.user
                    med.save()
                    newly_dispensed.append(med)

        # Compute status from the in-memory medications list (avoids stale
        # prefetch cache that refresh_from_db() does not clear).
        dispensed_count = sum(1 for m in medications if m.is_dispensed)
        if dispensed_count == 0:
            rx.status = 'pending'
            rx.dispensed_at = None
        elif dispensed_count == len(medications):
            rx.status = 'dispensed'
            if not rx.dispensed_at:
                rx.dispensed_at = now
        else:
            rx.status = 'partial'
        rx.save()

        # For portal prescriptions whose items were written without an
        # inventory FK (self-registered prescribers have no org), resolve
        # item_id against the dispensing pharmacy's org so commission
        # calculation can look up prices.
        if rx.source == 'portal':
            for med in newly_dispensed:
                if not med.item_id:
                    resolved = _resolve_item(org, med.item_name, med.brand or '')
                    if resolved:
                        med.item_id = resolved
                        PrescriptionItem.objects.filter(pk=med.pk).update(item_id=resolved)

        # ── Auto-generate commission if prescriber has a non-zero rate ────────
        _create_commission_for_dispense(rx, newly_dispensed)

        # ── Auto-record consultation-fee payout (once per prescription) ───────
        _create_consultation_payout_for_dispense(rx)

    log_activity(
        request,
        action='Dispense Prescription',
        category='customers',
        description=f'Dispensed medications on Rx#{pk} for "{rx.customer_name}"',
    )

    # Return fresh data — use pk only (org already verified above)
    rx = (Prescription.objects
          .select_related('organization', 'created_by', 'branch', 'prescriber')
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
          .select_related('organization', 'created_by', 'branch')
          .prefetch_related('medications')
          .order_by('-created_at'))

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

    q = (request.query_params.get('q') or request.query_params.get('phone') or '').strip()
    if not q:
        return Response({'detail': 'q (or phone) query parameter is required'},
                        status=status.HTTP_400_BAD_REQUEST)

    # Match customer phone (contains) OR customer name (contains).
    name_or_phone = _m.Q(customer_phone__icontains=q) | _m.Q(customer_name__icontains=q)

    # Always include portal prescriptions (org=null) alongside org-scoped ones.
    portal_q = _m.Q(source='portal', organization__isnull=True)

    # ?network=true expands the search to all active network peer orgs.
    network = request.query_params.get('network', '').lower() in ('1', 'true')
    if network:
        org_ids = _get_peer_org_ids(org)
        qs = (Prescription.objects
              .filter(name_or_phone, _m.Q(organization_id__in=org_ids) | portal_q)
              .select_related('organization', 'created_by', 'branch')
              .prefetch_related('medications'))
    else:
        qs = (Prescription.objects
              .filter(name_or_phone, _m.Q(organization=org) | portal_q)
              .select_related('organization', 'created_by', 'branch')
              .prefetch_related('medications'))

    undispensed_only = request.query_params.get('undispensed', '').lower() in ('1', 'true')
    if undispensed_only:
        qs = qs.filter(status__in=['pending', 'partial'])

    return Response([rx.to_api_dict() for rx in qs.order_by('-created_at')])


# ── Network-wide pending count ────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated, IsPrescriptionUser])
def pending_count(request):
    """
    GET /api/prescriptions/pending-count/
    Returns { "pending": N, "partial": M, "total": N+M }

    Efficient aggregate — does not load prescription objects.
    Used by the Flutter header badge to show total unresolved Rxs across the network.
    Optionally scoped to a single branch via ?branch_id=<int>.
    """
    org, err = require_org(request)
    if err:
        return err

    qs = Prescription.objects.filter(
        organization=org,
        status__in=['pending', 'partial'],
    )

    branch_id = request.query_params.get('branch_id', '')
    if branch_id.isdigit() and int(branch_id) > 0:
        qs = qs.filter(branch_id=int(branch_id))

    counts = qs.aggregate(
        pending=Count(
            Case(When(status='pending', then=1), output_field=IntegerField())
        ),
        partial=Count(
            Case(When(status='partial', then=1), output_field=IntegerField())
        ),
    )
    pending = counts['pending'] or 0
    partial = counts['partial'] or 0

    return Response({
        'pending': pending,
        'partial': partial,
        'total':   pending + partial,
    })


# ── Cross-network prescriptions ───────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated, IsPrescriptionUser])
def network_prescriptions(request):
    """
    GET /api/prescriptions/network/

    Returns prescriptions from every organization that shares at least one
    active PharmacyNetwork with the requesting user's org.  Falls back to
    the current org only when the org has no active network memberships.

    Query params:
        status      — pending | partial | dispensed | undispensed
        search      — patient name / phone / doctor / diagnosis
        network_id  — (optional) scope to a specific network
        page        — 1-based pagination (50 per page)
    """
    org, err = require_org(request)
    if err:
        return err

    source = request.query_params.get('source', '').strip()

    # Portal prescriptions are global — any pharmacy can see them.
    # When source=portal is explicitly requested, skip the org/network filter.
    if source == 'portal':
        qs = (Prescription.objects
              .filter(source='portal')
              .select_related('organization', 'created_by', 'branch')
              .prefetch_related('medications'))
    else:
        # Collect all network IDs this org actively belongs to
        my_network_ids = list(
            PharmacyNetworkMembership.objects
            .filter(organization=org, status='active')
            .values_list('network_id', flat=True)
        )

        if my_network_ids:
            # Optionally scope to one specific network the caller belongs to
            network_id_param = request.query_params.get('network_id', '')
            if network_id_param.isdigit() and int(network_id_param) > 0:
                requested_net = int(network_id_param)
                if requested_net not in my_network_ids:
                    return Response(
                        {'detail': 'You are not an active member of that network.'},
                        status=status.HTTP_403_FORBIDDEN,
                    )
                active_network_ids = [requested_net]
            else:
                active_network_ids = my_network_ids

            # All org IDs that are active members of any of those networks
            peer_org_ids = list(
                PharmacyNetworkMembership.objects
                .filter(network_id__in=active_network_ids, status='active')
                .values_list('organization_id', flat=True)
                .distinct()
            )
            qs = (Prescription.objects
                  .filter(organization_id__in=peer_org_ids)
                  .select_related('organization', 'created_by', 'branch')
                  .prefetch_related('medications'))
        else:
            # No active networks — fall back to own org
            qs = (Prescription.objects
                  .filter(organization=org)
                  .select_related('organization', 'created_by', 'branch')
                  .prefetch_related('medications'))

    # Status filter
    rx_status = request.query_params.get('status', '').strip()
    if rx_status == 'undispensed':
        qs = qs.filter(status__in=['pending', 'partial'])
    elif rx_status in ('pending', 'partial', 'dispensed'):
        qs = qs.filter(status=rx_status)

    # Text search
    search = request.query_params.get('search', '').strip()
    if search:
        qs = qs.filter(
            _m.Q(customer_name__icontains=search) |
            _m.Q(customer_phone__icontains=search) |
            _m.Q(doctor_name__icontains=search) |
            _m.Q(diagnosis__icontains=search)
        )

    # Order by org → branch → newest first (enables grouped display in Flutter)
    qs = qs.order_by(
        'organization__name',
        F('branch__name').asc(nulls_last=True),
        '-created_at',
    )

    # Pagination (50 per page)
    page_size = 50
    try:
        page = max(1, int(request.query_params.get('page', '1')))
    except (ValueError, TypeError):
        page = 1
    total  = qs.count()
    offset = (page - 1) * page_size
    page_qs = qs[offset:offset + page_size]

    return Response({'count': total, 'results': [rx.to_api_dict() for rx in page_qs]})


# ── Hospital CRUD ─────────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def hospital_list(request):
    """
    GET  /api/prescriptions/hospitals/   ?search=<str>
    POST /api/prescriptions/hospitals/   { name, address?, phone?, city? }
    Global — not org-scoped. Any authenticated user can list or create.
    """
    if request.method == 'GET':
        search = request.query_params.get('search', '').strip()
        qs = Hospital.objects.all()
        if search:
            qs = qs.filter(
                _m.Q(name__icontains=search) |
                _m.Q(city__icontains=search)
            )
        return Response([h.to_api_dict() for h in qs[:100]])

    name = (request.data.get('name') or '').strip()
    if not name:
        return Response({'detail': 'name is required'}, status=status.HTTP_400_BAD_REQUEST)

    hospital = Hospital.objects.create(
        name    = name,
        address = (request.data.get('address') or '').strip(),
        phone   = (request.data.get('phone') or '').strip(),
        city    = (request.data.get('city') or '').strip(),
    )
    return Response(hospital.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(['GET', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated])
def hospital_detail(request, pk):
    """
    GET    /api/prescriptions/hospitals/<pk>/
    PATCH  /api/prescriptions/hospitals/<pk>/
    DELETE /api/prescriptions/hospitals/<pk>/
    """
    try:
        hospital = Hospital.objects.get(pk=pk)
    except Hospital.DoesNotExist:
        return Response({'detail': 'Hospital not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        return Response(hospital.to_api_dict())

    if request.method == 'PATCH':
        data = request.data
        if 'name' in data:
            hospital.name = (data['name'] or '').strip()
        if 'address' in data:
            hospital.address = (data['address'] or '').strip()
        if 'phone' in data:
            hospital.phone = (data['phone'] or '').strip()
        if 'city' in data:
            hospital.city = (data['city'] or '').strip()
        hospital.save()
        return Response(hospital.to_api_dict())

    # DELETE — block if prescribers still reference this hospital
    count = hospital.prescribers.count()
    if count > 0:
        return Response(
            {'detail': f'Cannot delete: {count} prescriber(s) linked to this hospital.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    hospital.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


# ── Prescriber CRUD ───────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def prescriber_list(request):
    """
    GET  /api/prescriptions/prescribers/
         ?search=<str>       — filter by name / license / specialty / hospital
         ?hospital_id=<int>  — scope to one hospital

    POST /api/prescriptions/prescribers/
         Global — no org required. Associates prescriber with a hospital.
    """
    if request.method == 'GET':
        search      = request.query_params.get('search', '').strip()
        hospital_id = request.query_params.get('hospital_id', '')

        qs = Prescriber.objects.select_related('hospital').all()

        if hospital_id.isdigit() and int(hospital_id) > 0:
            qs = qs.filter(hospital_id=int(hospital_id))

        if search:
            qs = qs.filter(
                _m.Q(name__icontains=search) |
                _m.Q(license_number__icontains=search) |
                _m.Q(specialty__icontains=search) |
                _m.Q(hospital__name__icontains=search) |
                _m.Q(clinic__icontains=search)
            )

        return Response([p.to_api_dict() for p in qs[:100]])

    # ── POST: create ──────────────────────────────────────────────────────────
    name = (request.data.get('name') or '').strip()
    if not name:
        return Response({'detail': 'name is required'}, status=status.HTTP_400_BAD_REQUEST)

    hospital = None
    hospital_id = request.data.get('hospital_id')
    if hospital_id:
        try:
            hospital = Hospital.objects.get(pk=hospital_id)
        except Hospital.DoesNotExist:
            pass

    # Link prescriber to the creating pharmacy's org so portal prescriptions
    # they write can be scoped back to this pharmacy.
    creator_org = getattr(getattr(request.user, 'organization', None), 'id', None)
    try:
        commission_rate = float(request.data.get('commission_rate') or 0)
        if not (0 <= commission_rate <= 100):
            commission_rate = 0.0
    except (TypeError, ValueError):
        commission_rate = 0.0

    prescriber = Prescriber.objects.create(
        organization_id = creator_org,
        hospital        = hospital,
        name            = name,
        license_number  = (request.data.get('license_number') or '').strip(),
        specialty       = (request.data.get('specialty') or '').strip(),
        phone           = (request.data.get('phone') or '').strip(),
        address         = (request.data.get('address') or '').strip(),
        commission_rate = commission_rate,
    )
    if _apply_consult_fees(prescriber, request.data):
        prescriber.save()
    log_activity(
        request,
        action='Add Prescriber',
        category='customers',
        description=f'Prescriber "{prescriber.name}" registered',
    )
    return Response(prescriber.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(['GET', 'PATCH', 'DELETE'])
@permission_classes([AllowAny])
def prescriber_detail(request, pk):
    """
    GET    /api/prescriptions/prescribers/<pk>/
    PATCH  /api/prescriptions/prescribers/<pk>/
    DELETE /api/prescriptions/prescribers/<pk>/
    Pharmacy staff (IsAuthenticated): read any; write requires PRESCRIPTIONS_WRITE role.
    Prescriber portal token (X-Prescriber-Token): may read and self-update consultation
    fees on its OWN record only — no other fields, no DELETE.
    """
    try:
        prescriber = Prescriber.objects.select_related('hospital').get(pk=pk)
    except Prescriber.DoesNotExist:
        return Response({'detail': 'Prescriber not found'}, status=status.HTTP_404_NOT_FOUND)

    # Portal token path — only the prescriber's own record.
    portal_self = False
    if not request.user.is_authenticated:
        token = (request.META.get('HTTP_X_PRESCRIBER_TOKEN') or '').strip()
        tok_presc = _verify_prescriber_token(token) if token else None
        if tok_presc is None or tok_presc.pk != prescriber.pk:
            return Response({'detail': 'Authentication credentials were not provided.'},
                            status=status.HTTP_401_UNAUTHORIZED)
        portal_self = True

    if request.method == 'GET':
        return Response(prescriber.to_api_dict())

    if portal_self:
        # Prescriber self-service: consultation fees only.
        if request.method != 'PATCH':
            return Response({'detail': 'Permission denied.'}, status=status.HTTP_403_FORBIDDEN)
        _apply_consult_fees(prescriber, request.data)
        prescriber.save()
        return Response(prescriber.to_api_dict())

    if request.user.role not in PRESCRIPTIONS_WRITE:
        return Response({'detail': 'Permission denied.'}, status=status.HTTP_403_FORBIDDEN)

    if request.method == 'PATCH':
        data = request.data
        if 'name' in data:
            prescriber.name = (data['name'] or '').strip()
        if 'license_number' in data:
            prescriber.license_number = (data['license_number'] or '').strip()
        if 'specialty' in data:
            prescriber.specialty = (data['specialty'] or '').strip()
        if 'phone' in data:
            prescriber.phone = (data['phone'] or '').strip()
        if 'address' in data:
            prescriber.address = (data['address'] or '').strip()
        if 'hospital_id' in data:
            hid = data['hospital_id']
            if hid:
                try:
                    prescriber.hospital = Hospital.objects.get(pk=hid)
                except Hospital.DoesNotExist:
                    pass
            else:
                prescriber.hospital = None
        if 'is_verified' in data:
            prescriber.is_verified = bool(data['is_verified'])
        if 'commission_rate' in data:
            try:
                rate = float(data['commission_rate'])
                if 0 <= rate <= 100:
                    prescriber.commission_rate = rate
            except (TypeError, ValueError):
                pass
        _apply_consult_fees(prescriber, data)
        prescriber.save()
        log_activity(
            request,
            action='Update Prescriber',
            category='customers',
            description=f'Updated prescriber "{prescriber.name}"',
        )
        return Response(prescriber.to_api_dict())

    # DELETE — block if active prescriptions still reference this prescriber
    rx_count = prescriber.prescriptions.count()
    if rx_count > 0:
        return Response(
            {'detail': f'Cannot delete: {rx_count} prescription(s) reference this prescriber.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    name = prescriber.name
    prescriber.delete()
    log_activity(
        request,
        action='Delete Prescriber',
        category='customers',
        description=f'Deleted prescriber "{name}"',
    )
    return Response(status=status.HTTP_204_NO_CONTENT)


# ── Prescriber's patient list ─────────────────────────────────────────────────

@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def prescriber_patients(request, pk):
    """
    GET  /api/prescriptions/prescribers/<pk>/patients/
    POST /api/prescriptions/prescribers/<pk>/patients/
    No pharmacy JWT required — scoped to the prescriber's own patients.
    POST body: { name, phone, is_network_patient?, blood_group?, date_of_birth?,
                 allergies?, chronic_conditions?, email?, address? }
    """
    try:
        prescriber = Prescriber.objects.get(pk=pk)
    except Prescriber.DoesNotExist:
        return Response({'detail': 'Prescriber not found'}, status=status.HTTP_404_NOT_FOUND)

    # Patient PII — require pharmacy staff JWT or this prescriber's own portal token.
    if not request.user.is_authenticated and not _portal_token_owner(request, prescriber):
        return Response({'detail': 'Authentication required.'}, status=status.HTTP_401_UNAUTHORIZED)

    from customers.models import Customer

    if request.method == 'GET':
        qs = Customer.objects.filter(prescriber=prescriber)
        return Response([c.to_list_dict() for c in qs])

    # POST — register a new patient under this prescriber
    name  = (request.data.get('name') or '').strip()
    phone = (request.data.get('phone') or '').strip()
    if not name:
        return Response({'detail': 'name is required'}, status=status.HTTP_400_BAD_REQUEST)
    if not phone:
        return Response({'detail': 'phone is required'}, status=status.HTTP_400_BAD_REQUEST)

    # Prevent duplicate phone under same prescriber
    if Customer.objects.filter(prescriber=prescriber, phone=phone).exists():
        return Response(
            {'detail': 'A patient with this phone number is already registered under this prescriber.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    dob = None
    dob_raw = (request.data.get('date_of_birth') or '').strip()
    if dob_raw:
        from datetime import date
        try:
            parts = dob_raw.split('-')
            dob = date(int(parts[0]), int(parts[1]), int(parts[2]))
        except (ValueError, IndexError):
            dob = None

    customer = Customer.objects.create(
        prescriber         = prescriber,
        name               = name,
        phone              = phone,
        organization       = None,
        is_network_patient = bool(request.data.get('is_network_patient', True)),
        blood_group        = (request.data.get('blood_group') or '').strip(),
        date_of_birth      = dob,
        allergies          = request.data.get('allergies') or [],
        chronic_conditions = request.data.get('chronic_conditions') or [],
        email              = (request.data.get('email') or '').strip(),
        address            = (request.data.get('address') or '').strip(),
    )
    return Response(customer.to_list_dict(), status=status.HTTP_201_CREATED)


# ── Public self-registration (no auth, no org) ────────────────────────────────

@api_view(['POST'])
@permission_classes([AllowAny])
def prescriber_register(request):
    """
    POST /api/prescriptions/prescribers/register/
    Public self-registration. Creates an unverified prescriber linked to a hospital.
    No JWT required.
    """
    name = (request.data.get('name') or '').strip()
    if not name:
        return Response({'detail': 'name is required'}, status=status.HTTP_400_BAD_REQUEST)

    password_raw = (request.data.get('password') or '').strip()
    if not password_raw:
        return Response({'detail': 'password is required'}, status=status.HTTP_400_BAD_REQUEST)
    if len(password_raw) < 8:
        return Response({'detail': 'password must be at least 8 characters'}, status=status.HTTP_400_BAD_REQUEST)

    phone = (request.data.get('phone') or '').strip()
    if not phone:
        return Response({'detail': 'phone is required'}, status=status.HTTP_400_BAD_REQUEST)
    if Prescriber.objects.filter(phone=phone).exists():
        return Response({'detail': 'A prescriber with this phone number already exists.'}, status=status.HTTP_400_BAD_REQUEST)

    hospital = None
    hospital_id = request.data.get('hospital_id')
    if hospital_id:
        try:
            hospital = Hospital.objects.get(pk=hospital_id)
        except Hospital.DoesNotExist:
            pass

    prescriber = Prescriber.objects.create(
        hospital       = hospital,
        name           = name,
        license_number = (request.data.get('license_number') or '').strip(),
        specialty      = (request.data.get('specialty') or '').strip(),
        phone          = phone,
        address        = (request.data.get('address') or '').strip(),
        password       = make_password(password_raw),
        is_verified    = False,
    )
    return Response(prescriber.to_api_dict(), status=status.HTTP_201_CREATED)


# ── Prescriber login ──────────────────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([AllowAny])
def prescriber_login(request):
    """
    POST /api/prescriptions/prescribers/login/
    Body: { phone, password }
    Returns prescriber profile data on success.
    """
    phone    = (request.data.get('phone') or '').strip()
    password = (request.data.get('password') or '').strip()

    if not phone or not password:
        return Response(
            {'detail': 'phone and password are required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        prescriber = Prescriber.objects.select_related('hospital').get(phone=phone)
    except Prescriber.DoesNotExist:
        return Response({'detail': 'Invalid credentials.'}, status=status.HTTP_401_UNAUTHORIZED)
    except Prescriber.MultipleObjectsReturned:
        return Response(
            {'detail': 'Multiple accounts found with this phone. Contact admin.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if not prescriber.password or not check_password(password, prescriber.password):
        return Response({'detail': 'Invalid credentials.'}, status=status.HTTP_401_UNAUTHORIZED)

    token = _issue_prescriber_token(prescriber.id)
    return Response({'prescriber': prescriber.to_api_dict(), 'token': token})


# ── Prescriber portal — create prescription (no pharmacy JWT) ─────────────────

def _create_commission_for_dispense(rx, newly_dispensed_items):
    """
    Called inside dispense_prescription's atomic block.
    Creates one PrescriberCommission for the newly-dispensed items.
    Skips silently if: no prescriber, commission_rate == 0, no items with price.
    """
    if not rx.prescriber_id:
        return
    prescriber = rx.prescriber
    if not prescriber.commission_rate or prescriber.commission_rate <= 0:
        return
    if not newly_dispensed_items:
        return

    # Sum selling price * quantity for items that have an inventory FK.
    # Items without item_id have no known price — excluded from calculation.
    from decimal import Decimal
    from inventory.models import Item as InventoryItem

    item_ids = [m.item_id for m in newly_dispensed_items if m.item_id]
    prices   = {}
    if item_ids:
        for inv_item in InventoryItem.objects.filter(pk__in=item_ids).only('id', 'price'):
            prices[inv_item.id] = inv_item.price

    sales_amount = Decimal('0')
    for med in newly_dispensed_items:
        if med.item_id and med.item_id in prices:
            sales_amount += prices[med.item_id] * Decimal(str(med.quantity))

    if sales_amount <= 0:
        return

    commission_amount = (sales_amount * prescriber.commission_rate / Decimal('100')).quantize(
        Decimal('0.01')
    )

    PrescriberCommission.objects.create(
        prescriber        = prescriber,
        prescription      = rx,
        patient_name      = rx.customer_name,
        sales_amount      = sales_amount,
        commission_rate   = prescriber.commission_rate,
        commission_amount = commission_amount,
        status            = 'pending',
    )


def _create_consultation_payout_for_dispense(rx):
    """
    Called inside dispense_prescription's atomic block.
    Records the prescription's silent consultation fee as a payout owed to the
    prescriber. Created at most once per prescription (OneToOne), the first time
    it is dispensed. Skips if: no prescriber, no consultation fee, already exists.
    """
    if not rx.prescriber_id:
        return
    if not rx.consultation_fee or rx.consultation_fee <= 0:
        return
    ConsultationPayout.objects.get_or_create(
        prescription=rx,
        defaults={
            'prescriber':            rx.prescriber,
            'patient_name':          rx.customer_name,
            'consultation_category': rx.consultation_category or '',
            'consultation_fee':      rx.consultation_fee,
            'status':                'pending',
        },
    )


@api_view(['POST'])
@permission_classes([AllowAny])
def prescriber_portal_create_rx(request):
    """
    POST /api/prescriptions/portal/
    Authenticated via 'Authorization: Bearer <prescriber_signed_token>' header.
    Body: { customer, diagnosis?, notes?, items: [{item_name, quantity, unit, dosage?, duration?, instructions?}] }
    """
    token = (request.META.get('HTTP_X_PRESCRIBER_TOKEN') or '').strip()
    prescriber = _verify_prescriber_token(token) if token else None
    if prescriber is None:
        return Response({'detail': 'Invalid or missing prescriber token.'},
                        status=status.HTTP_401_UNAUTHORIZED)

    data = request.data
    customer_id = data.get('customer')
    if not customer_id:
        return Response({'detail': 'customer is required'}, status=status.HTTP_400_BAD_REQUEST)

    from customers.models import Customer
    try:
        customer = Customer.objects.get(pk=customer_id)
    except Customer.DoesNotExist:
        return Response({'detail': 'Customer not found'}, status=status.HTTP_404_NOT_FOUND)

    items_data = data.get('items') or []
    if not items_data:
        return Response({'detail': 'At least one medication is required'},
                        status=status.HTTP_400_BAD_REQUEST)

    # Resolve org: prescriber's own org first, fall back to customer's org.
    # Prescribers created by a pharmacy admin have organization set to that pharmacy.
    org_for_rx = prescriber.organization or customer.organization

    consult_category, consult_fee = _resolve_consultation(prescriber, data)

    with transaction.atomic():
        rx = Prescription.objects.create(
            organization   = org_for_rx,
            prescriber     = prescriber,
            doctor_name    = prescriber.name,
            customer       = customer,
            customer_name  = customer.name,
            customer_phone = customer.phone,
            diagnosis      = (data.get('diagnosis') or '').strip(),
            notes          = (data.get('notes') or '').strip(),
            consultation_category = consult_category,
            consultation_fee      = consult_fee,
            status         = 'pending',
            source         = 'portal',
        )
        for item in items_data:
            item_name = (item.get('item_name') or '').strip()
            if not item_name:
                continue
            brand   = (item.get('brand') or '').strip()
            # Resolve inventory FK so commission calculation can look up prices.
            item_id = None
            if org_for_rx:
                item_id = _resolve_item(org_for_rx, item_name, brand)
            PrescriptionItem.objects.create(
                prescription = rx,
                item_id      = item_id,
                item_name    = item_name,
                brand        = brand,
                quantity     = float(item.get('quantity', 1)),
                unit         = (item.get('unit') or 'unit(s)').strip(),
                dosage       = (item.get('dosage') or '').strip(),
                duration     = (item.get('duration') or '').strip(),
                instructions = (item.get('instructions') or '').strip(),
            )

    return Response(rx.to_api_dict(), status=status.HTTP_201_CREATED)


# ── Commission endpoints ──────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([AllowAny])
def prescriber_commissions(request, pk):
    """
    GET /api/prescriptions/prescribers/<pk>/commissions/
    Pharmacy staff (IsAuthenticated) or prescriber portal token both accepted.
    ?status=pending|paid
    """
    try:
        prescriber = Prescriber.objects.get(pk=pk)
    except Prescriber.DoesNotExist:
        return Response({'detail': 'Prescriber not found'}, status=status.HTTP_404_NOT_FOUND)

    if not request.user.is_authenticated and not _portal_token_owner(request, prescriber):
        return Response({'detail': 'Authentication required.'}, status=status.HTTP_401_UNAUTHORIZED)

    qs = PrescriberCommission.objects.filter(prescriber=prescriber).select_related('prescriber')

    status_filter = request.query_params.get('status', '').strip()
    if status_filter in ('pending', 'paid'):
        qs = qs.filter(status=status_filter)

    page_size = 50
    try:
        page = max(1, int(request.query_params.get('page', '1')))
    except (ValueError, TypeError):
        page = 1
    total  = qs.count()
    offset = (page - 1) * page_size

    return Response({
        'count':   total,
        'results': [c.to_api_dict() for c in qs[offset:offset + page_size]],
    })


@api_view(['GET'])
@permission_classes([AllowAny])
def prescriber_commission_summary(request, pk):
    """
    GET /api/prescriptions/prescribers/<pk>/commissions/summary/
    Returns aggregate totals: total_earned, pending_amount, paid_amount,
    pending_count, paid_count, total_prescriptions.
    """
    try:
        prescriber = Prescriber.objects.get(pk=pk)
    except Prescriber.DoesNotExist:
        return Response({'detail': 'Prescriber not found'}, status=status.HTTP_404_NOT_FOUND)

    if not request.user.is_authenticated and not _portal_token_owner(request, prescriber):
        return Response({'detail': 'Authentication required.'}, status=status.HTTP_401_UNAUTHORIZED)

    from django.db.models import Sum
    from decimal import Decimal

    qs = PrescriberCommission.objects.filter(prescriber=prescriber)

    agg = qs.aggregate(
        total_earned=Sum('commission_amount'),
        pending_amount=Sum(
            'commission_amount',
            filter=_m.Q(status='pending'),
        ),
        paid_amount=Sum(
            'commission_amount',
            filter=_m.Q(status='paid'),
        ),
    )

    pending_count = qs.filter(status='pending').count()
    paid_count    = qs.filter(status='paid').count()

    return Response({
        'total_earned':        float(agg['total_earned'] or Decimal('0')),
        'pending_amount':      float(agg['pending_amount'] or Decimal('0')),
        'paid_amount':         float(agg['paid_amount'] or Decimal('0')),
        'pending_count':       pending_count,
        'paid_count':          paid_count,
        'total_prescriptions': qs.values('prescription_id').distinct().count(),
    })


@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def prescriber_commission_mark_paid(request, pk, commission_id):
    """
    PATCH /api/prescriptions/prescribers/<pk>/commissions/<commission_id>/
    Body: { "status": "paid" }
    Restricted to PRESCRIPTIONS_WRITE roles (pharmacy admin / manager).
    """
    if not request.user.is_superuser and request.user.role not in PRESCRIPTIONS_WRITE:
        return Response({'detail': 'Permission denied.'}, status=status.HTTP_403_FORBIDDEN)

    try:
        commission = PrescriberCommission.objects.select_related('prescriber').get(
            pk=commission_id, prescriber_id=pk
        )
    except PrescriberCommission.DoesNotExist:
        return Response({'detail': 'Commission record not found.'}, status=status.HTTP_404_NOT_FOUND)

    new_status = (request.data.get('status') or '').strip()
    if new_status not in ('pending', 'paid'):
        return Response(
            {'detail': 'status must be "pending" or "paid"'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    commission.status = new_status
    if new_status == 'paid' and not commission.paid_at:
        commission.paid_at = timezone.now()
    elif new_status == 'pending':
        commission.paid_at = None
    commission.save()

    log_activity(
        request,
        action='Commission Paid Out',
        category='customers',
        description=(
            f'Commission #{commission.id} for {commission.prescriber.name} '
            f'(NGN {commission.commission_amount}) marked as {new_status}'
        ),
    )
    return Response(commission.to_api_dict())


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def prescriber_commission_pay_all(request, pk):
    """
    POST /api/prescriptions/prescribers/<pk>/commissions/pay-all/
    Marks ALL pending commissions for this prescriber as paid in a single call.
    Restricted to PRESCRIPTIONS_WRITE roles.
    Returns { "paid_count": N, "total_amount": X }.
    """
    if not request.user.is_superuser and request.user.role not in PRESCRIPTIONS_WRITE:
        return Response({'detail': 'Permission denied.'}, status=status.HTTP_403_FORBIDDEN)

    try:
        prescriber = Prescriber.objects.get(pk=pk)
    except Prescriber.DoesNotExist:
        return Response({'detail': 'Prescriber not found.'}, status=status.HTTP_404_NOT_FOUND)

    from django.db.models import Sum
    from decimal import Decimal

    now = timezone.now()
    pending_qs = PrescriberCommission.objects.filter(prescriber=prescriber, status='pending')
    agg = pending_qs.aggregate(total=Sum('commission_amount'))
    total_amount = float(agg['total'] or Decimal('0'))
    paid_count   = pending_qs.update(status='paid', paid_at=now)

    log_activity(
        request,
        action='Commission Bulk Pay Out',
        category='customers',
        description=(
            f'Marked {paid_count} pending commission(s) as paid for {prescriber.name} '
            f'(NGN {total_amount})'
        ),
    )
    return Response({'paid_count': paid_count, 'total_amount': total_amount})


# ── Consultation-fee payout endpoints ─────────────────────────────────────────

def _send_prescriber_sms(prescriber, message: str) -> bool:
    """
    Best-effort SMS to a prescriber's phone. Returns True if sent (or logged in
    the no-provider dev fallback), False if the provider rejected/was unreachable.
    Mirrors pos.views.send_sms — no exception propagates.
    """
    import logging
    logger = logging.getLogger('pharmapp.sms')

    phone = (prescriber.phone or '').strip()
    if not phone:
        logger.info('Consultation notify: prescriber %s has no phone', prescriber.id)
        return False

    # Normalize to international format (Nigeria: 0XXXXXXXXXX → +234XXXXXXXXXX)
    if phone.startswith('0') and len(phone) == 11:
        phone = '+234' + phone[1:]
    elif not phone.startswith('+'):
        phone = '+234' + phone

    from django.conf import settings as djsettings
    sms_url = getattr(djsettings, 'SMS_PROVIDER_URL', None)
    sms_key = getattr(djsettings, 'SMS_API_KEY', None)
    sender  = getattr(djsettings, 'SMS_SENDER_ID', 'PharmApp')

    if sms_url and sms_key:
        import requests as _requests
        try:
            resp = _requests.post(sms_url, json={
                'to':      phone,
                'from':    sender,
                'sms':     message,
                'type':    'plain',
                'api_key': sms_key,
                'channel': 'generic',
            }, timeout=10)
            if resp.status_code not in (200, 201):
                logger.warning('Consultation SMS failed: %s %s', resp.status_code, resp.text)
                return False
        except Exception as exc:
            logger.error('Consultation SMS exception: %s', exc)
            return False
    else:
        logger.info('Consultation SMS (no provider) → %s: %s', phone, message)
    return True


def _notify_consultation_total(prescriber, recipients=None):
    """
    Notify the prescriber (SMS) and the org-admin (in-app Notification) of the
    current consultation-payout totals. Best-effort — never raises.
    Returns the recipients actually delivered to, e.g. ['prescriber', 'admin'].
    """
    from django.db.models import Sum
    from decimal import Decimal
    from pos.models import Notification
    from authapp.models import PharmUser

    recipients = recipients or ['prescriber', 'admin']
    delivered = []

    qs = ConsultationPayout.objects.filter(prescriber=prescriber)
    agg = qs.aggregate(
        total=Sum('consultation_fee'),
        paid=Sum('consultation_fee', filter=_m.Q(status='paid')),
        pending=Sum('consultation_fee', filter=_m.Q(status='pending')),
    )
    total   = float(agg['total']   or Decimal('0'))
    paid    = float(agg['paid']    or Decimal('0'))
    pending = float(agg['pending'] or Decimal('0'))

    msg = (
        f'Consultation fees for Dr. {prescriber.name}: '
        f'NGN {total:,.2f} total · NGN {paid:,.2f} paid · NGN {pending:,.2f} pending.'
    )

    # SMS the prescriber
    if 'prescriber' in recipients:
        if _send_prescriber_sms(prescriber, msg):
            delivered.append('prescriber')

    # In-app notification to the linked pharmacy's admins
    if 'admin' in recipients and prescriber.organization_id:
        admins = PharmUser.objects.filter(
            organization_id=prescriber.organization_id,
            role='Admin',
            is_active=True,
        )
        created_any = False
        for admin_user in admins:
            Notification.objects.create(
                user=admin_user,
                notif_type='system',
                priority='medium',
                title=f'Consultation payout — Dr. {prescriber.name}',
                message=msg[:200],
            )
            created_any = True
        if created_any:
            delivered.append('admin')

    return delivered


@api_view(['GET'])
@permission_classes([AllowAny])
def prescriber_consultations(request, pk):
    """
    GET /api/prescriptions/prescribers/<pk>/consultations/
    Pharmacy staff (IsAuthenticated) or prescriber portal token both accepted.
    ?status=pending|paid
    """
    try:
        prescriber = Prescriber.objects.get(pk=pk)
    except Prescriber.DoesNotExist:
        return Response({'detail': 'Prescriber not found'}, status=status.HTTP_404_NOT_FOUND)

    if not request.user.is_authenticated and not _portal_token_owner(request, prescriber):
        return Response({'detail': 'Authentication required.'}, status=status.HTTP_401_UNAUTHORIZED)

    qs = ConsultationPayout.objects.filter(prescriber=prescriber).select_related('prescriber')

    status_filter = request.query_params.get('status', '').strip()
    if status_filter in ('pending', 'paid'):
        qs = qs.filter(status=status_filter)

    page_size = 50
    try:
        page = max(1, int(request.query_params.get('page', '1')))
    except (ValueError, TypeError):
        page = 1
    total  = qs.count()
    offset = (page - 1) * page_size

    return Response({
        'count':   total,
        'results': [c.to_api_dict() for c in qs[offset:offset + page_size]],
    })


@api_view(['GET'])
@permission_classes([AllowAny])
def prescriber_consultation_summary(request, pk):
    """
    GET /api/prescriptions/prescribers/<pk>/consultations/summary/
    Returns: total_collected, pending_amount, paid_amount,
    pending_count, paid_count, total_consultations.
    """
    try:
        prescriber = Prescriber.objects.get(pk=pk)
    except Prescriber.DoesNotExist:
        return Response({'detail': 'Prescriber not found'}, status=status.HTTP_404_NOT_FOUND)

    if not request.user.is_authenticated and not _portal_token_owner(request, prescriber):
        return Response({'detail': 'Authentication required.'}, status=status.HTTP_401_UNAUTHORIZED)

    from django.db.models import Sum
    from decimal import Decimal

    qs = ConsultationPayout.objects.filter(prescriber=prescriber)
    agg = qs.aggregate(
        total_collected=Sum('consultation_fee'),
        pending_amount=Sum('consultation_fee', filter=_m.Q(status='pending')),
        paid_amount=Sum('consultation_fee', filter=_m.Q(status='paid')),
    )

    return Response({
        'total_collected':     float(agg['total_collected'] or Decimal('0')),
        'pending_amount':      float(agg['pending_amount']  or Decimal('0')),
        'paid_amount':         float(agg['paid_amount']     or Decimal('0')),
        'pending_count':       qs.filter(status='pending').count(),
        'paid_count':          qs.filter(status='paid').count(),
        'total_consultations': qs.count(),
    })


@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def prescriber_consultation_mark_paid(request, pk, payout_id):
    """
    PATCH /api/prescriptions/prescribers/<pk>/consultations/<payout_id>/
    Body: { "status": "paid" }
    Restricted to PRESCRIPTIONS_WRITE roles (pharmacy admin / manager).
    """
    if not request.user.is_superuser and request.user.role not in PRESCRIPTIONS_WRITE:
        return Response({'detail': 'Permission denied.'}, status=status.HTTP_403_FORBIDDEN)

    try:
        payout = ConsultationPayout.objects.select_related('prescriber').get(
            pk=payout_id, prescriber_id=pk
        )
    except ConsultationPayout.DoesNotExist:
        return Response({'detail': 'Consultation payout not found.'}, status=status.HTTP_404_NOT_FOUND)

    new_status = (request.data.get('status') or '').strip()
    if new_status not in ('pending', 'paid'):
        return Response(
            {'detail': 'status must be "pending" or "paid"'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    payout.status = new_status
    if new_status == 'paid' and not payout.paid_at:
        payout.paid_at = timezone.now()
    elif new_status == 'pending':
        payout.paid_at = None
    payout.save()

    log_activity(
        request,
        action='Consultation Fee Paid Out',
        category='customers',
        description=(
            f'Consultation payout #{payout.id} for {payout.prescriber.name} '
            f'(NGN {payout.consultation_fee}) marked as {new_status}'
        ),
    )
    return Response(payout.to_api_dict())


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def prescriber_consultation_pay_all(request, pk):
    """
    POST /api/prescriptions/prescribers/<pk>/consultations/pay-all/
    Marks ALL pending consultation payouts for this prescriber as paid, then
    notifies the prescriber (SMS) + org-admin (in-app) of the total.
    Restricted to PRESCRIPTIONS_WRITE roles.
    Returns { "paid_count": N, "total_amount": X, "notified": [...] }.
    """
    if not request.user.is_superuser and request.user.role not in PRESCRIPTIONS_WRITE:
        return Response({'detail': 'Permission denied.'}, status=status.HTTP_403_FORBIDDEN)

    try:
        prescriber = Prescriber.objects.get(pk=pk)
    except Prescriber.DoesNotExist:
        return Response({'detail': 'Prescriber not found.'}, status=status.HTTP_404_NOT_FOUND)

    from django.db.models import Sum
    from decimal import Decimal

    now = timezone.now()
    pending_qs   = ConsultationPayout.objects.filter(prescriber=prescriber, status='pending')
    agg          = pending_qs.aggregate(total=Sum('consultation_fee'))
    total_amount = float(agg['total'] or Decimal('0'))
    paid_count   = pending_qs.update(status='paid', paid_at=now)

    notified = _notify_consultation_total(prescriber)

    log_activity(
        request,
        action='Consultation Fee Bulk Pay Out',
        category='customers',
        description=(
            f'Marked {paid_count} pending consultation payout(s) as paid for '
            f'{prescriber.name} (NGN {total_amount})'
        ),
    )
    return Response({
        'paid_count':   paid_count,
        'total_amount': total_amount,
        'notified':     notified,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def prescriber_consultation_notify(request, pk):
    """
    POST /api/prescriptions/prescribers/<pk>/consultations/notify/
    Body (optional): { "recipients": ["prescriber", "admin"] }
    Sends the current consultation-fee total to the prescriber (SMS) and the
    org-admin (in-app) WITHOUT changing any payout status.
    Restricted to PRESCRIPTIONS_WRITE roles.
    Returns { "notified": [...] }.
    """
    if not request.user.is_superuser and request.user.role not in PRESCRIPTIONS_WRITE:
        return Response({'detail': 'Permission denied.'}, status=status.HTTP_403_FORBIDDEN)

    try:
        prescriber = Prescriber.objects.get(pk=pk)
    except Prescriber.DoesNotExist:
        return Response({'detail': 'Prescriber not found.'}, status=status.HTTP_404_NOT_FOUND)

    recipients = request.data.get('recipients') or ['prescriber', 'admin']
    if not isinstance(recipients, list):
        recipients = ['prescriber', 'admin']

    notified = _notify_consultation_total(prescriber, recipients=recipients)

    log_activity(
        request,
        action='Consultation Total Notified',
        category='customers',
        description=f'Notified {", ".join(notified) or "nobody"} of consultation total for {prescriber.name}',
    )
    return Response({'notified': notified})
