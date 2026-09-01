from django.urls import path

from .views import (
    NotificationListView,
    MarkNotificationReadView,
    DeviceTokenView,
)


urlpatterns = [
    path(
        '',
        NotificationListView.as_view(),
        name='notification-list'
    ),

    path(
        '<int:pk>/read/',
        MarkNotificationReadView.as_view(),
        name='notification-read'
    ),
    path(
        'device-token/',
        DeviceTokenView.as_view(),
        name='device-token',
    ),
]