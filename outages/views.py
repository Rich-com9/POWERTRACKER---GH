from django.db import IntegrityError, transaction
from django.utils import timezone
from accounts.permissions import IsAdminUser

from rest_framework import generics, serializers, status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema

from accounts.models import SavedArea
from notifications.models import Notification
from notifications.push_service import send_push_notification

from .models import OutageConfirmation, OutageReport, OutageUpdate, OutageVerification
from .serializers import (
    LatestUpdateSerializer,
    OutageReportSerializer,
    OutageUpdateSerializer,
)


def _create_user_notification(
    *, user, notification_type, title, message, outage
):
    notification = Notification.objects.create(
        user=user,
        notification_type=notification_type,
        title=title,
        message=message,
        outage=outage,
    )

    send_push_notification(
        user=user,
        title=title,
        message=message,
        notification_type=notification_type,
        outage_id=outage.id,
    )

    return notification


class OutageConfirmationResponseSerializer(serializers.Serializer):
    message = serializers.CharField()
    outage_id = serializers.IntegerField()
    confirmations = serializers.IntegerField()


class OutageResolveResponseSerializer(serializers.Serializer):
    message = serializers.CharField()
    outage_id = serializers.IntegerField()
    status = serializers.CharField()
    restored_at = serializers.DateTimeField()


class OutageRejectResponseSerializer(serializers.Serializer):
    message = serializers.CharField()
    outage_id = serializers.IntegerField()
    status = serializers.CharField()


class OutageListCreateView(generics.ListCreateAPIView):

    queryset = OutageReport.objects.select_related(
        'reported_by',
        'area'
    )

    serializer_class = OutageReportSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def get_queryset(self):
        queryset = self.queryset.all()
        if not self.request.user.is_staff:
            queryset = queryset.filter(reported_by=self.request.user)
        return queryset

    def perform_create(self, serializer):

        outage = serializer.save(
            reported_by=self.request.user
        )

        saved_areas = SavedArea.objects.filter(
            area=outage.area
        ).select_related('user')

        for saved_area in saved_areas:

            if saved_area.user == self.request.user:
                continue

            _create_user_notification(
                user=saved_area.user,
                notification_type='outage',
                title='Power outage reported',
                message=(
                    f'A power outage has been reported in '
                    f'{outage.area.name}.'
                ),
                outage=outage,
            )


