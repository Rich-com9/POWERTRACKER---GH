from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ('accounts', '0002_savedarea'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='phone_verified',
            field=models.BooleanField(default=False),
        ),
        migrations.CreateModel(
            name='PhoneVerificationCode',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('code_hash', models.CharField(max_length=128)),
                ('expires_at', models.DateTimeField()),
                ('attempts', models.PositiveSmallIntegerField(default=0)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='phone_verification_codes', to=settings.AUTH_USER_MODEL)),
            ],
            options={'ordering': ['-created_at']},
        ),
    ]