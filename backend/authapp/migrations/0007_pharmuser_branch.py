from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('authapp', '0006_organization_logo'),
        ('branches', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='pharmuser',
            name='branch',
            field=models.ForeignKey(
                blank=True,
                help_text='Pre-assigned branch. Null = org-wide access (admin/manager scope).',
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='users',
                to='branches.branch',
            ),
        ),
    ]
