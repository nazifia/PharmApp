from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("pos", "0010_sale_consultation_fee"),
    ]

    operations = [
        migrations.AlterField(
            model_name="stockcheck",
            name="status",
            field=models.CharField(
                choices=[
                    ("pending", "Pending"),
                    ("in_progress", "In Progress"),
                    ("completed", "Completed"),
                    ("cancelled", "Cancelled"),
                ],
                default="pending",
                max_length=20,
            ),
        ),
    ]
