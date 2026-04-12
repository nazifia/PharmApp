from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from authapp.utils import require_org
from subscription.models import Subscription, PLAN_LIMITS
from .models import Branch

ADMIN_ROLES = {'Admin', 'Manager'}


def _require_admin(request):
    if request.user.role not in ADMIN_ROLES:
        return Response(
            {'detail': 'Only Admin or Manager can manage branches.'},
            status=status.HTTP_403_FORBIDDEN,
        )
    return None


def _branch_limit(org):
    """
    Returns the max number of branches allowed for the org's current plan.
    -1 means unlimited.
    """
    try:
        sub = org.subscription
        sub.refresh_status()
        # Respect custom override if set
        if sub.custom_max_branches is not None:
            return sub.custom_max_branches
        plan_limits = {
            'trial':        1,
            'starter':      1,
            'professional': 3,
            'enterprise':   -1,
        }
        return plan_limits.get(sub.plan, 1)
    except Subscription.DoesNotExist:
        return 1


# ── GET /api/branches/ ───────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def branch_list(request):
    """List all active branches for the authenticated org."""
    org, err = require_org(request)
    if err:
        return err

    branches = Branch.objects.filter(organization=org, is_active=True)
    return Response([b.to_api_dict() for b in branches])


# ── POST /api/branches/ ──────────────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def branch_create(request):
    """
    Create a new branch. Admin/Manager only.
    Enforces the plan's branch limit.
    """
    err = _require_admin(request)
    if err:
        return err

    org, err = require_org(request)
    if err:
        return err

    # Check plan limit
    limit = _branch_limit(org)
    current_count = Branch.objects.filter(organization=org, is_active=True).count()
    if limit != -1 and current_count >= limit:
        return Response(
            {
                'detail': (
                    f'Your plan allows a maximum of {limit} branch'
                    f'{"" if limit == 1 else "es"}. '
                    'Upgrade to Professional or Enterprise to add more.'
                ),
                'limit_reached': True,
                'current_count': current_count,
                'max_branches':  limit,
            },
            status=status.HTTP_403_FORBIDDEN,
        )

    name    = (request.data.get('name') or '').strip()
    address = (request.data.get('address') or '').strip()
    phone   = (request.data.get('phone') or '').strip()
    email   = (request.data.get('email') or '').strip()

    if not name:
        return Response({'detail': 'Branch name is required.'}, status=status.HTTP_400_BAD_REQUEST)

    if Branch.objects.filter(organization=org, name=name).exists():
        return Response(
            {'detail': f'A branch named "{name}" already exists.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # First branch for this org is automatically the main branch
    is_main = not Branch.objects.filter(organization=org).exists()

    branch = Branch.objects.create(
        organization=org,
        name=name,
        address=address,
        phone=phone,
        email=email,
        is_main=is_main,
    )
    return Response(branch.to_api_dict(), status=status.HTTP_201_CREATED)


# ── GET /api/branches/{id}/ ──────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def branch_detail(request, branch_id):
    """Get a single branch by id (must belong to the caller's org)."""
    org, err = require_org(request)
    if err:
        return err

    try:
        branch = Branch.objects.get(pk=branch_id, organization=org)
    except Branch.DoesNotExist:
        return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

    return Response(branch.to_api_dict())


# ── PATCH /api/branches/{id}/ ────────────────────────────────────────────────

@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def branch_update(request, branch_id):
    """Update branch details. Admin/Manager only."""
    err = _require_admin(request)
    if err:
        return err

    org, err = require_org(request)
    if err:
        return err

    try:
        branch = Branch.objects.get(pk=branch_id, organization=org)
    except Branch.DoesNotExist:
        return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

    data    = request.data
    changed = []

    if 'name' in data:
        new_name = (data['name'] or '').strip()
        if not new_name:
            return Response({'detail': 'Name cannot be blank.'}, status=400)
        if (Branch.objects.filter(organization=org, name=new_name)
                          .exclude(pk=branch_id).exists()):
            return Response({'detail': f'A branch named "{new_name}" already exists.'}, status=400)
        branch.name = new_name
        changed.append('name')

    for field in ('address', 'phone', 'email'):
        if field in data:
            setattr(branch, field, (data[field] or '').strip())
            changed.append(field)

    if changed:
        branch.save(update_fields=changed + ['updated_at'])

    return Response(branch.to_api_dict())


# ── DELETE /api/branches/{id}/ ───────────────────────────────────────────────

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def branch_deactivate(request, branch_id):
    """
    Deactivate (soft-delete) a branch. Admin/Manager only.
    The main branch cannot be deactivated while other branches exist.
    """
    err = _require_admin(request)
    if err:
        return err

    org, err = require_org(request)
    if err:
        return err

    try:
        branch = Branch.objects.get(pk=branch_id, organization=org)
    except Branch.DoesNotExist:
        return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

    if branch.is_main:
        other_active = Branch.objects.filter(
            organization=org, is_active=True
        ).exclude(pk=branch_id).exists()
        if other_active:
            return Response(
                {'detail': 'Cannot deactivate the main branch while other branches are active. '
                           'Set another branch as main first.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

    branch.is_active = False
    branch.save(update_fields=['is_active', 'updated_at'])
    return Response({'detail': 'Branch deactivated.'})


# ── POST /api/branches/{id}/set-main/ ────────────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def branch_set_main(request, branch_id):
    """Promote a branch to the main/head-office branch. Admin only."""
    err = _require_admin(request)
    if err:
        return err

    org, err = require_org(request)
    if err:
        return err

    try:
        branch = Branch.objects.get(pk=branch_id, organization=org, is_active=True)
    except Branch.DoesNotExist:
        return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

    # Clear existing main flag then set the new one
    Branch.objects.filter(organization=org, is_main=True).update(is_main=False)
    branch.is_main = True
    branch.save(update_fields=['is_main', 'updated_at'])

    return Response(branch.to_api_dict())
