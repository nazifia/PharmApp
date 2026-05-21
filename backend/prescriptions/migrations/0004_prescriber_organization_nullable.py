import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('authapp', '0014_rename_network_mem_org_status_idx_authapp_pha_organiz_b86818_idx_and_more'),
        ('prescriptions', '0003_prescriber_prescription_prescriber_and_more'),
    ]

    operations = [
        migrations.AlterField(
            model_name='prescriber',
            name='organization',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name='prescribers',
                to='authapp.organization',
            ),
        ),
    ]
