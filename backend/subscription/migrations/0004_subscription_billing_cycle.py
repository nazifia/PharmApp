from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('subscription', '0003_planpricing'),
    ]

    operations = [
        migrations.AddField(
            model_name='subscription',
            name='billing_cycle',
            field=models.CharField(
                choices=[('monthly', 'Monthly'), ('annual', 'Annual')],
                default='monthly',
                max_length=10,
                help_text='Monthly or annual billing. Annual shows a discounted total/year price.',
            ),
        ),
    ]
