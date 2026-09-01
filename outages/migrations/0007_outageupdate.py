from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ('outages', '0006_outagereport_scheduled_for'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='OutageUpdate',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('message', models.TextField()),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('author', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='outage_updates', to=settings.AUTH_USER_MODEL)),
                ('outage', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='updates', to='outages.outagereport')),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
    ]