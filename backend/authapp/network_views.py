"""
Network management endpoints.

GET  /api/networks/                     — list networks this org belongs to
POST /api/networks/                     — create a new network (caller becomes owner)
GET  /api/networks/<id>/                — network detail + member list
POST /api/networks/<id>/invite/         — invite another org by slug
POST /api/networks/<id>/accept/         — accept a pending invitation
POST /api/networks/<id>/decline/        — decline / cancel a pending invitation
DELETE /api/networks/<id>/leave/        — leave (non-owner) or disband (owner, if sole owner)
DELETE /api/networks/<id>/members/<org_id>/  — owner removes a member org
"""

from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from authapp.utils import require_org, log_activity
from authapp.models import Organization, PharmacyNetwork, PharmacyNetworkMembership


def _require_membership(org, network_id, required_status='active'):
    """
    Returns (network, membership, None) when the org is an active member,
    or (None, None, error_Response) otherwise.
    """
    try:
        network = PharmacyNetwork.objects.get(pk=network_id, is_active=True)
    except PharmacyNetwork.DoesNotExist:
        return None, None, Response({'detail': 'Network not found.'}, status=status.HTTP_404_NOT_FOUND)
    try:
        m = PharmacyNetworkMembership.objects.get(network=network, organization=org)
    except PharmacyNetworkMembership.DoesNotExist:
        return None, None, Response({'detail': 'You are not a member of this network.'}, status=status.HTTP_403_FORBIDDEN)
    if required_status and m.status != required_status:
        return None, None, Response(
            {'detail': f'Membership status is "{m.status}", expected "{required_status}".'},
            status=status.HTTP_403_FORBIDDEN,
        )
    return network, m, None


# ── List / Create ─────────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def network_list(request):
    org, err = require_org(request)
    if err:
        return err

    if request.method == 'GET':
        memberships = (
            PharmacyNetworkMembership.objects
            .filter(organization=org)
            .select_related('network')
        )
        return Response([m.to_api_dict() for m in memberships])

    # POST — create network; caller's org becomes owner with status=active
    name = (request.data.get('name') or '').strip()
    if not name:
        return Response({'detail': 'name is required.'}, status=status.HTTP_400_BAD_REQUEST)

    description = (request.data.get('description') or '').strip()
    network = PharmacyNetwork.objects.create(
        name=name,
        description=description,
        created_by=org,
    )
    PharmacyNetworkMembership.objects.create(
        network=network,
        organization=org,
        role='owner',
        status='active',
        invited_by=request.user,
        joined_at=timezone.now(),
    )
    log_activity(
        request, action='Create Network', category='settings',
        description=f'Created pharmacy network "{name}"',
    )
    return Response(network.to_api_dict(), status=status.HTTP_201_CREATED)


# ── Detail ────────────────────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def network_detail(request, network_id):
    org, err = require_org(request)
    if err:
        return err

    network, membership, err = _require_membership(org, network_id)
    if err:
        return err

    members = (
        PharmacyNetworkMembership.objects
        .filter(network=network)
        .select_related('organization', 'network')
    )
    data = network.to_api_dict(membership=membership)
    data['members'] = [m.to_api_dict() for m in members]
    return Response(data)


# ── Invite ────────────────────────────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def network_invite(request, network_id):
    org, err = require_org(request)
    if err:
        return err

    network, membership, err = _require_membership(org, network_id)
    if err:
        return err

    if membership.role != 'owner':
        return Response({'detail': 'Only network owners can invite members.'}, status=status.HTTP_403_FORBIDDEN)

    org_slug = (request.data.get('org_slug') or '').strip()
    if not org_slug:
        return Response({'detail': 'org_slug is required.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        target_org = Organization.objects.get(slug=org_slug)
    except Organization.DoesNotExist:
        return Response({'detail': 'No pharmacy found with that slug.'}, status=status.HTTP_404_NOT_FOUND)

    if target_org == org:
        return Response({'detail': 'Cannot invite your own organization.'}, status=status.HTTP_400_BAD_REQUEST)

    m, created = PharmacyNetworkMembership.objects.get_or_create(
        network=network,
        organization=target_org,
        defaults={'role': 'member', 'status': 'pending', 'invited_by': request.user},
    )
    if not created:
        if m.status == 'active':
            return Response({'detail': 'Organization is already a member.'}, status=status.HTTP_409_CONFLICT)
        # Re-invite a previously declined/suspended org
        m.status = 'pending'
        m.invited_by = request.user
        m.save(update_fields=['status', 'invited_by'])

    log_activity(
        request, action='Invite to Network', category='settings',
        description=f'Invited "{target_org.name}" to network "{network.name}"',
    )
    return Response(m.to_api_dict(), status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


# ── Accept / Decline ──────────────────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def network_accept(request, network_id):
    org, err = require_org(request)
    if err:
        return err

    network, membership, err = _require_membership(org, network_id, required_status='pending')
    if err:
        return err

    membership.status   = 'active'
    membership.joined_at = timezone.now()
    membership.save(update_fields=['status', 'joined_at'])

    log_activity(
        request, action='Join Network', category='settings',
        description=f'"{org.name}" accepted invitation to network "{network.name}"',
    )
    return Response(membership.to_api_dict())


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def network_decline(request, network_id):
    org, err = require_org(request)
    if err:
        return err

    network, membership, err = _require_membership(org, network_id, required_status='pending')
    if err:
        return err

    membership.delete()
    log_activity(
        request, action='Decline Network', category='settings',
        description=f'"{org.name}" declined invitation to network "{network.name}"',
    )
    return Response(status=status.HTTP_204_NO_CONTENT)


# ── Leave ─────────────────────────────────────────────────────────────────────

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def network_leave(request, network_id):
    org, err = require_org(request)
    if err:
        return err

    network, membership, err = _require_membership(org, network_id)
    if err:
        return err

    if membership.role == 'owner':
        # Disband only if sole owner; otherwise require ownership transfer first
        other_owners = network.memberships.filter(role='owner', status='active').exclude(organization=org)
        if other_owners.exists():
            return Response(
                {'detail': 'Transfer ownership before leaving.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        # Sole owner disbands the whole network
        network.is_active = False
        network.save(update_fields=['is_active'])
        log_activity(
            request, action='Disband Network', category='settings',
            description=f'Disbanded network "{network.name}"',
        )
    else:
        membership.delete()
        log_activity(
            request, action='Leave Network', category='settings',
            description=f'"{org.name}" left network "{network.name}"',
        )
    return Response(status=status.HTTP_204_NO_CONTENT)


# ── Remove member (owner action) ──────────────────────────────────────────────

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def network_remove_member(request, network_id, org_id):
    org, err = require_org(request)
    if err:
        return err

    network, membership, err = _require_membership(org, network_id)
    if err:
        return err

    if membership.role != 'owner':
        return Response({'detail': 'Only network owners can remove members.'}, status=status.HTTP_403_FORBIDDEN)

    if org_id == org.id:
        return Response({'detail': 'Use /leave/ to remove yourself.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        target = PharmacyNetworkMembership.objects.get(network=network, organization_id=org_id)
    except PharmacyNetworkMembership.DoesNotExist:
        return Response({'detail': 'Member not found.'}, status=status.HTTP_404_NOT_FOUND)

    target_name = target.organization.name
    target.delete()
    log_activity(
        request, action='Remove Network Member', category='settings',
        description=f'Removed "{target_name}" from network "{network.name}"',
    )
    return Response(status=status.HTTP_204_NO_CONTENT)
