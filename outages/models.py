from django.conf import settings
from django.db import models


class OutageReport(models.Model):

    STATUS_CHOICES = [
        ('active', 'Active'),
        ('restored', 'Restored'),
    ]

    OUTAGE_TYPE_CHOICES = [
        ('planned', 'Planned'),
        ('unplanned', 'Unplanned'),
        ('unknown', 'Unknown'),
    ]

    reported_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='outage_reports'
    )

    area = models.ForeignKey(
        'areas.Area',
        on_delete=models.CASCADE,
        related_name='outages'
    )

    description = models.TextField(blank=True)

    location_address = models.CharField(
        max_length=255,
        blank=True
    )

    image = models.ImageField(
        upload_to='outage_images/',
        blank=True,
        null=True
    )

    latitude = models.DecimalField(
        max_digits=9,
        decimal_places=6
    )

    longitude = models.DecimalField(
        max_digits=9,
        decimal_places=6
    )

    outage_type = models.CharField(
        max_length=20,
        choices=OUTAGE_TYPE_CHOICES,
        default='unknown'
    )

    outage_time = models.CharField(
        max_length=30,
        default='now'
    )

    scheduled_for = models.DateTimeField(
        null=True,
        blank=True
    )

    status = models.CharField(
    max_length=20,
    choices=[
        ('active', 'Active'),
        ('restored', 'Restored'),
        ('rejected', 'Rejected'),
    ],
    default='active'
)

    confirmations = models.PositiveIntegerField(default=0)

    reported_at = models.DateTimeField(auto_now_add=True)

    restored_at = models.DateTimeField(
        null=True,
        blank=True
    )

    class Meta:
        ordering = ['-reported_at']

    def __str__(self):
        return f"{self.area.name} - {self.status}"


class OutageConfirmation(models.Model):

    outage = models.ForeignKey(
        OutageReport,
        on_delete=models.CASCADE,
        related_name='confirmation_records'
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='outage_confirmations'
    )

    confirmed_at = models.DateTimeField(
        auto_now_add=True
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['outage', 'user'],
                name='unique_outage_confirmation'
            )
        ]
        ordering = ['-confirmed_at']

    def __str__(self):
        return f"{self.user.username} confirmed outage #{self.outage.id}"


class OutageVerification(models.Model):
    outage = models.ForeignKey(
        OutageReport,
        on_delete=models.CASCADE,
        related_name='verification_records'
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='outage_verifications'
    )

    is_accurate = models.BooleanField()

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['outage', 'user'],
                name='unique_outage_verification'
            )
        ]


class OutageUpdate(models.Model):
    outage = models.ForeignKey(
        OutageReport,
        on_delete=models.CASCADE,
        related_name='updates'
    )

    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='outage_updates'
    )

    message = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']