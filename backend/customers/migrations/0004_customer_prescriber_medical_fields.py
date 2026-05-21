from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('customers', '0003_customer_is_network_patient'),
        ('prescriptions', '0007_remove_prescriber_prescriptio_organiz_65404a_idx_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='customer',
            name='prescriber',
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='patients',
                to='prescriptions.prescriber',
            ),
        ),
        migrations.AddField(
            model_name='customer',
            name='blood_group',
            field=models.CharField(blank=True, default='', max_length=5),
        ),
        migrations.AddField(
            model_name='customer',
            name='date_of_birth',
            field=models.DateField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='customer',
            name='allergies',
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name='customer',
            name='chronic_conditions',
            field=models.JSONField(blank=True, default=list),
        ),
    ]
