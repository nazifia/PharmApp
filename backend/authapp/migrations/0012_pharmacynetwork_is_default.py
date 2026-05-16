from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('authapp', '0011_pharmacynetwork_pharmacynetworkmembership'),
    ]

    operations = [
        migrations.AddField(
            model_name='pharmacynetwork',
            name='is_default',
            field=models.BooleanField(default=False, db_index=True),
        ),
    ]
