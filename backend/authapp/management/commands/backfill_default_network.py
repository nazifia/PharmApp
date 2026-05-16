"""
Management command: backfill_default_network

Adds every existing Organization that is not already a member of the
platform default network (is_default=True) to that network as an active member.

Usage
─────
python manage.py backfill_default_network
python manage.py backfill_default_network --dry-run
python manage.py backfill_default_network --network-id 3   # target a specific network
"""

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from authapp.models import Organization, PharmacyNetwork, PharmacyNetworkMembership


class Command(BaseCommand):
    help = 'Backfill all existing orgs into the platform default network.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run', action='store_true',
            help='Print what would happen without writing anything.',
        )
        parser.add_argument(
            '--network-id', type=int, default=None,
            help='Target a specific network by ID instead of the is_default one.',
        )

    def handle(self, *args, **options):
        dry_run    = options['dry_run']
        network_id = options['network_id']

        # ── Resolve default network ───────────────────────────────────────────
        if network_id:
            try:
                network = PharmacyNetwork.objects.get(pk=network_id, is_active=True)
            except PharmacyNetwork.DoesNotExist:
                raise CommandError(f'No active PharmacyNetwork with id={network_id}.')
        else:
            network = PharmacyNetwork.objects.filter(is_default=True, is_active=True).first()
            if network is None:
                raise CommandError(
                    'No default network found. '
                    'Mark one with is_default=True or pass --network-id.'
                )

        self.stdout.write(f'Target network: "{network.name}" (id={network.id})')

        # ── Find orgs not yet in the network ──────────────────────────────────
        already_in = set(
            PharmacyNetworkMembership.objects
            .filter(network=network)
            .values_list('organization_id', flat=True)
        )
        orgs_to_add = Organization.objects.exclude(pk__in=already_in)
        count = orgs_to_add.count()

        if count == 0:
            self.stdout.write(self.style.SUCCESS('All orgs already in network. Nothing to do.'))
            return

        self.stdout.write(f'{count} org(s) to add:')
        for org in orgs_to_add:
            self.stdout.write(f'  • {org.name} (id={org.id})')

        if dry_run:
            self.stdout.write(self.style.WARNING('Dry run — no changes written.'))
            return

        # ── Bulk insert ───────────────────────────────────────────────────────
        now = timezone.now()
        memberships = [
            PharmacyNetworkMembership(
                network=network,
                organization=org,
                role='member',
                status='active',
                joined_at=now,
            )
            for org in orgs_to_add
        ]

        with transaction.atomic():
            PharmacyNetworkMembership.objects.bulk_create(
                memberships,
                ignore_conflicts=True,  # safe re-run: skip if already added by a race
            )

        self.stdout.write(self.style.SUCCESS(f'Done. Added {count} org(s) to "{network.name}".'))
