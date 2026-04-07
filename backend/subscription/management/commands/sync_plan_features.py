"""
Management command: sync_plan_features

Performs an additive sync of PlanFeatureFlag rows from PLAN_FEATURES_DEFAULT.
Every (plan, feature_key) pair that is missing from the DB is created with
is_enabled=True.  Existing rows — including any superuser customisations — are
left completely untouched.  Nothing is removed or disabled.

Covers ALL plans (trial / starter / professional / enterprise) and ALL features
defined in PLAN_FEATURES_DEFAULT.

Usage
-----
    python manage.py sync_plan_features
    python manage.py sync_plan_features --dry-run     # show what would be added
    python manage.py sync_plan_features --plan starter  # one plan only
    python manage.py sync_plan_features --feature customers  # one feature only
"""
from django.core.management.base import BaseCommand, CommandError

from subscription.models import PlanFeatureFlag, PLAN_CHOICES, PLAN_FEATURES_DEFAULT, FEATURE_KEY_CHOICES


class Command(BaseCommand):
    help = (
        'Add any missing PlanFeatureFlag rows from PLAN_FEATURES_DEFAULT '
        'without modifying or removing existing rows.'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            default=False,
            help='Show what would be added without writing to the DB.',
        )
        parser.add_argument(
            '--plan',
            metavar='PLAN',
            default=None,
            help='Sync only this plan (e.g. starter). Omit to sync all plans.',
        )
        parser.add_argument(
            '--feature',
            metavar='KEY',
            default=None,
            help='Sync only this feature key (e.g. customers). Omit to sync all features.',
        )

    def handle(self, *args, **options):
        dry_run        = options['dry_run']
        filter_plan    = options['plan']
        filter_feature = options['feature']

        valid_plans    = {p for p, _ in PLAN_CHOICES}
        valid_features = {k for k, _ in FEATURE_KEY_CHOICES}

        if filter_plan and filter_plan not in valid_plans:
            raise CommandError(
                f'Unknown plan "{filter_plan}". '
                f'Valid plans: {", ".join(sorted(valid_plans))}'
            )
        if filter_feature and filter_feature not in valid_features:
            self.stdout.write(self.style.WARNING(
                f'Feature key "{filter_feature}" is not in FEATURE_KEY_CHOICES — '
                f'proceeding anyway.'
            ))

        label_map = dict(FEATURE_KEY_CHOICES)
        sort_map  = {k: i for i, (k, _) in enumerate(FEATURE_KEY_CHOICES)}
        added     = 0
        skipped   = 0

        for plan, feature_set in PLAN_FEATURES_DEFAULT.items():
            if filter_plan and plan != filter_plan:
                continue
            for key in feature_set:
                if filter_feature and key != filter_feature:
                    continue

                exists = PlanFeatureFlag.objects.filter(
                    plan=plan, feature_key=key
                ).exists()

                if exists:
                    skipped += 1
                    self.stdout.write(
                        f'  skip  {plan:15s} {key}  (already in DB)'
                    )
                else:
                    if dry_run:
                        self.stdout.write(
                            self.style.WARNING(
                                f'  [dry] would add  {plan:15s} {key}'
                            )
                        )
                    else:
                        PlanFeatureFlag.objects.create(
                            plan=plan,
                            feature_key=key,
                            feature_label=label_map.get(key, key),
                            is_enabled=True,
                            sort_order=sort_map.get(key, 99),
                        )
                        self.stdout.write(
                            self.style.SUCCESS(
                                f'  added {plan:15s} {key}'
                            )
                        )
                    added += 1

        self.stdout.write('')
        if dry_run:
            self.stdout.write(self.style.WARNING(
                f'Dry run complete: {added} flag(s) would be added, '
                f'{skipped} already present.'
            ))
        else:
            self.stdout.write(self.style.SUCCESS(
                f'Sync complete: {added} flag(s) added, {skipped} already present.'
            ))
