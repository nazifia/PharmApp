from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('authapp', '0015_alter_userpermissionoverride_permission'),
    ]

    operations = [
        migrations.AddField(
            model_name='organization',
            name='auto_logout_minutes',
            field=models.PositiveIntegerField(
                default=10,
                help_text='Minutes of inactivity before the app logs the user out. 0 = never.',
            ),
        ),
    ]
