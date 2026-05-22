from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('customers', '0004_customer_prescriber_medical_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='customer',
            name='current_medications',
            field=models.JSONField(blank=True, default=list),
        ),
    ]
