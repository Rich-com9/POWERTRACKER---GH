from django.db import models


class Area(models.Model):
    name = models.CharField(max_length=150)

    region = models.CharField(max_length=100)

    active_outage_count = models.PositiveIntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.name}, {self.region}"