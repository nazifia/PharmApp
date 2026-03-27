import django.db.models.deletion
import django.utils.timezone
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('authapp', '0002_organization_pharmuser_organization'),
    ]

    operations = [
        migrations.CreateModel(
            name='Subscription',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('plan', models.CharField(
                    choices=[
                        ('trial',        'Free Trial'),
                        ('starter',      'Starter'),
                        ('professional', 'Professional'),
                        ('enterprise',   'Enterprise'),
                    ],
                    default='trial',
                    max_length=20,
                )),
                ('status', models.CharField(
                    choices=[
                        ('trial',     'Trial'),
                        ('expiring',  'Trial Expiring'),
                        ('expired',   'Expired'),
                        ('active',    'Active'),
                        ('suspended', 'Suspended'),
                        ('cancelled', 'Cancelled'),
                    ],
                    default='trial',
                    max_length=20,
                )),
                ('trial_ends_at',           models.DateTimeField(blank=True, null=True)),
                ('current_period_end',      models.DateTimeField(blank=True, null=True)),
                ('external_subscription_id', models.CharField(blank=True, default='', max_length=200)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('organization', models.OneToOneField(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='subscription',
                    to='authapp.organization',
                )),
            ],
            options={
                'verbose_name':        'Subscription',
                'verbose_name_plural': 'Subscriptions',
            },
        ),
    ]
