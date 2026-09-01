from django.contrib import admin

from .models import OutageConfirmation, OutageReport, OutageUpdate


@admin.register(OutageReport)
class OutageReportAdmin(admin.ModelAdmin):

    list_display = (
        'id',
        'area',
        'reported_by',
        'outage_type',
        'status',
        'reported_at',
        'restored_at',
    )

    list_filter = (
        'status',
        'outage_type',
        'area',
        'reported_at',
    )

    search_fields = (
        'description',
        'reported_by__username',
        'reported_by__email',
        'area__name',
    )

    readonly_fields = (
        'reported_at',
        'restored_at',
    )


@admin.register(OutageConfirmation)
class OutageConfirmationAdmin(admin.ModelAdmin):

    list_display = (
        'id',
        'outage',
        'user',
    )

    search_fields = (
        'user__username',
        'user__email',
        'outage__description',
    )


@admin.register(OutageUpdate)
class OutageUpdateAdmin(admin.ModelAdmin):
    list_display = ('outage', 'author', 'created_at')
    search_fields = ('message', 'author__username', 'outage__description')
    readonly_fields = ('created_at',)