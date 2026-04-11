from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('subscription', '0006_add_plan_feature_flag'),
    ]

    operations = [
        migrations.CreateModel(
            name='PaymentAccount',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('account_type', models.CharField(
                    choices=[
                        ('bank_transfer', 'Bank Transfer'),
                        ('mobile_money',  'Mobile Money'),
                        ('paypal',        'PayPal'),
                        ('payoneer',      'Payoneer'),
                        ('flutterwave',   'Flutterwave'),
                        ('stripe',        'Stripe'),
                        ('crypto',        'Cryptocurrency'),
                        ('other',         'Other'),
                    ],
                    default='bank_transfer',
                    max_length=20,
                    help_text='Payment method / channel type.',
                )),
                ('label', models.CharField(
                    max_length=100,
                    help_text='Short display name shown to customers (e.g. "GTBank — NGN Account").',
                )),
                ('account_name', models.CharField(
                    max_length=150,
                    help_text='Name of the account holder.',
                )),
                ('bank_name', models.CharField(
                    blank=True,
                    default='',
                    max_length=150,
                    help_text='Bank or provider name (leave blank for PayPal / crypto).',
                )),
                ('account_number', models.CharField(
                    max_length=200,
                    help_text='Account number, phone number, email address, or wallet address.',
                )),
                ('routing_info', models.CharField(
                    blank=True,
                    default='',
                    max_length=100,
                    help_text='Sort code, routing number, SWIFT / BIC, or branch code (optional).',
                )),
                ('currency', models.CharField(
                    default='USD',
                    max_length=3,
                    help_text='ISO 4217 currency code (e.g. USD, NGN, GHS, GBP).',
                )),
                ('country', models.CharField(
                    blank=True,
                    default='',
                    max_length=100,
                    help_text='Country or region this account is intended for (optional).',
                )),
                ('instructions', models.TextField(
                    blank=True,
                    default='',
                    help_text=(
                        'Additional payment instructions shown to the customer '
                        '(e.g. "Use your org name as the payment reference").'
                    ),
                )),
                ('is_active', models.BooleanField(
                    default=True,
                    help_text='Only active accounts are shown in the Flutter app.',
                )),
                ('sort_order', models.PositiveSmallIntegerField(
                    default=0,
                    help_text='Lower numbers appear first.',
                )),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('updated_by', models.CharField(
                    blank=True,
                    default='',
                    max_length=150,
                    help_text='Username of the last superuser to edit this record.',
                )),
            ],
            options={
                'verbose_name': 'Payment Account',
                'verbose_name_plural': 'Payment Accounts',
                'ordering': ['sort_order', 'currency', 'label'],
            },
        ),
    ]
