from decimal import Decimal
from django.db import migrations, models


def seed_plan_pricing(apps, schema_editor):
    PlanPricing = apps.get_model('subscription', 'PlanPricing')
    defaults = [
        ('trial',        Decimal('0.00'),  Decimal('0.00')),
        ('starter',      Decimal('9.99'),  Decimal('99.99')),
        ('professional', Decimal('29.99'), Decimal('299.99')),
        ('enterprise',   Decimal('79.99'), Decimal('799.99')),
    ]
    for plan, monthly, annual in defaults:
        PlanPricing.objects.get_or_create(
            plan=plan,
            defaults={
                'monthly_price': monthly,
                'annual_price':  annual,
                'currency':      'USD',
                'is_active':     True,
            },
        )


class Migration(migrations.Migration):

    dependencies = [
        ('subscription', '0002_subscriptionevent'),
    ]

    operations = [
        migrations.CreateModel(
            name='PlanPricing',
            fields=[
                ('id',            models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('plan',          models.CharField(
                    choices=[
                        ('trial',        'Free Trial'),
                        ('starter',      'Starter'),
                        ('professional', 'Professional'),
                        ('enterprise',   'Enterprise'),
                    ],
                    max_length=20, unique=True,
                )),
                ('monthly_price', models.DecimalField(decimal_places=2, default=Decimal('0.00'), max_digits=10)),
                ('annual_price',  models.DecimalField(
                    decimal_places=2, default=Decimal('0.00'), max_digits=10,
                    help_text='Full yearly price (total for 12 months). Set to 0 to disable annual billing.',
                )),
                ('currency',      models.CharField(default='USD', max_length=3)),
                ('is_active',     models.BooleanField(
                    default=True,
                    help_text='Inactive plans are hidden from the in-app upgrade screen.',
                )),
                ('updated_at',    models.DateTimeField(auto_now=True)),
                ('updated_by',    models.CharField(blank=True, default='', max_length=150)),
            ],
            options={
                'verbose_name':        'Plan Pricing',
                'verbose_name_plural': 'Plan Pricing',
                'ordering':            ['monthly_price'],
            },
        ),
        migrations.RunPython(seed_plan_pricing, migrations.RunPython.noop),
    ]
