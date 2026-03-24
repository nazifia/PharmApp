from django.contrib.auth import authenticate
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from rest_framework.throttling import ScopedRateThrottle
from rest_framework_simplejwt.tokens import RefreshToken
from .models import Organization, PharmUser


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

    return Response({
        'access': _token_for(user),
        'user':   user.to_api_dict(),
    }, status=status.HTTP_201_CREATED)
