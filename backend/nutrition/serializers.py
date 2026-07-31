from rest_framework import serializers

from nutrition.models import Nutrient, NutritionDataSource


class NutritionDataSourceSerializer(serializers.ModelSerializer):
    class Meta:
        model = NutritionDataSource
        fields = (
            "id",
            "name",
            "source_type",
            "license_name",
            "license_url",
            "citation",
            "source_url",
            "update_frequency",
            "reliability_score",
            "is_active",
            "created_at",
            "updated_at",
        )


class NutrientSerializer(serializers.ModelSerializer):
    class Meta:
        model = Nutrient
        fields = (
            "id",
            "code",
            "name",
            "unit",
            "nutrient_group",
            "recommended_daily_unit",
            "aliases",
            "created_at",
            "updated_at",
        )


class NutritionTargetUpdateSerializer(serializers.Serializer):
    calories_kcal = serializers.DecimalField(
        max_digits=7,
        decimal_places=1,
        min_value=1000,
        max_value=6000,
    )
    protein_g = serializers.DecimalField(
        max_digits=6,
        decimal_places=1,
        min_value=20,
        max_value=400,
    )
    carbs_g = serializers.DecimalField(
        max_digits=6,
        decimal_places=1,
        min_value=20,
        max_value=800,
    )
    fat_g = serializers.DecimalField(
        max_digits=6,
        decimal_places=1,
        min_value=20,
        max_value=300,
    )
    fiber_g = serializers.DecimalField(
        max_digits=5,
        decimal_places=1,
        min_value=5,
        max_value=100,
    )
    water_ml = serializers.DecimalField(
        max_digits=7,
        decimal_places=1,
        min_value=500,
        max_value=10000,
    )


class NutritionTargetConfirmationSerializer(serializers.Serializer):
    confirm = serializers.BooleanField()

    def validate_confirm(self, value):
        if not value:
            raise serializers.ValidationError(
                "Confirm before replacing the current targets."
            )
        return value
