from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('branches', '0001_initial'),
        ('inventory', '0005_decimal_quantities'),
    ]

    operations = [
        migrations.AddField(
            model_name='item',
            name='branch',
            field=models.ForeignKey(
                blank=True,
                help_text='Branch this item belongs to. Null = org-wide / unassigned.',
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='items',
                to='branches.branch',
            ),
        ),
    ]
