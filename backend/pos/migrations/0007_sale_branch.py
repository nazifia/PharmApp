from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('branches', '0001_initial'),
        ('pos', '0006_decimal_stock_check'),
    ]

    operations = [
        migrations.AddField(
            model_name='sale',
            name='branch',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='sales',
                to='branches.branch',
            ),
        ),
    ]