class LatestUpdatesView(generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = LatestUpdateSerializer

    def list(self, request, *args, **kwargs):
        events = []
        outages = OutageReport.objects.filter(
            status__in=['active', 'restored']
        ).select_related('area').prefetch_related('updates')

        for outage in outages:
            is_restored = outage.status == 'restored'
            events.append({
                'id': outage.id,
                'outage_id': outage.id,
                'area_name': outage.area.name,
                'title': 'Power restored' if is_restored else 'Power outage reported',
                'message': outage.description or (
                    f'An outage was reported in {outage.area.name}.'
                ),
                'update_type': 'restored' if is_restored else 'outage',
                'status': outage.status,
                'created_at': outage.restored_at if is_restored else outage.reported_at,
            })

            for update in outage.updates.all():
                events.append({
                    'id': update.id,
                    'outage_id': outage.id,
                    'area_name': outage.area.name,
                    'title': 'Official outage update',
                    'message': update.message,
                    'update_type': 'update',
                    'status': outage.status,
                    'created_at': update.created_at,
                })

        events.sort(key=lambda event: event['created_at'], reverse=True)
        serializer = self.get_serializer(events[:50], many=True)
        return Response(serializer.data)

class OutageDetailView(generics.RetrieveAPIView):

    queryset = OutageReport.objects.select_related(
        'reported_by',
        'area'
    )

    serializer_class = OutageReportSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = self.queryset.all()
        if not self.request.user.is_staff:
            queryset = queryset.filter(reported_by=self.request.user)
        return queryset


class OutageUpdateCreateView(generics.CreateAPIView):
    serializer_class = OutageUpdateSerializer
    permission_classes = [IsAdminUser]

    def perform_create(self, serializer):
        outage = OutageReport.objects.select_related(
            'reported_by',
            'area',
        ).get(pk=self.kwargs['pk'])
        update = serializer.save(
            outage=outage,
            author=self.request.user,
        )
        recipients = {outage.reported_by_id: outage.reported_by}
        for saved_area in SavedArea.objects.filter(
            area=outage.area
        ).select_related('user'):
            recipients[saved_area.user_id] = saved_area.user

        for user in recipients.values():
            _create_user_notification(
                user=user,
                notification_type='update',
                title='Update on your outage report',
                message=update.message,
                outage=outage,
            )


class ConfirmOutageView(APIView):

    serializer_class = OutageConfirmationResponseSerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(responses=OutageConfirmationResponseSerializer)
    def post(self, request, pk):

        try:
            outage = OutageReport.objects.get(pk=pk)
        except OutageReport.DoesNotExist:
            return Response(
                {'detail': 'Outage not found.'},
                status=status.HTTP_404_NOT_FOUND
            )

        if not request.user.is_staff and outage.reported_by_id != request.user.id:
            return Response(
                {'detail': 'You do not have access to this outage.'},
                status=status.HTTP_404_NOT_FOUND
            )

        if outage.status == 'restored':
            return Response(
                {'detail': 'This outage has already been restored.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            with transaction.atomic():
                OutageConfirmation.objects.create(
                    outage=outage,
                    user=request.user
                )
        except IntegrityError:
            return Response(
                {'detail': 'You have already confirmed this outage.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        outage.confirmations = outage.confirmation_records.count()
        outage.save(update_fields=['confirmations'])

        return Response(
            {
                'message': 'Outage confirmed successfully.',
                'outage_id': outage.id,
                'confirmations': outage.confirmations,
            },
            status=status.HTTP_200_OK
        )


class VerifyOutageView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            outage = OutageReport.objects.get(pk=pk)
        except OutageReport.DoesNotExist:
            return Response(
                {'detail': 'Outage not found.'},
                status=status.HTTP_404_NOT_FOUND
            )

        if not request.user.is_staff and outage.reported_by_id != request.user.id:
            return Response(
                {'detail': 'You do not have access to this outage.'},
                status=status.HTTP_404_NOT_FOUND
            )

        is_accurate = request.data.get('is_accurate')
        if not isinstance(is_accurate, bool):
            return Response(
                {'detail': 'is_accurate must be true or false.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if OutageVerification.objects.filter(
            outage=outage,
            user=request.user,
        ).exists():
            return Response(
                {'detail': 'You have already verified this outage.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        OutageVerification.objects.create(
            outage=outage,
            user=request.user,
            is_accurate=is_accurate,
        )

        return Response(
            {
                'message': 'Outage verification recorded.',
                'accurate_votes': outage.verification_records.filter(
                    is_accurate=True
                ).count(),
                'inaccurate_votes': outage.verification_records.filter(
                    is_accurate=False
                ).count(),
            },
            status=status.HTTP_201_CREATED
        )
        
class ResolveOutageView(APIView):

    serializer_class = OutageResolveResponseSerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(responses=OutageResolveResponseSerializer)
    def post(self, request, pk):

        try:
            outage = OutageReport.objects.select_related(
                'area'
            ).get(pk=pk)

        except OutageReport.DoesNotExist:
            return Response(
                {'detail': 'Outage not found.'},
                status=status.HTTP_404_NOT_FOUND
            )

        if not request.user.is_staff and outage.reported_by_id != request.user.id:
            return Response(
                {'detail': 'You do not have access to this outage.'},
                status=status.HTTP_404_NOT_FOUND
            )

        if outage.status == 'restored':
            return Response(
                {
                    'detail':
                    'This outage has already been restored.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        outage.status = 'restored'
        outage.restored_at = timezone.now()

        outage.save(
            update_fields=[
                'status',
                'restored_at',
            ]
        )

        saved_areas = SavedArea.objects.filter(
            area=outage.area
        ).select_related('user')

        for saved_area in saved_areas:

            if saved_area.user == request.user:
                continue

            _create_user_notification(
                user=saved_area.user,
                notification_type='restored',
                title='Power restored',
                message=(
                    f'Power has been restored in '
                    f'{outage.area.name}.'
                ),
                outage=outage,
            )

        return Response(
            {
                'message': 'Outage marked as restored.',
                'outage_id': outage.id,
                'status': outage.status,
                'restored_at': outage.restored_at,
            },
            status=status.HTTP_200_OK
        )
        
class ActiveOutageListView(generics.ListAPIView):

    serializer_class = OutageReportSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = OutageReport.objects.filter(
            status='active'
        ).select_related(
            'reported_by',
            'area'
        )

        if not self.request.user.is_staff:
            queryset = queryset.filter(reported_by=self.request.user)

        area_id = self.request.query_params.get('area')

        if area_id:
            queryset = queryset.filter(area_id=area_id)

        return queryset


class ScheduledOutageCreateView(generics.CreateAPIView):

    serializer_class = OutageReportSerializer
    permission_classes = [IsAdminUser]
    parser_classes = [FormParser, MultiPartParser]

    def perform_create(self, serializer):
        serializer.save(
            reported_by=self.request.user,
            outage_type='planned',
            outage_time='scheduled',
            status='active',
        )
    

class RejectOutageView(APIView):

    serializer_class = OutageRejectResponseSerializer
    permission_classes = [IsAdminUser]

    @extend_schema(responses=OutageRejectResponseSerializer)
    def post(self, request, pk):

        try:
            outage = OutageReport.objects.get(pk=pk)

        except OutageReport.DoesNotExist:
            return Response(
                {'detail': 'Outage not found.'},
                status=status.HTTP_404_NOT_FOUND
            )

        if outage.status == 'rejected':
            return Response(
                {'detail': 'This outage has already been rejected.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        outage.status = 'rejected'
        outage.save(update_fields=['status'])

        return Response(
            {
                'message': 'Outage report rejected.',
                'outage_id': outage.id,
                'status': outage.status,
            },
            status=status.HTTP_200_OK
        )

