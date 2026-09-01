from django.urls import path

from .views import (
    OutageListCreateView,
    OutageDetailView,
    ConfirmOutageView,
    ResolveOutageView,
    ActiveOutageListView,
    RejectOutageView,
    VerifyOutageView,
    ScheduledOutageCreateView,
    OutageUpdateCreateView,
    LatestUpdatesView,
)


urlpatterns = [
    path(
        '',
        OutageListCreateView.as_view(),
        name='outage-list-create'
    ),

    path(
        'active/',
        ActiveOutageListView.as_view(),
        name='active-outages'
    ),

    path(
        'latest/',
        LatestUpdatesView.as_view(),
        name='latest-updates',
    ),

    path(
        'scheduled/',
        ScheduledOutageCreateView.as_view(),
        name='scheduled-outage-create'
    ),

    path(
        '<int:pk>/',
        OutageDetailView.as_view(),
        name='outage-detail'
    ),

    path(
        '<int:pk>/confirm/',
        ConfirmOutageView.as_view(),
        name='outage-confirm'
    ),

    path(
        '<int:pk>/updates/',
        OutageUpdateCreateView.as_view(),
        name='outage-update-create',
    ),

    path(
        '<int:pk>/resolve/',
        ResolveOutageView.as_view(),
        name='outage-resolve'
    ),

    path(
        '<int:pk>/verify/',
        VerifyOutageView.as_view(),
        name='outage-verify'
    ),
    
    path(
    '<int:pk>/reject/',
    RejectOutageView.as_view(),
    name='outage-reject'
),
    
]