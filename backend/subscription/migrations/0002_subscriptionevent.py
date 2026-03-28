from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('subscription', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='SubscriptionEvent',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('event_type', models.CharField(
                    choices=[
                        ('plan_changed',   'Plan Changed'),
                        ('status_changed', 'Status Changed'),
                        ('trial_extended', 'Trial Extended'),
                        ('activated',      'Activated'),
                        ('suspended',      'Suspended'),
                        ('reactivated',    'Reactivated'),
                        ('cancelled',      'Cancelled'),
                        ('reset',          'Reset to Trial'),
                        ('note',           'Admin Note'),
                    ],
                    max_length=30,
                )),
                ('old_value',    models.CharField(blank=True, default='', max_length=100)),
                ('new_value',    models.CharField(blank=True, default='', max_length=100)),
                ('note',         models.TextField(blank=True, default='')),
                ('performed_by', models.CharField(default='system', max_length=150,
                                                  help_text='Username, "system", or "api"')),
                ('created_at',   models.DateTimeField(auto_now_add=True)),
                ('subscription', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='events',
                    to='subscription.subscription',
                )),
            ],
            options={
                'verbose_name':        'Subscription Event',
                'verbose_name_plural': 'Subscription Events',
                'ordering':            ['-created_at'],
            },
        ),
    ]
