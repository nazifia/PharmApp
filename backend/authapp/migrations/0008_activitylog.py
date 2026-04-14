from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('authapp', '0007_pharmuser_branch'),
    ]

    operations = [
        migrations.CreateModel(
            name='ActivityLog',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('username', models.CharField(blank=True, default='', max_length=200)),
                ('role', models.CharField(blank=True, default='', max_length=30)),
                ('action', models.CharField(max_length=100)),
                ('category', models.CharField(
                    choices=[
                        ('auth', 'Auth'), ('sales', 'Sales'), ('inventory', 'Inventory'),
                        ('customers', 'Customers'), ('users', 'Users'), ('settings', 'Settings'),
                        ('reports', 'Reports'), ('other', 'Other'),
                    ],
                    default='other', max_length=20,
                )),
                ('description', models.TextField(blank=True, default='')),
                ('ip_address', models.GenericIPAddressField(blank=True, null=True)),
                ('timestamp', models.DateTimeField(auto_now_add=True)),
                ('organization', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='activity_logs',
                    to='authapp.organization',
                )),
                ('user', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='activity_logs',
                    to='authapp.pharmuser',
                )),
            ],
            options={
                'ordering': ['-timestamp'],
            },
        ),
        migrations.AddIndex(
            model_name='activitylog',
            index=models.Index(fields=['organization', 'timestamp'], name='authapp_act_org_ts_idx'),
        ),
        migrations.AddIndex(
            model_name='activitylog',
            index=models.Index(fields=['organization', 'category'], name='authapp_act_org_cat_idx'),
        ),
    ]
