"""
Management command: expire_trials

Refreshes the status of all trial subscriptions based on their trial_ends_at
date.  Designed to be run as a daily cron job or Celery beat task.

Usage:
    python manage.py expire_trials            # normal run
    python manage.py expire_trials --dry-run  # preview without saving
    python manage.py expire_trials --verbose  # print each org name

Cron example (every day at midnight):
    0 0 * * * /path/to/venv/bin/python /path/to/manage.py expire_trials \
              --settings pharmapi.settings.prod >> /var/log/expire_trials.log 2>&1
"""
from django.core.management.base import BaseCommand
from django.utils import timezone

from subscription.models import Subscription


class Command(BaseCommand):
    help = 'Refresh trial subscription statuses (expire / mark expiring).'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run', action='store_true',
            help='Show what would change without saving to the database.',
        )
        parser.add_argument(
            '--verbose', action='store_true',
            help='Print each subscription that is updated.',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        verbose = options['verbose']
        now     = timezone.now()

        if dry_run:
            self.stdout.write(self.style.WARNING('DRY RUN — no changes will be saved.\n'))

        trial_subs = Subscription.objects.filter(plan='trial').select_related('organization')

        counts = {'trial': 0, 'expiring': 0, 'expired': 0, 'skipped': 0}

        for sub in trial_subs:
            old_status = sub.status
            sub.refresh_status()
            new_status = sub.status

            if old_status == new_status:
                counts['skipped'] += 1
                continue

            counts[new_status] = counts.get(new_status, 0) + 1

            if verbose:
                self.stdout.write(
                    f'  {sub.organization.name}: {old_status} → {new_status}'
                )

            if not dry_run:
                sub.save(update_fields=['status'])

        # ── Summary ───────────────────────────────────────────────────────────

        self.stdout.write('\n' + self.style.SUCCESS('expire_trials complete'))
        self.stdout.write(f"  Expired    : {counts.get('expired',  0)}")
        self.stdout.write(f"  Expiring   : {counts.get('expiring', 0)}")
        self.stdout.write(f"  Still trial: {counts.get('trial',    0)}")
        self.stdout.write(f"  Unchanged  : {counts['skipped']}")

        if dry_run:
            self.stdout.write(self.style.WARNING('\nNo changes saved (dry-run mode).'))
