from django.urls import path

from .views import (
    AreaListCreateView,
    AreaDetailView,
)

urlpatterns = [
    path('', AreaListCreateView.as_view(), name='area-list-create'),
    path('<int:pk>/', AreaDetailView.as_view(), name='area-detail'),
]