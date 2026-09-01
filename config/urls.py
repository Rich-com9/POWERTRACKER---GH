from django.contrib import admin
from django.conf import settings
from django.conf.urls.static import static
from django.urls import include, path

from accounts.views import EmailTokenObtainPairView
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
)

from rest_framework_simplejwt.views import TokenRefreshView


urlpatterns = [

    # Django Admin
    path('admin/', admin.site.urls),

    # API
    path(
        'api/auth/token/',
        EmailTokenObtainPairView.as_view(),
        name='token_obtain_pair',
    ),

    path(
        'api/auth/login/',
        EmailTokenObtainPairView.as_view(),
        name='token_obtain_pair_alias',
    ),

    path(
        'api/auth/token/refresh/',
        TokenRefreshView.as_view(),
        name='token_refresh'
    ),

    path(
        'api/auth/',
        include('accounts.urls')
    ),

    path(
        'api/areas/',
        include('areas.urls')
    ),

    path(
        'api/outages/',
        include('outages.urls')
    ),

    path(
        'api/notifications/',
        include('notifications.urls')
    ),

    # API Documentation
    path(
        'api/schema/',
        SpectacularAPIView.as_view(),
        name='schema',
    ),

    path(
        'api/docs/',
        SpectacularSwaggerView.as_view(
            url_name='schema'
        ),
        name='swagger-ui',
    ),
]

urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)