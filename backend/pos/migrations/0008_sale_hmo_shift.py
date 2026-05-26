from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):

    dependencies = [
        ('branches', '__first__'),
        ('pos', '0007_sale_branch'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        # HMO fields on Sale
        migrations.AddField(
            model_name='sale',
            name='hmo_card_number',
            field=models.CharField(blank=True, default='', max_length=100),
        ),
        migrations.AddField(
            model_name='sale',
            name='hmo_provider',
            field=models.CharField(blank=True, default='', max_length=100),
        ),
        migrations.AddField(
            model_name='sale',
            name='hmo_coverage_percent',
            field=models.DecimalField(
                blank=True, decimal_places=2, max_digits=5, null=True,
            ),
        ),
        migrations.AddField(
            model_name='sale',
            name='hmo_amount',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=12),
        ),
        # Shift model
        migrations.CreateModel(
            name='Shift',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('status', models.CharField(
                    choices=[('open', 'Open'), ('closed', 'Closed')],
                    default='open', max_length=10,
                )),
                ('opened_at', models.DateTimeField(default=django.utils.timezone.now)),
                ('closed_at', models.DateTimeField(blank=True, null=True)),
                ('opening_cash', models.DecimalField(decimal_places=2, default=0, max_digits=12)),
                ('closing_cash', models.DecimalField(decimal_places=2, default=0, max_digits=12)),
                ('organization', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='shifts', to='authapp.organization',
                )),
                ('staff', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='shifts', to=settings.AUTH_USER_MODEL,
                )),
                ('branch', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='shifts', to='branches.branch',
                )),
            ],
            options={'ordering': ['-opened_at']},
        ),
    ]
