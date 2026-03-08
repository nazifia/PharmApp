from django.contrib.auth import authenticate
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken


def _token_for(user):
    refresh = RefreshToken.for_user(user)
    return str(refresh.access_token)


@api_view(['POST'])
@permission_classes([AllowAny])
def login_view(request):
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
