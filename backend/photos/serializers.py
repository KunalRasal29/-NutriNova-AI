from __future__ import annotations

from django.utils import timezone
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from foods.models import Food
from foods.serializers import FoodSearchResultSerializer
from meals.models import MealLog
from meals.serializers import MealLogSerializer
from photos.models import NutritionLabelScan, PhotoAnalysis, PhotoDetectedFood
from photos.providers import PHOTO_DISCLAIMER
from photos.services.photo_nutrition_preview import visible_foods_for_user
from photos.validators import validate_uploaded_image


class PhotoAnalysisUploadSerializer(serializers.Serializer):
    image = serializers.ImageField()

    def validate_image(self, value):
        return validate_uploaded_image(value)


class PhotoDetectedFoodSerializer(serializers.ModelSerializer):
    matched_food_detail = FoodSearchResultSerializer(
        source="matched_food",
        read_only=True,
    )

    class Meta:
        model = PhotoDetectedFood
        fields = (
            "id",
            "detected_name",
            "normalized_name",
            "matched_food",
            "matched_food_detail",
            "quantity_estimate",
            "unit_estimate",
            "quantity_value",
            "quantity_unit",
            "grams_estimate",
            "grams_per_unit_estimate",
            "total_grams_estimate",
            "min_total_grams_estimate",
            "max_total_grams_estimate",
            "confidence_score",
            "count_confidence",
            "portion_confidence",
            "bounding_box",
            "user_confirmed",
            "user_corrected_name",
            "user_quantity_value",
            "user_quantity_unit",
            "user_corrected_grams",
            "user_total_grams",
            "is_user_corrected",
            "is_removed",
            "correction_note",
            "nutrition_preview_snapshot",
            "added_manually",
            "reasoning_short",
        )
        read_only_fields = fields


class NutritionLabelScanSerializer(serializers.ModelSerializer):
    class Meta:
        model = NutritionLabelScan
        fields = (
            "id",
            "product_name",
            "brand",
            "serving_size",
            "barcode",
            "parsed_nutrients",
            "ingredients_text",
            "allergens",
            "confidence_score",
        )


class PhotoAnalysisDetailSerializer(serializers.ModelSerializer):
    detected_foods = PhotoDetectedFoodSerializer(many=True, read_only=True)
    nutrition_label_scan = NutritionLabelScanSerializer(read_only=True)
    image_url = serializers.SerializerMethodField()
    disclaimer = serializers.SerializerMethodField()
    review_reasons = serializers.SerializerMethodField()

    class Meta:
        model = PhotoAnalysis
        fields = (
            "id",
            "image",
            "image_url",
            "status",
            "analysis_type",
            "ai_provider",
            "raw_ai_response",
            "confidence_score",
            "error_message",
            "detected_foods",
            "nutrition_label_scan",
            "disclaimer",
            "review_reasons",
            "created_at",
            "updated_at",
        )
        read_only_fields = fields

    @extend_schema_field(serializers.CharField)
    def get_image_url(self, obj):
        request = self.context.get("request")
        if not obj.image:
            return ""
        url = obj.image.url
        return request.build_absolute_uri(url) if request else url

    @extend_schema_field(serializers.CharField)
    def get_disclaimer(self, obj):
        return PHOTO_DISCLAIMER

    @extend_schema_field(serializers.JSONField)
    def get_review_reasons(self, obj):
        return obj.raw_ai_response.get("review_reasons", [])


class ConfirmDetectedFoodSerializer(serializers.Serializer):
    detected_food = serializers.UUIDField()
    matched_food = serializers.UUIDField(
        required=False,
        allow_null=True,
    )
    user_confirmed = serializers.BooleanField(default=True)
    user_quantity_value = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
    )
    user_quantity_unit = serializers.ChoiceField(
        choices=PhotoDetectedFood.QuantityUnit.choices,
        required=False,
        allow_null=True,
    )
    user_total_grams = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
    )
    user_corrected_name = serializers.CharField(
        max_length=255,
        required=False,
        allow_blank=True,
    )
    user_corrected_grams = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
    )
    is_removed = serializers.BooleanField(required=False)
    correction_note = serializers.CharField(required=False, allow_blank=True)


class ConfirmPhotoMealSerializer(serializers.Serializer):
    date = serializers.DateField(default=timezone.localdate)
    meal_type = serializers.ChoiceField(
        choices=MealLog.MealType.choices,
        default=MealLog.MealType.CUSTOM,
    )
    name = serializers.CharField(max_length=160, required=False, allow_blank=True)
    notes = serializers.CharField(required=False, allow_blank=True)
    timezone = serializers.CharField(max_length=64, required=False, allow_blank=True)
    items = ConfirmDetectedFoodSerializer(many=True, required=False)


class MatchFoodsResponseSerializer(serializers.Serializer):
    analysis = PhotoAnalysisDetailSerializer()


class ConfirmPhotoMealResponseSerializer(serializers.Serializer):
    meal = MealLogSerializer()
    disclaimer = serializers.CharField()


class ConfirmLabelFoodResponseSerializer(serializers.Serializer):
    food = serializers.JSONField()
    disclaimer = serializers.CharField()


class PhotoDetectedFoodUpdateSerializer(serializers.Serializer):
    user_quantity_value = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
    )
    user_quantity_unit = serializers.ChoiceField(
        choices=PhotoDetectedFood.QuantityUnit.choices,
        required=False,
        allow_null=True,
    )
    user_total_grams = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
    )
    matched_food = serializers.PrimaryKeyRelatedField(
        queryset=Food.objects.none(),
        required=False,
        allow_null=True,
    )
    is_removed = serializers.BooleanField(required=False)
    correction_note = serializers.CharField(required=False, allow_blank=True)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request:
            self.fields["matched_food"].queryset = visible_foods_for_user(request.user)


class ManualPhotoFoodAddSerializer(serializers.Serializer):
    food_id = serializers.PrimaryKeyRelatedField(
        source="food",
        queryset=Food.objects.none(),
    )
    quantity_value = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
    )
    quantity_unit = serializers.ChoiceField(
        choices=PhotoDetectedFood.QuantityUnit.choices,
        required=False,
        allow_null=True,
    )
    total_grams = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request:
            self.fields["food_id"].queryset = visible_foods_for_user(request.user)


class PhotoReviewResponseSerializer(serializers.Serializer):
    analysis_id = serializers.UUIDField()
    status = serializers.CharField()
    image_url = serializers.CharField()
    disclaimer = serializers.CharField()
    items = serializers.JSONField()
    total_preview = serializers.JSONField()
    warnings = serializers.JSONField()
