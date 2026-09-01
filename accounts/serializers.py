from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from .models import SavedArea


User = get_user_model()


class EmailTokenObtainPairSerializer(TokenObtainPairSerializer):
    email = serializers.EmailField(required=False, allow_blank=True)
    username = serializers.CharField(required=False, allow_blank=True)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['username'].required = False
        self.fields['email'].required = False

    def validate(self, attrs):
        email = attrs.get('email')
        username = attrs.get('username')
        password = attrs.get('password')

        if email and not username and password:
            user = User.objects.filter(email__iexact=email).first()
            if user is not None:
                attrs['username'] = user.get_username()
                attrs.pop('email', None)

        try:
            data = super().validate(attrs)
        except AuthenticationFailed:
            raise AuthenticationFailed(
                'Incorrect username/email or password.',
                code='invalid_credentials',
            )

        return data


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True,
        min_length=8
    )
    phone = serializers.CharField(max_length=20)

    class Meta:
        model = User
        fields = [
            'username',
            'name',
            'email',
            'phone',
            'password',
        ]

    def create(self, validated_data):
        password = validated_data.pop('password')
        validated_data['phone_verified'] = True
        user = User.objects.create_user(
            password=password,
            **validated_data
        )

        return user


class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=8)
    confirm_password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError({
                'confirm_password': 'Passwords do not match.'
            })
        if not self.context['request'].user.check_password(
            attrs['current_password']
        ):
            raise serializers.ValidationError({
                'current_password': 'Current password is incorrect.'
            })
        return attrs


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordResetConfirmSerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(min_length=6, max_length=6)
    new_password = serializers.CharField(write_only=True, min_length=8)
    confirm_password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError({
                'confirm_password': 'Passwords do not match.'
            })
        validate_password(attrs['new_password'])
        return attrs


class EmailVerificationConfirmSerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(min_length=6, max_length=6)


class EmailVerificationRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class UserSerializer(serializers.ModelSerializer):

    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'name',
            'email',
            'phone',
            'phone_verified',
            'is_staff',
        ]

        read_only_fields = [
            'is_staff',
            'phone_verified',
        ]

class SavedAreaSerializer(serializers.ModelSerializer):

    area_name = serializers.CharField(
        source='area.name',
        read_only=True
    )

    region = serializers.CharField(
        source='area.region',
        read_only=True
    )

    class Meta:
        model = SavedArea

        fields = [
            'id',
            'area',
            'area_name',
            'region',
            'created_at',
        ]

        read_only_fields = [
            'id',
            'area_name',
            'region',
            'created_at',
        ]
