from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('authapp', '0010_alter_userpermissionoverride_permission'),
    ]

    operations = [
        migrations.CreateModel(
            name='PharmacyNetwork',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=200)),
                ('slug', models.SlugField(blank=True, max_length=220, unique=True)),
                ('description', models.TextField(blank=True, default='')),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('created_by', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='created_networks',
                    to='authapp.organization',
                )),
            ],
        ),
        migrations.CreateModel(
            name='PharmacyNetworkMembership',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('role', models.CharField(
                    choices=[('owner', 'Owner'), ('member', 'Member')],
                    default='member',
                    max_length=20,
                )),
                ('status', models.CharField(
                    choices=[('active', 'Active'), ('pending', 'Pending'), ('suspended', 'Suspended')],
                    default='pending',
                    max_length=20,
                )),
                ('joined_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('network', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='memberships',
                    to='authapp.pharmacynetwork',
                )),
                ('organization', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='network_memberships',
                    to='authapp.organization',
                )),
                ('invited_by', models.ForeignKey(
                    blank=True,
                    null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='network_invitations_sent',
                    to='authapp.pharmuser',
                )),
            ],
            options={
                'ordering': ['-created_at'],
                'unique_together': {('network', 'organization')},
            },
        ),
        migrations.AddIndex(
            model_name='pharmacynetworkmembership',
            index=models.Index(fields=['organization', 'status'], name='network_mem_org_status_idx'),
        ),
        migrations.AddIndex(
            model_name='pharmacynetworkmembership',
            index=models.Index(fields=['network', 'status'], name='network_mem_net_status_idx'),
        ),
    ]
