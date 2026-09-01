from rest_framework import serializers

from .models import OutageReport, OutageUpdate


class LatestUpdateSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    outage_id = serializers.IntegerField()
    area_name = serializers.CharField()
    title = serializers.CharField()
    message = serializers.CharField()
    update_type = serializers.CharField()
    status = serializers.CharField()
    created_at = serializers.DateTimeField()


class OutageUpdateSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(
        source='author.name',
        read_only=True
    )

    class Meta:
        model = OutageUpdate
        fields = [
            'id',
            'author',
            'author_name',
            'message',
            'created_at',
        ]
        read_only_fields = [
            'id',
            'author',
            'author_name',
            'created_at',
        ]


class OutageReportSerializer(serializers.ModelSerializer):

    reported_by_name = serializers.CharField(
        source='reported_by.name',
        read_only=True
    )

    area_name = serializers.CharField(
        source='area.name',
        read_only=True
    )

    accurate_votes = serializers.SerializerMethodField()
    inaccurate_votes = serializers.SerializerMethodField()
    updates = OutageUpdateSerializer(many=True, read_only=True)

    class Meta:
        model = OutageReport

        fields = [
            'id',
            'reported_by',
            'reported_by_name',
            'area',
            'area_name',
            'description',
            'location_address',
            'image',
            'latitude',
            'longitude',
            'outage_type',
            'outage_time',
            'scheduled_for',
            'status',
            'confirmations',
            'accurate_votes',
            'inaccurate_votes',
            'updates',
            'reported_at',
            'restored_at',
        ]

        read_only_fields = [
            'id',
            'reported_by',
            'reported_by_name',
            'area_name',
            'confirmations',
            'reported_at',
            'restored_at',
        ]

    def get_accurate_votes(self, obj):
        return obj.verification_records.filter(is_accurate=True).count()

    def get_inaccurate_votes(self, obj):
        return obj.verification_records.filter(is_accurate=False).count()