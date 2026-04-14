from rest_framework.response import Response
from rest_framework import status


def require_org(request):
    """
    Returns (organization, None) for a normal authenticated user
    or (None, 403_Response) if the user has no organization linked.
    Superusers are also required to have an org when using the API.
    """
    org = getattr(request.user, 'organization', None)
    if org is None:
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


def log_activity(request, action, category, description=''):
    """
    Fire-and-forget activity log entry. Never raises — logging must not break views.
    """
    try:
        from authapp.models import ActivityLog
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
