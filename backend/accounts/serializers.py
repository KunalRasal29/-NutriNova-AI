from django.contrib.auth import authenticate, get_user_model
from django.db import transaction
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from profiles.models import UserProfile

User = get_user_model()


PROFILE_FIELD_NAMES = (
    "display_name",
    "date_of_birth",
    "gender_optional",
    "height_cm",
    "weight_kg",
    "activity_level",
    "goal_type",
    "dietary_preference",
    "allergies",
    "disliked_foods",
    "target_weight_kg",
    "daily_calorie_target_kcal",
    "daily_protein_target_g",
    "daily_carbs_target_g",
    "daily_fat_target_g",
    "daily_fiber_target_g",
    "daily_water_target_ml",
    "nutrition_targets_customized",
    "nutrition_target_method",
    "nutrition_targets_calculated_at",
    "timezone",
    "country",
    "has_completed_onboarding",
    "onboarding_step",
)


class LowercaseChoiceField(serializers.ChoiceField):
    def to_internal_value(self, data):
        if isinstance(data, str):
            data = data.lower()
        return super().to_internal_value(data)


def tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {
        "access": str(refresh.access_token),
        "refresh": str(refresh),
    }


class RegisterSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(
        write_only=True, min_length=8, trim_whitespace=False
    )
    display_name = serializers.CharField(
        max_length=160, required=False, allow_blank=True
    )
    timezone = serializers.CharField(max_length=64, required=False, default="UTC")
    country = serializers.CharField(max_length=2, required=False, default="IN")

    def validate_email(self, value):
        email = User.objects.normalize_email(value).lower()
        if User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return email

    def validate_country(self, value):
        return value.upper()

    @transaction.atomic
    def create(self, validated_data):
        profile_data = {
            "display_name": validated_data.pop("display_name", ""),
            "timezone": validated_data.pop("timezone", "UTC"),
            "country": validated_data.pop("country", "IN").upper(),
        }
        email = validated_data["email"]
        user = User.objects.create_user(
            username=email,
            email=email,
            password=validated_data["password"],
            timezone=profile_data["timezone"],
        )
        UserProfile.objects.update_or_create(user=user, defaults=profile_data)
        return user

    def to_representation(self, instance):
        return AuthTokenResponseSerializer(instance).data


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate(self, attrs):
        email = attrs["email"].lower()
        password = attrs["password"]

        try:
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist as exc:
            raise serializers.ValidationError("Invalid email or password.") from exc

        authenticated_user = authenticate(
            request=self.context.get("request"),
            username=user.username,
            password=password,
        )
        if authenticated_user is None:
            raise serializers.ValidationError("Invalid email or password.")
        if not authenticated_user.is_active:
            raise serializers.ValidationError("This account is inactive.")

        attrs["user"] = authenticated_user
        return attrs

    def create(self, validated_data):
        return validated_data["user"]

    def to_representation(self, instance):
        return AuthTokenResponseSerializer(instance).data


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField(write_only=True)

    def validate_refresh(self, value):
        try:
            token = RefreshToken(value)
            token.blacklist()
        except Exception as exc:
            raise serializers.ValidationError(
                "Invalid or expired refresh token."
            ) from exc
        return value


class ProfilePayloadSerializer(serializers.Serializer):
    display_name = serializers.CharField(allow_blank=True)
    date_of_birth = serializers.DateField(allow_null=True)
    gender_optional = serializers.ChoiceField(
        choices=UserProfile.GenderOptional.choices,
        allow_blank=True,
    )
    height_cm = serializers.DecimalField(
        max_digits=5, decimal_places=2, allow_null=True
    )
    weight_kg = serializers.DecimalField(
        max_digits=6, decimal_places=2, allow_null=True
    )
    activity_level = serializers.ChoiceField(choices=UserProfile.ActivityLevel.choices)
    goal_type = serializers.ChoiceField(choices=UserProfile.GoalType.choices)
    dietary_preference = LowercaseChoiceField(
        choices=UserProfile.DietaryPreference.choices
    )
    allergies = serializers.ListField(child=serializers.CharField(max_length=120))
    disliked_foods = serializers.ListField(child=serializers.CharField(max_length=120))
    target_weight_kg = serializers.DecimalField(
        max_digits=6,
        decimal_places=2,
        allow_null=True,
    )
    daily_calorie_target_kcal = serializers.DecimalField(
        max_digits=7,
        decimal_places=1,
        read_only=True,
        allow_null=True,
    )
    daily_protein_target_g = serializers.DecimalField(
        max_digits=6,
        decimal_places=1,
        read_only=True,
        allow_null=True,
    )
    daily_carbs_target_g = serializers.DecimalField(
        max_digits=6,
        decimal_places=1,
        read_only=True,
        allow_null=True,
    )
    daily_fat_target_g = serializers.DecimalField(
        max_digits=6,
        decimal_places=1,
        read_only=True,
        allow_null=True,
    )
    daily_fiber_target_g = serializers.DecimalField(
        max_digits=5,
        decimal_places=1,
        read_only=True,
        allow_null=True,
    )
    daily_water_target_ml = serializers.DecimalField(
        max_digits=7,
        decimal_places=1,
        read_only=True,
        allow_null=True,
    )
    nutrition_targets_customized = serializers.BooleanField(read_only=True)
    nutrition_target_method = serializers.CharField(read_only=True)
    nutrition_targets_calculated_at = serializers.DateTimeField(
        read_only=True,
        allow_null=True,
    )
    timezone = serializers.CharField(max_length=64)
    country = serializers.CharField(max_length=2)
    has_completed_onboarding = serializers.BooleanField()
    onboarding_step = serializers.IntegerField(min_value=0, max_value=50)


