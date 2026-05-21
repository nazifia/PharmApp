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

from authapp.utils import require_org, log_activity
from authapp.permissions import IsPrescriptionUser, PRESCRIPTIONS_WRITE
from authapp.models import PharmacyNetworkMembership
from .models import Prescription, PrescriptionItem, Prescriber, Hospital


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

        # Network-wide view: order by branch name so grouped display works cleanly.
        # Branch-scoped view: use default -created_at ordering from Meta.
        if network_wide or not branch_filtered:
            qs = qs.order_by(
                F('branch__name').asc(nulls_last=True),
                '-created_at',
            )

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
                    rx.prescriber = Prescriber.objects.get(pk=pid, organization=org)
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
              .select_related('organization', 'created_by', 'branch')
              .prefetch_related('medications')
              .get(pk=pk, organization=org))
    except Prescription.DoesNotExist:
        # Allow network peer orgs and any pharmacy to dispense portal Rxs.
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

    log_activity(
        request,
        action='Dispense Prescription',
        category='customers',
        description=f'Dispensed medications on Rx#{pk} for "{rx.customer_name}"',
    )

    # Return fresh data — use pk only (org already verified above)
    rx = (Prescription.objects
          .select_related('organization', 'created_by', 'branch')
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

    return Response([rx.to_api_dict() for rx in qs])


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
    prescriber = Prescriber.objects.create(
        organization_id = creator_org,
        hospital       = hospital,
        name           = name,
        license_number = (request.data.get('license_number') or '').strip(),
        specialty      = (request.data.get('specialty') or '').strip(),
        phone          = (request.data.get('phone') or '').strip(),
        address        = (request.data.get('address') or '').strip(),
    )
    log_activity(
        request,
        action='Add Prescriber',
        category='customers',
        description=f'Prescriber "{prescriber.name}" registered',
    )
    return Response(prescriber.to_api_dict(), status=status.HTTP_201_CREATED)


@api_view(['GET', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated])
def prescriber_detail(request, pk):
    """
    GET    /api/prescriptions/prescribers/<pk>/
    PATCH  /api/prescriptions/prescribers/<pk>/
    DELETE /api/prescriptions/prescribers/<pk>/
    Global — any authenticated user can read; write requires PRESCRIPTIONS_WRITE role.
    """
    try:
        prescriber = Prescriber.objects.select_related('hospital').get(pk=pk)
    except Prescriber.DoesNotExist:
        return Response({'detail': 'Prescriber not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
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
            status         = 'pending',
            source         = 'portal',
        )
        for item in items_data:
            item_name = (item.get('item_name') or '').strip()
            if not item_name:
                continue
            PrescriptionItem.objects.create(
                prescription = rx,
                item_name    = item_name,
                quantity     = float(item.get('quantity', 1)),
                unit         = (item.get('unit') or 'unit(s)').strip(),
                dosage       = (item.get('dosage') or '').strip(),
                duration     = (item.get('duration') or '').strip(),
                instructions = (item.get('instructions') or '').strip(),
            )

    return Response(rx.to_api_dict(), status=status.HTTP_201_CREATED)
