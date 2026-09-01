from django.contrib import admin

from .models import Area


@admin.register(Area)
class AreaAdmin(admin.ModelAdmin):

    list_display = (
        'id',
        'name',
        'region',
    )

    list_filter = (
        'region',
    )

    search_fields = (
        'name',
        'region',
    )