class MeSerializer(serializers.Serializer):
    id = serializers.UUIDField(read_only=True)
    email = serializers.EmailField(read_only=True)
    profile_id = serializers.UUIDField(read_only=True)
    display_name = serializers.CharField(
        max_length=160,
        required=False,
        allow_blank=True,
    )
    date_of_birth = serializers.DateField(required=False, allow_null=True)
    gender_optional = serializers.ChoiceField(
        choices=UserProfile.GenderOptional.choices,
        required=False,
        allow_blank=True,
    )
    height_cm = serializers.DecimalField(
        max_digits=5,
        decimal_places=2,
        required=False,
        allow_null=True,
    )
    weight_kg = serializers.DecimalField(
        max_digits=6,
        decimal_places=2,
        required=False,
        allow_null=True,
    )
    activity_level = serializers.ChoiceField(
        choices=UserProfile.ActivityLevel.choices,
        required=False,
    )
    goal_type = serializers.ChoiceField(
        choices=UserProfile.GoalType.choices,
        required=False,
    )
    dietary_preference = LowercaseChoiceField(
        choices=UserProfile.DietaryPreference.choices,
        required=False,
    )
    allergies = serializers.ListField(
        child=serializers.CharField(max_length=120),
        required=False,
    )
    disliked_foods = serializers.ListField(
        child=serializers.CharField(max_length=120),
        required=False,
    )
    target_weight_kg = serializers.DecimalField(
        max_digits=6,
        decimal_places=2,
        required=False,
        allow_null=True,
    )
    daily_calorie_target_kcal = serializers.DecimalField(
        max_digits=7,
        decimal_places=1,
        read_only=True,
        allow_null=True,
    )
    daily_protein_target_g = serializers.DecimalField(
        max_digits=6,
        decimal_places=1,
        read_only=True,
        allow_null=True,
    )
    daily_carbs_target_g = serializers.DecimalField(
        max_digits=6,
        decimal_places=1,
        read_only=True,
        allow_null=True,
    )
    daily_fat_target_g = serializers.DecimalField(
        max_digits=6,
        decimal_places=1,
        read_only=True,
        allow_null=True,
    )
    daily_fiber_target_g = serializers.DecimalField(
        max_digits=5,
        decimal_places=1,
        read_only=True,
        allow_null=True,
    )
    daily_water_target_ml = serializers.DecimalField(
        max_digits=7,
        decimal_places=1,
        read_only=True,
        allow_null=True,
    )
    nutrition_targets_customized = serializers.BooleanField(read_only=True)
    nutrition_target_method = serializers.CharField(read_only=True)
    nutrition_targets_calculated_at = serializers.DateTimeField(
        read_only=True,
        allow_null=True,
    )
    timezone = serializers.CharField(max_length=64, required=False)
    country = serializers.CharField(max_length=2, required=False)
    has_completed_onboarding = serializers.BooleanField(required=False)
    onboarding_step = serializers.IntegerField(
        required=False, min_value=0, max_value=50
    )
    created_at = serializers.DateTimeField(read_only=True)
    updated_at = serializers.DateTimeField(read_only=True)

    def validate_country(self, value):
        return value.upper()

    def to_representation(self, instance):
        profile, _ = UserProfile.objects.get_or_create(
            user=instance,
            defaults={"timezone": instance.timezone},
        )
        data = {
            "id": instance.id,
            "email": instance.email,
            "profile_id": profile.id,
            "created_at": profile.created_at,
            "updated_at": profile.updated_at,
        }
        for field_name in PROFILE_FIELD_NAMES:
            data[field_name] = getattr(profile, field_name)
        return super().to_representation(data)

    @transaction.atomic
    def update(self, instance, validated_data):
        profile, _ = UserProfile.objects.get_or_create(
            user=instance,
            defaults={"timezone": instance.timezone},
        )
        was_onboarded = profile.has_completed_onboarding
        for field_name, value in validated_data.items():
            setattr(profile, field_name, value)
            if field_name == "timezone":
                instance.timezone = value
        if "timezone" in validated_data:
            instance.save(update_fields=("timezone", "updated_at"))
        profile.save()
        if profile.has_completed_onboarding and not was_onboarded:
            from nutrition.targets import save_initial_estimate

            save_initial_estimate(profile)
        return instance


class AuthTokenResponseSerializer(serializers.Serializer):
    user = MeSerializer(read_only=True)
    access = serializers.CharField()
    refresh = serializers.CharField()

    def to_representation(self, instance):
        return {
            "user": MeSerializer(instance).data,
            **tokens_for_user(instance),
        }
