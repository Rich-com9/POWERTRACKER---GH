from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from .models import DeviceToken, Notification
from .serializers import NotificationSerializer


class NotificationListView(generics.ListAPIView):

    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(
            user=self.request.user
        ).select_related('outage')


class MarkNotificationReadView(generics.UpdateAPIView):

    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(
            user=self.request.user
        )

    def perform_update(self, serializer):
        serializer.save(is_read=True)


class DeviceTokenView(generics.CreateAPIView):
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):
        token = request.data.get('token')
        platform = request.data.get('platform', 'android')

        if not token:
            return Response(
                {'detail': 'token is required.'},
                status=400,
            )

        DeviceToken.objects.update_or_create(
            token=token,
            defaults={
                'user': request.user,
                'platform': platform,
            },
        )
        return Response({'message': 'Device token registered.'})