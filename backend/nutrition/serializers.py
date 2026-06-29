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
