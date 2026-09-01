from django.urls import path

from .views import (
    RegisterView,
    ProfileView,
    ChangePasswordView,
    PasswordResetRequestView,
    PasswordResetConfirmView,
    EmailVerificationConfirmView,
    EmailVerificationRequestView,
    SavedAreaListCreateView,
    SavedAreaDeleteView,
    AdminDashboardView,
    AnalyticsView,
)


urlpatterns = [
    path(
    'register/', 
    RegisterView.as_view(), 
    name='register'
    ),
    
    path(
    'profile/', 
    ProfileView.as_view(), 
    name='profile'),

path(
    'change-password/',
    ChangePasswordView.as_view(),
    name='change-password'),

path(
    'password-reset/request/',
    PasswordResetRequestView.as_view(),
    name='password-reset-request'),

path(
    'password-reset/confirm/',
    PasswordResetConfirmView.as_view(),
    name='password-reset-confirm'),

path(
    'email-verification/confirm/',
    EmailVerificationConfirmView.as_view(),
    name='email-verification-confirm'),

path(
    'email-verification/request/',
    EmailVerificationRequestView.as_view(),
    name='email-verification-request'),

    path(
    'saved-areas/',
    SavedAreaListCreateView.as_view(),
    name='saved-area-list-create'
),

path(
    'saved-areas/<int:pk>/',
    SavedAreaDeleteView.as_view(),
    name='saved-area-delete'
),

path(
    'admin/dashboard/',
    AdminDashboardView.as_view(),
    name='admin-dashboard'
),

path(
    'analytics/',
    AnalyticsView.as_view(),
    name='analytics',
),

]
