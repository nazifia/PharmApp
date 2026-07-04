from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('customers', '0006_customer_hmo_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='wallettransaction',
            name='method',
            field=models.CharField(
                blank=True, default='', max_length=20,
                choices=[('cash', 'Cash'), ('pos', 'POS'), ('transfer', 'Transfer')],
            ),
        ),
    ]
