from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('inventory', '0006_item_branch'),
    ]

    operations = [
        migrations.AddField(
            model_name='item',
            name='reorder_level',
            field=models.IntegerField(null=True, blank=True),
        ),
    ]
