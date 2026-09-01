from django.conf import settings
from django.db import models


class Notification(models.Model):

    NOTIFICATION_TYPES = [
        ('outage', 'Outage'),
        ('restored', 'Restored'),
        ('confirmation', 'Confirmation'),
        ('system', 'System'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications'
    )

    notification_type = models.CharField(
        max_length=30,
        choices=NOTIFICATION_TYPES
    )

    title = models.CharField(max_length=200)

    message = models.TextField()

    outage = models.ForeignKey(
        'outages.OutageReport',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='notifications'
    )

    is_read = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user} - {self.title}"