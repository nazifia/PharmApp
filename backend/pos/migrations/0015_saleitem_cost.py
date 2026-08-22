from django.db import migrations, models
from django.db.models import OuterRef, Subquery


def backfill_cost(apps, schema_editor):
    """Seed the cost snapshot from each item's current cost price.

    Best available approximation for sales made before the snapshot existed:
    it is exactly what the profit report used to read at query time. Lines
    whose item was deleted stay at 0 and are reported as uncosted.
    """
    SaleItem = apps.get_model('pos', 'SaleItem')
    Item = apps.get_model('inventory', 'Item')
    SaleItem.objects.filter(item__isnull=False).update(
        cost=Subquery(Item.objects.filter(pk=OuterRef('item_id')).values('cost')[:1])
    )


class Migration(migrations.Migration):

    dependencies = [
        ('pos', '0014_alter_sale_status'),
        ('inventory', '0007_item_reorder_level'),
    ]

    operations = [
        migrations.AddField(
            model_name='saleitem',
            name='cost',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=12),
        ),
        migrations.RunPython(backfill_cost, migrations.RunPython.noop),
    ]
