"""
Migration: remove api_access and white_label feature keys.

- Updates Subscription.extra_features help_text to drop those two keys.
- Updates PlanFeatureFlag.feature_key choices to drop those two keys.
- Deletes any existing PlanFeatureFlag rows whose feature_key is
  'api_access' or 'white_label'.
"""

from django.db import migrations, models


def delete_stale_feature_flags(apps, schema_editor):
    PlanFeatureFlag = apps.get_model('subscription', 'PlanFeatureFlag')
    deleted, _ = PlanFeatureFlag.objects.filter(
        feature_key__in=['api_access', 'white_label']
    ).delete()
    if deleted:
        print(f'  Deleted {deleted} stale PlanFeatureFlag row(s) '
              f'(api_access / white_label).')


class Migration(migrations.Migration):

    dependencies = [
        ('subscription', '0007_add_payment_account'),
    ]

    operations = [
        # 1. Remove stale DB rows before narrowing the choices constraint.
        migrations.RunPython(
            delete_stale_feature_flags,
            reverse_code=migrations.RunPython.noop,
        ),

        # 2. Update Subscription.extra_features help_text.
        migrations.AlterField(
            model_name='subscription',
            name='extra_features',
            field=models.JSONField(
                blank=True,
                default=list,
                help_text=(
                    'Feature keys enabled for this org beyond the plan default. '
                    'Valid keys: pos, inventory, customers, user_management, '
                    'basic_reports, advanced_reports, wholesale, export_data, '
                    'multi_branch, priority_support'
                ),
            ),
        ),

        # 3. Update PlanFeatureFlag.feature_key choices.
        migrations.AlterField(
            model_name='planfeatureflag',
            name='feature_key',
            field=models.CharField(
                choices=[
                    ('pos',              'Point of Sale'),
                    ('inventory',        'Inventory Management'),
                    ('customers',        'Customer Management'),
                    ('user_management',  'User Management'),
                    ('basic_reports',    'Basic Reports'),
                    ('advanced_reports', 'Advanced Reports'),
                    ('wholesale',        'Wholesale Module'),
                    ('export_data',      'Export Data'),
                    ('multi_branch',     'Multi-Branch'),
                    ('priority_support', 'Priority Support'),
                ],
                help_text='Internal key used by the Flutter app to gate feature access.',
                max_length=50,
            ),
        ),
    ]
