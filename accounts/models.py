from django.contrib.auth.models import AbstractUser
from django.db import models
from django.conf import settings


class User(AbstractUser):
    email = models.EmailField(unique=True)
    phone = models.CharField(max_length=20, blank=True)

    name = models.CharField(max_length=150, blank=True)
    phone_verified = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False)
    email_verified_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return self.email


class PhoneVerificationCode(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='phone_verification_codes',
    )
    code_hash = models.CharField(max_length=128)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class EmailVerificationCode(models.Model):
    EMAIL_VERIFICATION = 'EMAIL_VERIFICATION'
    PASSWORD_RESET = 'PASSWORD_RESET'
    PURPOSE_CHOICES = [
        (EMAIL_VERIFICATION, 'Email verification'),
        (PASSWORD_RESET, 'Password reset'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='email_verification_codes',
    )
    purpose = models.CharField(max_length=32, choices=PURPOSE_CHOICES)
    code_hash = models.CharField(max_length=128)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'purpose']),
        ]

class SavedArea(models.Model):

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='saved_areas'
    )

    area = models.ForeignKey(
        'areas.Area',
        on_delete=models.CASCADE,
        related_name='saved_by_users'
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'area'],
                name='unique_saved_area'
            )
        ]
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user} - {self.area}"
    