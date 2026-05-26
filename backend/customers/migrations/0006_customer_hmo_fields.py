from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('customers', '0005_customer_current_medications'),
    ]

    operations = [
        migrations.AddField(
            model_name='customer',
            name='hmo_provider',
            field=models.CharField(blank=True, default='', max_length=100),
        ),
        migrations.AddField(
            model_name='customer',
            name='hmo_plan_name',
            field=models.CharField(blank=True, default='', max_length=100),
        ),
        migrations.AddField(
            model_name='customer',
            name='hmo_card_number',
            field=models.CharField(blank=True, default='', max_length=100),
        ),
        migrations.AddField(
            model_name='customer',
            name='hmo_coverage_percent',
            field=models.DecimalField(
                blank=True, decimal_places=2, max_digits=5, null=True,
                help_text='Percentage (0–100) of sale total covered by HMO',
            ),
        ),
        migrations.AddField(
            model_name='customer',
            name='hmo_expiry_date',
            field=models.DateField(blank=True, null=True),
        ),
    ]
