import django.db.models.deletion
import django.utils.timezone
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('authapp',   '0001_initial'),
        ('branches',  '__first__'),
        ('customers', '__first__'),
        ('inventory', '__first__'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Prescription',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('customer_name',  models.CharField(default='Walk-in', max_length=200)),
                ('customer_phone', models.CharField(blank=True, default='', max_length=20)),
                ('doctor_name',    models.CharField(blank=True, default='', max_length=200)),
                ('diagnosis',      models.TextField(blank=True, default='')),
                ('notes',          models.TextField(blank=True, default='')),
                ('status',         models.CharField(
                    choices=[('pending', 'Pending'), ('partial', 'Partial'), ('dispensed', 'Dispensed')],
                    default='pending', max_length=20,
                )),
                ('created_at',   models.DateTimeField(auto_now_add=True)),
                ('dispensed_at', models.DateTimeField(blank=True, null=True)),
                ('organization', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='prescriptions',
                    to='authapp.organization',
                )),
                ('branch', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='prescriptions',
                    to='branches.branch',
                )),
                ('customer', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='prescriptions',
                    to='customers.customer',
                )),
                ('created_by', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='prescriptions_written',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.CreateModel(
            name='PrescriptionItem',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('item_name',     models.CharField(max_length=200)),
                ('brand',         models.CharField(blank=True, default='', max_length=200)),
                ('quantity',      models.DecimalField(decimal_places=2, default=1, max_digits=10)),
                ('unit',          models.CharField(default='unit(s)', max_length=50)),
                ('dosage',        models.CharField(blank=True, default='', max_length=200)),
                ('duration',      models.CharField(blank=True, default='', max_length=100)),
                ('instructions',  models.TextField(blank=True, default='')),
                ('is_dispensed',  models.BooleanField(default=False)),
                ('dispensed_at',  models.DateTimeField(blank=True, null=True)),
                ('prescription', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='medications',
                    to='prescriptions.prescription',
                )),
                ('item', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='prescription_items',
                    to='inventory.item',
                )),
                ('dispensed_by', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='dispensed_rx_items',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
        ),
        migrations.AddIndex(
            model_name='prescription',
            index=models.Index(fields=['organization', 'status'], name='presc_org_status_idx'),
        ),
        migrations.AddIndex(
            model_name='prescription',
            index=models.Index(fields=['organization', 'created_at'], name='presc_org_created_idx'),
        ),
        migrations.AddIndex(
            model_name='prescription',
            index=models.Index(fields=['customer_phone'], name='presc_phone_idx'),
        ),
    ]
