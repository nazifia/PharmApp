import re
from django.contrib.auth import authenticate
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from rest_framework.throttling import ScopedRateThrottle
from rest_framework_simplejwt.tokens import RefreshToken
from .models import Organization, PharmUser, ActivityLog
from .permissions import (
    IsAdminOrManager, PERMISSION_LABELS, _PERMISSION_ROLE_MAP, get_effective_permissions
)
from .utils import log_activity


def _token_for(user):
    refresh = RefreshToken.for_user(user)
    return str(refresh.access_token)


@api_view(['POST'])
@permission_classes([AllowAny])
@throttle_classes([ScopedRateThrottle])
def login_view(request):
    request.throttle_scope = 'auth'
    phone    = request.data.get('phone_number', '').strip()
    password = request.data.get('password', '').strip()

    if not phone or not password:
        return Response({'detail': 'phone_number and password are required.'},
                        status=status.HTTP_400_BAD_REQUEST)

    user = authenticate(request, username=phone, password=password)
    if user is None:
        return Response({'detail': 'Invalid credentials.'},
                        status=status.HTTP_401_UNAUTHORIZED)

    if not user.is_active:
        return Response({'detail': 'Account is disabled.'},
                        status=status.HTTP_403_FORBIDDEN)

    log_activity(request, action='Login', category='auth',
                 description=f'Successful login ({user.role})')
    return Response({
        'access': _token_for(user),
        'user':   user.to_api_dict(),
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def me_view(request):
    return Response(request.user.to_api_dict())


@api_view(['POST'])
@permission_classes([AllowAny])
@throttle_classes([ScopedRateThrottle])
def register_org_view(request):
    """
    Create a new Organization + its first Admin user in one step.
    No authentication required — this is the pharmacy sign-up endpoint.
    """
    request.throttle_scope = 'auth'
    org_name  = (request.data.get('org_name') or '').strip()
    phone     = (request.data.get('phone_number') or '').strip()
    password  = (request.data.get('password') or '').strip()
    address   = (request.data.get('address') or '').strip()

    if not org_name:
        return Response({'detail': 'org_name is required.'}, status=status.HTTP_400_BAD_REQUEST)
    if not phone:
        return Response({'detail': 'phone_number is required.'}, status=status.HTTP_400_BAD_REQUEST)
    if not password or len(password) < 8:
        return Response({'detail': 'password must be at least 8 characters.'}, status=status.HTTP_400_BAD_REQUEST)
    if not re.search(r'[A-Za-z]', password) or not re.search(r'\d', password):
        return Response({'detail': 'password must contain at least one letter and one digit.'}, status=status.HTTP_400_BAD_REQUEST)

    if PharmUser.objects.filter(phone_number=phone).exists():
        return Response({'detail': 'A user with this phone number already exists.'},
                        status=status.HTTP_400_BAD_REQUEST)

    # Create the organization
    org = Organization.objects.create(name=org_name, address=address)

    # Create the first admin user linked to this org
    user = PharmUser.objects.create_user(
        phone_number=phone,
        password=password,
        role='Admin',
        organization=org,
    )

    # Create subscription in 'pending' state — superuser must approve before trial starts
    try:
        from subscription.models import Subscription
        Subscription.objects.get_or_create(
            organization=org,
            defaults={
                'plan':   'trial',
                'status': 'pending',
            },
        )
    except Exception:
        pass  # non-fatal — subscription can be created later via GET /subscription/

    return Response({
        'access': _token_for(user),
        'user':   user.to_api_dict(),
    }, status=status.HTTP_201_CREATED)


@api_view(['PATCH'])
@permission_classes([IsAuthenticated, IsAdminOrManager])
def org_logo_view(request):
    """
    PATCH /auth/org/logo/
    Multipart: { logo: <file> }
    Replaces the caller's organisation logo and returns { logoUrl }.
    """
    org = request.user.organization
    if org is None:
        return Response({'detail': 'No organisation linked to this account.'},
                        status=status.HTTP_400_BAD_REQUEST)

    logo_file = request.FILES.get('logo')
    if not logo_file:
        return Response({'detail': 'logo file is required.'}, status=status.HTTP_400_BAD_REQUEST)

    MAX_LOGO_SIZE = 2 * 1024 * 1024  # 2 MB
    if logo_file.size > MAX_LOGO_SIZE:
        return Response({'detail': 'Logo file must be smaller than 2 MB.'}, status=status.HTTP_400_BAD_REQUEST)

    allowed_types = {'image/jpeg', 'image/png', 'image/webp', 'image/gif'}
    if logo_file.content_type not in allowed_types:
        return Response({'detail': 'Logo must be a JPEG, PNG, WebP, or GIF image.'}, status=status.HTTP_400_BAD_REQUEST)

    # Delete old file to avoid orphan uploads
    if org.logo:
        org.logo.delete(save=False)

    org.logo = logo_file
    org.save(update_fields=['logo'])

    return Response({'logoUrl': request.build_absolute_uri(org.logo.url)})


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated, IsAdminOrManager])
def user_permissions_view(request, user_id):
    """
    GET  /auth/users/<id>/permissions/
         Returns per-permission matrix: role_default, override_state, effective.

    POST /auth/users/<id>/permissions/
         Body: { overrides: { permKey: 'inherit' | 'grant' | 'revoke', ... } }
         Saves overrides and returns updated matrix.
    """
    from .models import UserPermissionOverride

    # Scope: caller must be in same org (or superuser)
    try:
        target = PharmUser.objects.get(
            pk=user_id, organization=request.user.organization
        )
    except PharmUser.DoesNotExist:
        return Response({'detail': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'POST':
        overrides_input = request.data.get('overrides', {})
        if not isinstance(overrides_input, dict):
            return Response({'detail': 'overrides must be an object.'},
                            status=status.HTTP_400_BAD_REQUEST)

        valid_keys = {key for _, key in PERMISSION_LABELS}
        for perm_key, state in overrides_input.items():
            if perm_key not in valid_keys:
                continue
            if state == 'inherit':
                UserPermissionOverride.objects.filter(user=target, permission=perm_key).delete()
            elif state in ('grant', 'revoke'):
                UserPermissionOverride.objects.update_or_create(
                    user=target, permission=perm_key,
                    defaults={'granted': state == 'grant'},
                )

    # Build response matrix
    role = target.role or ''
    overrides_qs = {
        ov.permission: ov.granted
        for ov in UserPermissionOverride.objects.filter(user=target)
    }
    rows = []
    for label, key in PERMISSION_LABELS:
        role_default = role in (_PERMISSION_ROLE_MAP.get(key) or set())
        if key in overrides_qs:
            override_state = 'grant' if overrides_qs[key] else 'revoke'
            effective = overrides_qs[key]
        else:
            override_state = 'inherit'
            effective = role_default
        rows.append({
            'key':           key,
            'label':         label,
            'role_default':  role_default,
            'override_state': override_state,
            'effective':     effective,
        })

    return Response({
        'user_id': target.pk,
        'role':    role,
        'rows':    rows,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsAdminOrManager])
def activity_log_view(request):
    """
    GET /auth/activity-log/
    Query params: page (int), page_size (int, max 100), category (str), search (str)
    Returns: { count, results: [...] }
    """
    org = getattr(request.user, 'organization', None)
    if org is None:
        return Response({'detail': 'No organisation linked.'}, status=status.HTTP_403_FORBIDDEN)

    page      = max(1, int(request.query_params.get('page', 1)))
    page_size = min(100, max(1, int(request.query_params.get('page_size', 30))))
    category  = request.query_params.get('category', '').strip()
    search    = request.query_params.get('search', '').strip()

    qs = ActivityLog.objects.filter(organization=org)
    if category:
        qs = qs.filter(category=category)
    if search:
        from django.db.models import Q
        qs = qs.filter(
            Q(username__icontains=search) |
            Q(action__icontains=search)   |
            Q(description__icontains=search)
        )

    total  = qs.count()
    offset = (page - 1) * page_size
    logs   = qs[offset: offset + page_size]

    return Response({
        'count':   total,
        'results': [log.to_api_dict() for log in logs],
    })
