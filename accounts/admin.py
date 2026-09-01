from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import SavedArea


from .models import User


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = (
        'username',
        'email',
        'name',
        'phone',
        'is_staff',
        'is_active',
    )

    search_fields = (
        'username',
        'email',
        'name',
        'phone',
    )
    
@admin.register(SavedArea)
class SavedAreaAdmin(admin.ModelAdmin):

    list_display = (
        'id',
        'user',
        'area',
        'created_at',
    )

    list_filter = (
        'area',
        'created_at',
    )

    search_fields = (
        'user__username',
        'user__email',
        'area__name',
    )

    readonly_fields = (
        'created_at',
    )