from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from authapp.utils import require_org
from .models import Subscription

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
