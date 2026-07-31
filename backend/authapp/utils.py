import re

from rest_framework.response import Response
from rest_framework import status

# NCC National Numbering Plan mobile prefixes: 070x, 080x, 081x, 090x, 091x.
_NG_MOBILE = re.compile(r'^0(70|80|81|90|91)\d{8}$')


def normalize_ng_phone(raw):
    """
    Normalize a Nigerian mobile number to canonical local format 0XXXXXXXXXX
    (11 digits). Accepts +234..., 234... and local 0... forms, with spaces,
    dashes, dots or parentheses. Returns None if not a valid NCC mobile number.
    """
    digits = re.sub(r'[\s\-().]', '', raw or '')
    if digits.startswith('+234'):
        digits = '0' + digits[4:]
    elif digits.startswith('234') and len(digits) == 13:
        digits = '0' + digits[3:]
    return digits if _NG_MOBILE.match(digits) else None


def active_org(request):
    """
    The organization this request acts inside.

    Normally the user's own org. A superuser may act inside ANY tenant by
    logging in and then calling /api/auth/switch-org/, which mints a token
    carrying an `org_id` claim (see authapp.views.switch_org_view).
    """
    user = getattr(request, 'user', None)
    if getattr(user, 'is_superuser', False):
        payload = getattr(request.auth, 'payload', None) or {}
        org_id  = payload.get('org_id')
        if org_id:
            from authapp.models import Organization
            org = Organization.objects.filter(pk=org_id).first()
            if org is not None:
                return org
    return getattr(user, 'organization', None)


def require_org(request):
    """
    Returns (organization, None) for a normal authenticated user
    or (None, 403_Response) if the user has no organization linked.
    Superusers without an org must pick one via /api/auth/switch-org/.
    """
    org = active_org(request)
    if org is None:
        if getattr(request.user, 'is_superuser', False):
            return None, Response(
                {'detail': 'Select a pharmacy to manage.', 'code': 'select_org'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return None, Response(
            {'detail': 'Your account is not linked to an organization. '
                       'Contact your administrator or register a new pharmacy.'},
            status=status.HTTP_403_FORBIDDEN,
        )
    return org, None


def _get_client_ip(request):
    x_forwarded = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded:
        return x_forwarded.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR')


def log_activity(request, action, category, description='', user=None):
    """
    Fire-and-forget activity log entry. Never raises — logging must not break views.
    Pass `user` explicitly when request.user is not yet authenticated (e.g. login view).
    """
    try:
        from authapp.models import ActivityLog
        if user is None:
            user = request.user if request.user.is_authenticated else None
        org  = getattr(user, 'organization', None)
        ActivityLog.objects.create(
            organization=org,
            user=user,
            username=getattr(user, 'full_name', '') or getattr(user, 'phone_number', '') if user else '',
            role=getattr(user, 'role', '') if user else '',
            action=action,
            category=category,
            description=description,
            ip_address=_get_client_ip(request),
        )
    except Exception:
        pass
