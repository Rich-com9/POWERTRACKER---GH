from rest_framework import generics, serializers
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import (
    IsAuthenticated,
    BasePermission,
)
from rest_framework.permissions import AllowAny
from rest_framework_simplejwt.views import TokenObtainPairView
from drf_spectacular.utils import extend_schema
from .permissions import IsAdminUser

from .serializers import (
    EmailTokenObtainPairSerializer,
    RegisterSerializer,
    ChangePasswordSerializer,
    PasswordResetRequestSerializer,
    PasswordResetConfirmSerializer,
    UserSerializer,
)
from .models import EmailVerificationCode, SavedArea
from .serializers import SavedAreaSerializer

from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import check_password, make_password
from django.core.mail import send_mail
from django.db.models import Count
from django.utils import timezone
from datetime import timedelta
import secrets


from areas.models import Area
from outages.models import OutageReport, OutageConfirmation
from notifications.models import Notification


User = get_user_model()


class AdminDashboardSerializer(serializers.Serializer):
    users = serializers.IntegerField()
    areas = serializers.IntegerField()
    total_outages = serializers.IntegerField()
    active_outages = serializers.IntegerField()
    restored_outages = serializers.IntegerField()
    outages_today = serializers.IntegerField()
    total_confirmations = serializers.IntegerField()
    saved_areas = serializers.IntegerField()
    unread_notifications = serializers.IntegerField()


class AnalyticsSerializer(serializers.Serializer):
    total_outages = serializers.IntegerField()
    active_outages = serializers.IntegerField()
    restored_outages = serializers.IntegerField()
    average_outage_duration_hours = serializers.FloatField(allow_null=True)
    most_affected_area = serializers.CharField(allow_null=True)
    most_affected_area_count = serializers.IntegerField()


class EmailTokenObtainPairView(TokenObtainPairView):
    serializer_class = EmailTokenObtainPairSerializer


class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]


class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user


class ChangePasswordView(APIView):
    serializer_class = ChangePasswordSerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(request=ChangePasswordSerializer, responses={200: serializers.Serializer})
    def post(self, request):
        serializer = self.serializer_class(
            data=request.data,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        request.user.set_password(serializer.validated_data['new_password'])
        request.user.save(update_fields=['password'])
        return Response({'message': 'Password changed successfully.'})


class PasswordResetRequestView(APIView):
    serializer_class = PasswordResetRequestSerializer
    permission_classes = [AllowAny]

    @extend_schema(request=PasswordResetRequestSerializer)
    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = User.objects.filter(
            email__iexact=serializer.validated_data['email'],
            is_active=True,
        ).first()

        if user and user.has_usable_password():
            _send_email_code(user, EmailVerificationCode.PASSWORD_RESET)

        return Response({
            'message': 'If an eligible account exists, a code has been sent.'
        })


class PasswordResetConfirmView(APIView):
    serializer_class = PasswordResetConfirmSerializer
    permission_classes = [AllowAny]

    @extend_schema(request=PasswordResetConfirmSerializer)
    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = User.objects.filter(
            email__iexact=serializer.validated_data['email'],
            is_active=True,
        ).first()
        code = EmailVerificationCode.objects.filter(
            user=user,
            purpose=EmailVerificationCode.PASSWORD_RESET,
        ).first() if user else None
        if not _valid_email_code(code, serializer.validated_data['code']):
            if code:
                code.attempts += 1
                code.save(update_fields=['attempts'])
            raise serializers.ValidationError({
                'code': 'Invalid or expired reset code.'
            })

        user.set_password(serializer.validated_data['new_password'])
        user.save(update_fields=['password'])
        code.delete()
        return Response({'message': 'Password reset successfully.'})


def _send_email_code(user, purpose):
    existing = EmailVerificationCode.objects.filter(
        user=user,
        purpose=purpose,
        created_at__gte=timezone.now() - timedelta(seconds=60),
    ).first()
    if existing:
        return
    code = f'{secrets.randbelow(1000000):06d}'
    EmailVerificationCode.objects.filter(user=user, purpose=purpose).delete()
    EmailVerificationCode.objects.create(
        user=user,
        purpose=purpose,
        code_hash=make_password(code),
        expires_at=timezone.now() + timedelta(minutes=10),
    )
    send_mail(
        'Reset your PowerTracker password',
        f'Your PowerTracker GH code is {code}. It expires in 10 minutes.',
        None,
        [user.email],
        fail_silently=False,
    )

def _valid_email_code(code, raw_code):
    return bool(
        code
        and code.expires_at > timezone.now()
        and code.attempts < 5
        and check_password(raw_code, code.code_hash)
    )


class SavedAreaListCreateView(generics.ListCreateAPIView):

    serializer_class = SavedAreaSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return SavedArea.objects.filter(
            user=self.request.user
        ).select_related('area')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class SavedAreaDeleteView(generics.DestroyAPIView):

    serializer_class = SavedAreaSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return SavedArea.objects.filter(
            user=self.request.user
        )
        
class AdminDashboardView(APIView):

    serializer_class = AdminDashboardSerializer
    permission_classes = [IsAdminUser]

    @extend_schema(responses=AdminDashboardSerializer)
    def get(self, request):

        User = get_user_model()

        today = timezone.localdate()

        total_users = User.objects.count()

        total_areas = Area.objects.count()

        total_outages = OutageReport.objects.count()

        active_outages = OutageReport.objects.filter(
            status='active'
        ).count()

        restored_outages = OutageReport.objects.filter(
            status='restored'
        ).count()

        outages_today = OutageReport.objects.filter(
            reported_at__date=today
        ).count()

        total_confirmations = OutageConfirmation.objects.count()

        total_saved_areas = SavedArea.objects.count()

        unread_notifications = Notification.objects.filter(
            is_read=False
        ).count()

        return Response(
            {
                'users': total_users,
                'areas': total_areas,
                'total_outages': total_outages,
                'active_outages': active_outages,
                'restored_outages': restored_outages,
                'outages_today': outages_today,
                'total_confirmations': total_confirmations,
                'saved_areas': total_saved_areas,
                'unread_notifications': unread_notifications,
            }
        )


class AnalyticsView(APIView):

    serializer_class = AnalyticsSerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(responses=AnalyticsSerializer)
    def get(self, request):
        outages = OutageReport.objects.select_related('area')
        if not request.user.is_staff:
            outages = outages.filter(reported_by=request.user)
        restored_outages = outages.filter(
            status='restored',
            restored_at__isnull=False,
        )

        durations = [
            (outage.restored_at - outage.reported_at).total_seconds()
            for outage in restored_outages
        ]
        average_duration_hours = (
            sum(durations) / len(durations) / 3600
            if durations else None
        )

        affected_area = (
            outages.values('area__name')
            .annotate(total=Count('id'))
            .order_by('-total', 'area__name')
            .first()
        )

        return Response(
            {
                'total_outages': outages.count(),
                'active_outages': outages.filter(status='active').count(),
                'restored_outages': restored_outages.count(),
                'average_outage_duration_hours': average_duration_hours,
                'most_affected_area': (
                    affected_area['area__name']
                    if affected_area else None
                ),
                'most_affected_area_count': (
                    affected_area['total']
                    if affected_area else 0
                ),
            }
        )
