from django.db import migrations


def fix(apps, schema_editor):
    Sale = apps.get_model("pos", "Sale")
    Sale.objects.filter(payment_method="card").update(payment_method="pos")
    Sale.objects.filter(payment_method="bank_transfer").update(payment_method="transfer")


class Migration(migrations.Migration):

    dependencies = [
        ("pos", "0012_expense_payment_source"),
    ]

    operations = [
        migrations.RunPython(fix, migrations.RunPython.noop),
    ]
