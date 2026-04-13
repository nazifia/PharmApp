from datetime import timedelta

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from authapp.models import Organization
from authapp.utils import require_org
from .models import PaymentAccount, Subscription, SubscriptionEvent

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

    billing_cycle = (request.data.get('billing_cycle') or 'monthly').strip().lower()
    if billing_cycle not in ('monthly', 'annual'):
        billing_cycle = 'monthly'

    sub = Subscription.get_or_create_trial(org)
    old_plan = sub.plan

    # Record the requested plan + billing cycle and set status to pending.
    # A superuser approves in Django admin (changes status to 'active').
    sub.plan          = plan_id
    sub.billing_cycle = billing_cycle
    sub.status        = 'pending'
    sub.trial_ends_at = None
    sub.save()

    SubscriptionEvent.objects.create(
        subscription=sub,
        event_type='plan_changed',
        old_value=old_plan,
        new_value=f"{plan_id}/{billing_cycle}",
        performed_by=request.user.phone_number,
        note=f"Upgrade requested via app — billing cycle: {billing_cycle}. Awaiting admin approval.",
    )

    # checkout_url is empty for manual (bank-transfer) billing.
    # Replace with a real Paystack/Flutterwave session URL when integrating.
    checkout_url = ''
    return Response({
        'detail':       f"Upgrade to {plan_id} ({billing_cycle}) submitted. Awaiting admin approval.",
        'plan':         sub.plan,
        'billing_cycle': sub.billing_cycle,
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
VALID_STATUSES  = {'trial', 'expiring', 'expired', 'active', 'pending', 'suspended', 'cancelled'}

# Hard-coded baseline — extended at runtime with any custom keys in the DB.
_BUILTIN_FEATURES = {
    'pos', 'inventory', 'customers', 'user_management', 'basic_reports',
    'advanced_reports', 'wholesale', 'export_data', 'multi_branch',
    'priority_support',
}


def _valid_features():
    """
    Returns the full set of valid feature keys: the hard-coded baseline plus
    any custom keys that a superuser has added to the PlanFeatureFlag table.
    Falls back to the baseline if the DB query fails (e.g. before migrations).
    """
    from .models import PlanFeatureFlag
    try:
        db_keys = set(
            PlanFeatureFlag.objects.values_list('feature_key', flat=True)
        )
        return _BUILTIN_FEATURES | db_keys
    except Exception:
        return _BUILTIN_FEATURES

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
        invalid = [f for f in features if f not in _valid_features()]
        if invalid:
            return Response({'detail': f'Invalid feature keys: {invalid}'}, status=400)
        sub.extra_features = list(set(features))
        changed.append('extra_features')

    if 'removed_features' in data:
        features = data['removed_features']
        if not isinstance(features, list):
            return Response({'detail': 'removed_features must be a list'}, status=400)
        invalid = [f for f in features if f not in _valid_features()]
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


# ── GET|PATCH /api/superuser/plan-features/ ──────────────────────────────────

@api_view(['GET', 'PATCH'])
@permission_classes([IsAuthenticated])
def superuser_plan_features(request):
    """
    GET  — returns the global plan → feature matrix (same shape as subscription.to_api_dict
           plan_features / feature_labels / feature_order).
    PATCH — updates the matrix from Flutter's PlanFeatureMatrix.toJson() payload:
            { plan_features: {plan: [keys]}, feature_labels: {key: label}, feature_order: [keys] }
    """
    from .models import PlanFeatureFlag, PLAN_CHOICES

    err = _require_superuser(request)
    if err:
        return err

    if request.method == 'GET':
        PlanFeatureFlag.ensure_defaults()
        return Response(PlanFeatureFlag.get_all_features_matrix())

    # ── PATCH ────────────────────────────────────────────────────────────────
    data           = request.data
    plan_features  = data.get('plan_features', {})
    feature_labels = data.get('feature_labels', {})
    feature_order  = data.get('feature_order', [])

    if not isinstance(plan_features, dict):
        return Response({'detail': 'plan_features must be an object.'}, status=400)
    if not isinstance(feature_labels, dict):
        return Response({'detail': 'feature_labels must be an object.'}, status=400)
    if not isinstance(feature_order, list):
        return Response({'detail': 'feature_order must be a list.'}, status=400)

    valid_plans = {p for p, _ in PLAN_CHOICES}

    # All feature keys mentioned anywhere in the payload
    all_keys = set(feature_labels.keys())
    for keys in plan_features.values():
        all_keys.update(keys)
    all_keys.update(feature_order)

    if not all_keys:
        return Response({'detail': 'No feature keys provided.'}, status=400)

    updated = 0
    for key in all_keys:
        label = feature_labels.get(key, key)
        try:
            sort = feature_order.index(key)
        except ValueError:
            sort = 999

        for plan in valid_plans:
            keys_for_plan = set(plan_features.get(plan, []))
            is_enabled    = key in keys_for_plan

            flag, created = PlanFeatureFlag.objects.get_or_create(
                plan=plan,
                feature_key=key,
                defaults={
                    'feature_label': label,
                    'is_enabled':    is_enabled,
                    'sort_order':    sort,
                },
            )
            if not created:
                changed = False
                if flag.feature_label != label:
                    flag.feature_label = label
                    changed = True
                if flag.is_enabled != is_enabled:
                    flag.is_enabled = is_enabled
                    changed = True
                if flag.sort_order != sort:
                    flag.sort_order = sort
                    changed = True
                if changed:
                    flag.save()
                    updated += 1
            else:
                updated += 1

    return Response(PlanFeatureFlag.get_all_features_matrix())


# ── GET /api/subscription/payment-accounts/ ──────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def payment_accounts(request):
    """
    Return all active payment receiving accounts.
    Used by the Flutter upgrade screen to show pharmacy admins
    where to send payment for their subscription.
    """
    accounts = PaymentAccount.objects.filter(is_active=True).order_by('sort_order', 'currency')
    return Response([acc.to_api_dict() for acc in accounts])


# ── GET /api/subscription/billing/ ───────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def billing_info(request):
    """
    Return billing summary for the authenticated org's subscription.
    Includes the platform receiving account so Flutter never shows
    the hardcoded placeholder.
    """
    org, err = require_org(request)
    if err:
        return err

    # Primary receiving account (first active bank-transfer account, else any active)
    account = (
        PaymentAccount.objects
        .filter(is_active=True)
        .order_by('sort_order', 'currency')
        .first()
    )
    platform_account = None
    if account:
        platform_account = {
            'bank_name':      account.bank_name,
            'account_number': account.account_number,
            'account_name':   account.account_name,
            'sort_code':      account.routing_info or None,
            'payment_link':   None,
            'currency':       account.currency,
        }

    return Response({
        'platform_account':    platform_account,
        'invoices':            [],
        'auto_billing_enabled': False,
        'next_payment_date':   None,
        'next_payment_amount': None,
        'payment_method':      None,
        'billing_contact':     None,
    })


# ── GET /api/subscription/billing/receiving-account/ ─────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def billing_receiving_account(request):
    """
    Return the primary platform receiving account (first active record).
    Flutter fetches this separately as a fallback when the billing endpoint
    does not embed `platform_account`.
    """
    account = (
        PaymentAccount.objects
        .filter(is_active=True)
        .order_by('sort_order', 'currency')
        .first()
    )
    if not account:
        return Response(
            {'detail': 'No payment account configured.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    return Response({
        'bank_name':      account.bank_name,
        'account_number': account.account_number,
        'account_name':   account.account_name,
        'sort_code':      account.routing_info or None,
        'payment_link':   None,
        'currency':       account.currency,
    })


# ── GET /api/subscription/superuser/payment-accounts/ ────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def superuser_list_payment_accounts(request):
    """
    Return ALL payment accounts (active and inactive). Superuser only.
    Used by the Flutter superuser screen to manage payment method visibility.
    """
    err = _require_superuser(request)
    if err:
        return err

    accounts = PaymentAccount.objects.order_by('sort_order', 'currency', 'id')
    return Response([_payment_account_full_dict(acc) for acc in accounts])


# ── PATCH /api/subscription/superuser/payment-accounts/{id}/ ─────────────────

@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def superuser_toggle_payment_account(request, account_id):
    """
    Toggle is_active for a single PaymentAccount. Superuser only.
    Body: { "is_active": true | false }
    Returns the updated account.
    """
    err = _require_superuser(request)
    if err:
        return err

    try:
        account = PaymentAccount.objects.get(pk=account_id)
    except PaymentAccount.DoesNotExist:
        return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

    is_active = request.data.get('is_active')
    if not isinstance(is_active, bool):
        return Response(
            {'detail': 'is_active must be a boolean.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    account.is_active   = is_active
    account.updated_by  = request.user.phone_number
    account.save(update_fields=['is_active', 'updated_by', 'updated_at'])
    return Response(_payment_account_full_dict(account))


def _payment_account_full_dict(account):
    """Full serialization including is_active — used by superuser endpoints."""
    return {
        **account.to_api_dict(),
        'is_active':    account.is_active,
        'sort_order':   account.sort_order,
        'instructions': account.instructions,
        'updated_at':   account.updated_at.isoformat(),
        'updated_by':   account.updated_by,
    }
