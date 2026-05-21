from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('prescriptions', '0005_hospital_prescriber_hospital'),
    ]

    operations = [
        migrations.AddField(
            model_name='prescriber',
            name='password',
            field=models.CharField(blank=True, default='', max_length=128),
        ),
    ]
