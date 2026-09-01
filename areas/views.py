from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from .models import Area
from .serializers import AreaSerializer


class AreaListCreateView(generics.ListCreateAPIView):
    queryset = Area.objects.all()
    serializer_class = AreaSerializer
    permission_classes = [IsAuthenticated]


class AreaDetailView(generics.RetrieveAPIView):
    queryset = Area.objects.all()
    serializer_class = AreaSerializer
    permission_classes = [IsAuthenticated]
    
    