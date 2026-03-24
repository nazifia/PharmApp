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
