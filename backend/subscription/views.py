from datetime import timedelta

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from authapp.models import Organization
from authapp.utils import require_org
from .models import Subscription, SubscriptionEvent

# ── Plan upgrade constraints ───────────────────────────────────────────────────

VALID_PLANS = {'starter', 'professional', 'enterprise'}

ADMIN_ROLES = {'Admin', 'Manager'}


def _require_admin(request):
    if request.user.role not in ADMIN_ROLES:
        return Response(
            {'detail': 'Only Admin or Manager can manage subscriptions.'},
            status=status.HTTP_403_FORBIDDEN,
        )
    return None


# ── GET /api/subscription/ ────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def subscription_detail(request):
    """
    Return the current subscription for the authenticated user's organization.
    Creates a default trial if one doesn't exist yet.
    """
    org, err = require_org(request)
    if err:
        return err

    sub = Subscription.get_or_create_trial(org)
    return Response(sub.to_api_dict())


# ── POST /api/subscription/upgrade/ ──────────────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def subscription_upgrade(request):
    """
    Request a plan upgrade.
    Body: { "plan_id": "starter" | "professional" | "enterprise" }

    In production this should redirect to a payment gateway. For now it sets the
    plan directly (simulating a completed payment) and returns a placeholder
    checkout_url so the Flutter app has something to act on.
    """
    err = _require_admin(request)
    if err:
        return err

    org, err = require_org(request)
    if err:
        return err

    plan_id = (request.data.get('plan_id') or '').strip().lower()
    if plan_id not in VALID_PLANS:
        return Response(
            {'detail': f"Invalid plan_id. Choose from: {', '.join(sorted(VALID_PLANS))}"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    sub = Subscription.get_or_create_trial(org)

    # ── Payment integration hook ───────────────────────────────────────────────
    # In production, create a checkout session with your payment provider and
    # return the URL. For now we activate directly (sandbox / manual billing).
    sub.plan   = plan_id
    sub.status = 'active'
    sub.trial_ends_at = None
    sub.save()

    # Return a placeholder checkout URL (replace with real Stripe/Paystack URL)
    checkout_url = ''   # e.g. stripe_session.url
    return Response({
        'detail':       f"Plan upgraded to {plan_id}.",
        'plan':         sub.plan,
        'status':       sub.status,
        'checkout_url': checkout_url,
    }, status=status.HTTP_200_OK)


# ── POST /api/subscription/cancel/ ───────────────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def subscription_cancel(request):
    """Cancel the current subscription (Admin only)."""
    err = _require_admin(request)
    if err:
        return err

    org, err = require_org(request)
    if err:
        return err

    sub = Subscription.get_or_create_trial(org)
    sub.status = 'cancelled'
    sub.save(update_fields=['status', 'updated_at'])

    return Response({'detail': 'Subscription cancelled.'})


# ── Superuser helpers ─────────────────────────────────────────────────────────

def _require_superuser(request):
    if not request.user.is_superuser:
        return Response(
            {'detail': 'Superuser access required.'},
            status=status.HTTP_403_FORBIDDEN,
        )
    return None


def _org_to_superuser_dict(org):
    """Serialize an Organization + its Subscription for the superuser API."""
    try:
        sub = org.subscription
    except Subscription.DoesNotExist:
        sub = Subscription.get_or_create_trial(org)

    sub.refresh_status()
    usage = sub._usage()

    custom_limits = None
    if any(v is not None for v in [
        sub.custom_max_users, sub.custom_max_items,
        sub.custom_max_transactions, sub.custom_max_branches,
    ]):
        from .models import PLAN_LIMITS
        plan_limits = PLAN_LIMITS.get(sub.plan, {})
        custom_limits = {
            'max_users':
                sub.custom_max_users if sub.custom_max_users is not None
                else plan_limits.get('users', -1),
            'max_items':
                sub.custom_max_items if sub.custom_max_items is not None
                else plan_limits.get('items', -1),
            'max_transactions_per_month':
                sub.custom_max_transactions if sub.custom_max_transactions is not None
                else plan_limits.get('transactions', -1),
            'max_branches':
                sub.custom_max_branches if sub.custom_max_branches is not None else 1,
        }

    return {
        'id':                org.id,
        'name':              org.name,
        'slug':              org.slug,
        'phone':             getattr(org, 'phone', ''),
        'plan':              sub.plan,
        'status':            sub.status,
        'billing_cycle':     sub.billing_cycle,
        'trial_ends_at':     sub.trial_ends_at.isoformat() if sub.trial_ends_at else None,
        'current_period_end': sub.current_period_end.isoformat() if sub.current_period_end else None,
        'extra_features':    list(sub.extra_features or []),
        'removed_features':  list(sub.removed_features or []),
        'custom_limits':     custom_limits,
        'usage':             usage,
        'user_count':        org.users.filter(is_active=True).count(),
    }


# ── GET /api/superuser/organizations/ ────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def superuser_org_list(request):
    """List all organizations with their subscription info. Superuser only."""
    err = _require_superuser(request)
    if err:
        return err

    orgs = Organization.objects.prefetch_related('users').select_related('subscription').all()
    return Response([_org_to_superuser_dict(org) for org in orgs])


# ── GET /api/superuser/organizations/{id}/ ───────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def superuser_org_detail(request, org_id):
    """Get one organization's subscription detail. Superuser only."""
    err = _require_superuser(request)
    if err:
        return err

    try:
        org = Organization.objects.get(id=org_id)
    except Organization.DoesNotExist:
        return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

    return Response(_org_to_superuser_dict(org))


# ── PATCH /api/superuser/organizations/{id}/subscription/ ────────────────────

VALID_PLANS_ALL = {'trial', 'starter', 'professional', 'enterprise'}
VALID_STATUSES  = {'trial', 'expiring', 'expired', 'active', 'suspended', 'cancelled'}
VALID_FEATURES  = {
    'pos', 'inventory', 'customers', 'user_management', 'basic_reports',
    'advanced_reports', 'wholesale', 'export_data', 'multi_branch',
    'api_access', 'priority_support', 'white_label',
}

@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def superuser_update_subscription(request, org_id):
    """
    Override subscription fields for one org. Superuser only.
    Accepted body fields (all optional):
      plan, status, billing_cycle, trial_ends_at,
      extra_features, removed_features, custom_limits
    """
    err = _require_superuser(request)
    if err:
        return err

    try:
        org = Organization.objects.get(id=org_id)
    except Organization.DoesNotExist:
        return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

    sub = Subscription.get_or_create_trial(org)
    data = request.data
    changed = []

    if 'plan' in data:
        new_plan = data['plan']
        if new_plan not in VALID_PLANS_ALL:
            return Response({'detail': f'Invalid plan: {new_plan}'}, status=400)
        if new_plan != sub.plan:
            SubscriptionEvent.objects.create(
                subscription=sub, event_type='plan_changed',
                old_value=sub.plan, new_value=new_plan,
                performed_by=request.user.phone_number,
                note='Changed via Flutter superuser panel',
            )
            sub.plan = new_plan
            changed.append('plan')

    if 'status' in data:
        new_status = data['status']
        if new_status not in VALID_STATUSES:
            return Response({'detail': f'Invalid status: {new_status}'}, status=400)
        if new_status != sub.status:
            SubscriptionEvent.objects.create(
                subscription=sub, event_type='status_changed',
                old_value=sub.status, new_value=new_status,
                performed_by=request.user.phone_number,
                note='Changed via Flutter superuser panel',
            )
            sub.status = new_status
            changed.append('status')

    if 'billing_cycle' in data:
        bc = data['billing_cycle']
        if bc in ('monthly', 'annual'):
            sub.billing_cycle = bc
            changed.append('billing_cycle')

    if 'trial_ends_at' in data:
        from django.utils.dateparse import parse_datetime
        val = data['trial_ends_at']
        sub.trial_ends_at = parse_datetime(val) if val else None
        changed.append('trial_ends_at')

    if 'extra_features' in data:
        features = data['extra_features']
        if not isinstance(features, list):
            return Response({'detail': 'extra_features must be a list'}, status=400)
        invalid = [f for f in features if f not in VALID_FEATURES]
        if invalid:
            return Response({'detail': f'Invalid feature keys: {invalid}'}, status=400)
        sub.extra_features = list(set(features))
        changed.append('extra_features')

    if 'removed_features' in data:
        features = data['removed_features']
        if not isinstance(features, list):
            return Response({'detail': 'removed_features must be a list'}, status=400)
        invalid = [f for f in features if f not in VALID_FEATURES]
        if invalid:
            return Response({'detail': f'Invalid feature keys: {invalid}'}, status=400)
        sub.removed_features = list(set(features))
        changed.append('removed_features')

    if 'custom_limits' in data:
        cl = data['custom_limits']
        if cl is None:
            sub.custom_max_users        = None
            sub.custom_max_items        = None
            sub.custom_max_transactions = None
            sub.custom_max_branches     = None
        else:
            if 'max_users' in cl:
                sub.custom_max_users = cl['max_users']
            if 'max_items' in cl:
                sub.custom_max_items = cl['max_items']
            if 'max_transactions_per_month' in cl:
                sub.custom_max_transactions = cl['max_transactions_per_month']
            if 'max_branches' in cl:
                sub.custom_max_branches = cl['max_branches']
        changed.append('custom_limits')

    if changed and any(f in changed for f in ('extra_features', 'removed_features', 'custom_limits')):
        SubscriptionEvent.objects.create(
            subscription=sub, event_type='note',
            old_value='', new_value='feature/limit override updated',
            performed_by=request.user.phone_number,
            note=f"Fields changed: {', '.join(changed)}",
        )

    sub.save()
    return Response(_org_to_superuser_dict(org))


# ── POST /api/superuser/organizations/{id}/extend-trial/ ─────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def superuser_extend_trial(request, org_id):
    """Extend trial by N days from now (or from current trial_ends_at)."""
    err = _require_superuser(request)
    if err:
        return err

    try:
        org = Organization.objects.get(id=org_id)
    except Organization.DoesNotExist:
        return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

    days = int(request.data.get('days', 14))
    if not (1 <= days <= 365):
        return Response({'detail': 'days must be between 1 and 365.'}, status=400)

    sub  = Subscription.get_or_create_trial(org)
    from django.utils import timezone
    base = max(sub.trial_ends_at or timezone.now(), timezone.now())
    old_end = str(sub.trial_ends_at)[:16] if sub.trial_ends_at else '—'
    sub.trial_ends_at = base + timedelta(days=days)
    sub.plan   = 'trial'
    if sub.status in ('expired', 'cancelled'):
        sub.status = 'trial'
    sub.save()

    SubscriptionEvent.objects.create(
        subscription=sub, event_type='trial_extended',
        old_value=old_end,
        new_value=str(sub.trial_ends_at)[:16],
        performed_by=request.user.phone_number,
        note=f'+{days} days via Flutter superuser panel',
    )

    return Response(_org_to_superuser_dict(org))


# ── POST /api/superuser/organizations/{id}/reset-subscription/ ───────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def superuser_reset_subscription(request, org_id):
    """Reset all overrides (extra_features, removed_features, custom_limits) to defaults."""
    err = _require_superuser(request)
    if err:
        return err

    try:
        org = Organization.objects.get(id=org_id)
    except Organization.DoesNotExist:
        return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

    sub = Subscription.get_or_create_trial(org)
    sub.extra_features          = []
    sub.removed_features        = []
    sub.custom_max_users        = None
    sub.custom_max_items        = None
    sub.custom_max_transactions = None
    sub.custom_max_branches     = None
    sub.save()

    SubscriptionEvent.objects.create(
        subscription=sub, event_type='note',
        old_value='', new_value='overrides reset',
        performed_by=request.user.phone_number,
        note='All feature & limit overrides cleared via Flutter superuser panel',
    )

    return Response(_org_to_superuser_dict(org))
