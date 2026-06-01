from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('pos', '0008_sale_hmo_shift'),
    ]

    operations = [
        migrations.AddField(
            model_name='sale',
            name='shift',
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='shift_sales',
                to='pos.shift',
            ),
        ),
    ]
