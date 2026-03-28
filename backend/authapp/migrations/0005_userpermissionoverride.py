from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('authapp', '0004_add_full_name_to_pharmuser'),
    ]

    operations = [
        migrations.CreateModel(
            name='UserPermissionOverride',
            fields=[
                ('id',         models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('permission', models.CharField(
                    choices=[
                        ('viewReports','viewReports'),('manageUsers','manageUsers'),
                        ('manageSettings','manageSettings'),('viewNotifications','viewNotifications'),
                        ('viewSubscription','viewSubscription'),('retailPOS','retailPOS'),
                        ('wholesalePOS','wholesalePOS'),('viewWholesale','viewWholesale'),
                        ('readInventory','readInventory'),('writeInventory','writeInventory'),
                        ('readCustomers','readCustomers'),('writeCustomers','writeCustomers'),
                        ('manageExpenses','manageExpenses'),('manageSuppliers','manageSuppliers'),
                        ('processPayments','processPayments'),('manageTransfers','manageTransfers'),
                    ],
                    max_length=50,
                )),
                ('granted',    models.BooleanField(
                    default=True,
                    help_text='True = grant (even if role lacks it). False = revoke (even if role has it).',
                )),
                ('note',       models.CharField(blank=True, default='', max_length=200)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user',       models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='permission_overrides',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={'ordering': ('permission',)},
        ),
        migrations.AlterUniqueTogether(
            name='userpermissionoverride',
            unique_together={('user', 'permission')},
        ),
    ]
