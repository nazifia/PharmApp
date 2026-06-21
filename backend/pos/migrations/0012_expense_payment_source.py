from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("pos", "0011_stockcheck_cancelled_status"),
    ]

    operations = [
        migrations.AddField(
            model_name="expense",
            name="payment_source",
            field=models.CharField(
                choices=[("cash", "Cash"), ("other", "Other")],
                default="cash",
                max_length=10,
            ),
        ),
    ]
