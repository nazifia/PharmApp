from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('authapp', '0016_organization_auto_logout_minutes'),
    ]

    operations = [
        migrations.AddField(
            model_name='organization',
            name='last_reminded_at',
            field=models.DateTimeField(
                blank=True, null=True,
                help_text='When the org admin was last sent an inactivity reminder.',
            ),
        ),
    ]
