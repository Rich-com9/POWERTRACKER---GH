from rest_framework import serializers

from .models import Area


class AreaSerializer(serializers.ModelSerializer):

    class Meta:
        model = Area
        fields = [
            'id',
            'name',
            'region',
            'active_outage_count',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'active_outage_count',
            'created_at',
            'updated_at',
        ]