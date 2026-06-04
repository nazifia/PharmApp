from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('authapp', '0014_rename_network_mem_org_status_idx_authapp_pha_organiz_b86818_idx_and_more'),
    ]

    operations = [
        migrations.AlterField(
            model_name='userpermissionoverride',
            name='permission',
            field=models.CharField(
                choices=[
                    ('viewReports', 'viewReports'),
                    ('manageUsers', 'manageUsers'),
                    ('manageSettings', 'manageSettings'),
                    ('viewNotifications', 'viewNotifications'),
                    ('viewSubscription', 'viewSubscription'),
                    ('retailPOS', 'retailPOS'),
                    ('wholesalePOS', 'wholesalePOS'),
                    ('viewWholesale', 'viewWholesale'),
                    ('readInventory', 'readInventory'),
                    ('createInventory', 'createInventory'),
                    ('writeInventory', 'writeInventory'),
                    ('readCustomers', 'readCustomers'),
                    ('writeCustomers', 'writeCustomers'),
                    ('manageExpenses', 'manageExpenses'),
                    ('manageSuppliers', 'manageSuppliers'),
                    ('processPayments', 'processPayments'),
                    ('manageTransfers', 'manageTransfers'),
                    ('readPrescriptions', 'readPrescriptions'),
                    ('writePrescriptions', 'writePrescriptions'),
                    ('editLowStockAlert', 'editLowStockAlert'),
                ],
                max_length=50,
            ),
        ),
    ]
