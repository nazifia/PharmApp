from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('authapp', '0012_pharmacynetwork_is_default'),
    ]

    operations = [
        migrations.CreateModel(
            name='CommissionConfig',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('commission_rate', models.FloatField(default=0.0)),
                ('fixed_bonus', models.FloatField(blank=True, null=True)),
                ('is_active', models.BooleanField(default=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('organization', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='commission_configs',
                    to='authapp.organization',
                )),
                ('user', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='commission_config',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                'ordering': ('user__full_name',),
                'unique_together': {('organization', 'user')},
            },
        ),
    ]
