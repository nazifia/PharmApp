"""
Management command: notify_inactive_orgs

Finds organizations where NO user has logged in for 7+ days and sends the
org admin a WhatsApp reminder via the Meta WhatsApp Cloud API.

Required environment variables (set in the wsgi file / scheduled task):
    WHATSAPP_TOKEN            Meta Cloud API access token
    WHATSAPP_PHONE_NUMBER_ID  Sender phone-number ID from Meta Business
    WHATSAPP_TEMPLATE_NAME    Approved template name (default: inactive_org_reminder)

Usage:
    python manage.py notify_inactive_orgs             # normal run
    python manage.py notify_inactive_orgs --dry-run   # preview, no sends
    python manage.py notify_inactive_orgs --days 14   # custom threshold

PythonAnywhere scheduled task (daily):
    python /path/to/manage.py notify_inactive_orgs --settings=pharmapi.settings.pythonanywhere
"""
import os
from datetime import timedelta

import requests
from django.core.management.base import BaseCommand
from django.db.models import Max, Q
from django.utils import timezone

from authapp.models import Organization


def send_whatsapp(to_phone, org_name, days):
    """Send one template message via the Meta WhatsApp Cloud API."""
    token    = os.environ['WHATSAPP_TOKEN']
    phone_id = os.environ['WHATSAPP_PHONE_NUMBER_ID']
    template = os.environ.get('WHATSAPP_TEMPLATE_NAME', 'inactive_org_reminder')

    # Cloud API wants E.164 without '+': 0803... -> 234803...
    digits = ''.join(c for c in to_phone if c.isdigit())
    if digits.startswith('0'):
        digits = '234' + digits[1:]

    resp = requests.post(
        f'https://graph.facebook.com/v21.0/{phone_id}/messages',
        headers={'Authorization': f'Bearer {token}'},
        json={
            'messaging_product': 'whatsapp',
            'to': digits,
            'type': 'template',
            'template': {
                'name': template,
                'language': {'code': 'en'},
                'components': [{
                    'type': 'body',
                    'parameters': [
                        {'type': 'text', 'text': org_name},
                        {'type': 'text', 'text': str(days)},
                    ],
                }],
            },
        },
        timeout=15,
    )
    resp.raise_for_status()


class Command(BaseCommand):
    help = 'WhatsApp the org admin when no org user has logged in for N days.'

    def add_arguments(self, parser):
        parser.add_argument('--days', type=int, default=7,
                            help='Inactivity threshold in days (default 7).')
        parser.add_argument('--dry-run', action='store_true',
                            help='List targets without sending or saving.')

    def handle(self, *args, **options):
        days    = options['days']
        dry_run = options['dry_run']
        now     = timezone.now()
        cutoff  = now - timedelta(days=days)

        if not dry_run and not (os.environ.get('WHATSAPP_TOKEN')
                                and os.environ.get('WHATSAPP_PHONE_NUMBER_ID')):
            self.stderr.write(self.style.ERROR(
                'WHATSAPP_TOKEN / WHATSAPP_PHONE_NUMBER_ID not set. '
                'Use --dry-run to preview.'))
            return

        stale_orgs = (
            Organization.objects
            .annotate(last_activity=Max('users__last_login'))
            # Whole org silent since cutoff. Orgs whose users have never
            # logged in (last_activity NULL) fall back to created_at so a
            # brand-new org isn't flagged on day one.
            .filter(
                Q(last_activity__lt=cutoff) |
                Q(last_activity__isnull=True, created_at__lt=cutoff)
            )
            # Don't re-remind within the same window.
            .filter(Q(last_reminded_at__isnull=True) | Q(last_reminded_at__lt=cutoff))
        )

        sent = failed = skipped = 0
        for org in stale_orgs:
            admin = org.users.filter(role='Admin', is_active=True) \
                             .exclude(phone_number='').first()
            if admin is None:
                skipped += 1
                continue

            silent_days = (now - (org.last_activity or org.created_at)).days
            label = f'{org.name} -> {admin.phone_number} (silent {silent_days}d)'

            if dry_run:
                self.stdout.write(f'  WOULD SEND: {label}')
                sent += 1
                continue

            try:
                send_whatsapp(admin.phone_number, org.name, silent_days)
                org.last_reminded_at = now
                org.save(update_fields=['last_reminded_at'])
                sent += 1
                self.stdout.write(f'  SENT: {label}')
            except Exception as exc:  # ponytail: log and continue, one bad number must not stop the batch
                failed += 1
                self.stderr.write(f'  FAILED: {label} — {exc}')

        self.stdout.write(self.style.SUCCESS(
            f'\nnotify_inactive_orgs complete — sent {sent}, failed {failed}, '
            f'no-admin {skipped}' + (' (dry-run)' if dry_run else '')))
