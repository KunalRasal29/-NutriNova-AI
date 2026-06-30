from __future__ import annotations

from decimal import Decimal

from django.utils import timezone
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from foods.models import Food, FoodServing
from foods.services.custom_foods import visible_foods_for_user
from meals.models import DailyNutritionSummary, MealLog, MealLogItem
from meals.services import summary_payload
from meals.services.manual_add import MANUAL_QUANTITY_CHOICES
from nutrition.calculations import calculate_food_snapshot, calculate_grams_for_food


class MealLogItemSerializer(serializers.ModelSerializer):
    food_name = serializers.CharField(source="food.canonical_name", read_only=True)
    brand_name = serializers.CharField(source="food.brand_name", read_only=True)
    serving_name = serializers.CharField(source="serving.serving_name", read_only=True)
    food_source = serializers.SerializerMethodField()
    food_verified = serializers.BooleanField(source="food.verified", read_only=True)
    food_data_classification = serializers.SerializerMethodField()

    class Meta:
        model = MealLogItem
        fields = (
            "id",
            "meal_log",
            "food",
            "food_name",
            "brand_name",
            "food_source",
            "food_verified",
            "food_data_classification",
            "quantity",
            "unit",
            "grams_calculated",
            "serving",
            "serving_name",
            "calories_kcal",
            "macros_snapshot",
            "nutrients_snapshot",
            "source_confidence",
            "user_confirmed",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "meal_log",
            "food_name",
            "brand_name",
            "serving_name",
            "food_source",
            "food_verified",
            "food_data_classification",
            "calories_kcal",
            "macros_snapshot",
            "nutrients_snapshot",
            "source_confidence",
            "created_at",
            "updated_at",
        )
        extra_kwargs = {
            "grams_calculated": {"required": False},
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request:
            self.fields["food"].queryset = visible_foods_for_user(
                request.user
            ).prefetch_related("servings", "nutrients__nutrient", "nutrients__source")
        self.fields["serving"].queryset = FoodServing.objects.select_related("food")

    @extend_schema_field(serializers.JSONField)
    def get_food_source(self, obj):
        source = obj.food.source
        return {
            "name": source.name,
            "source_type": source.source_type,
            "reliability_score": source.reliability_score,
            "confidence_score": obj.source_confidence,
        }

    @extend_schema_field(serializers.CharField)
    def get_food_data_classification(self, obj):
        if obj.food.food_type == Food.FoodType.USER_CUSTOM:
            return "user_custom"
        if obj.food.source.source_type == "AI_ESTIMATE":
            return "ai_estimate"
        if obj.food.verified:
            return "official_verified"
        return "official_unverified"

    def validate(self, attrs):
        request = self.context["request"]
        instance = self.instance
        meal_log = self.context.get("meal_log")
        food = attrs.get("food") or getattr(instance, "food", None)
        if food is None:
            raise serializers.ValidationError({"food": "Food is required."})

        if meal_log and meal_log.user_id != request.user.id:
            raise serializers.ValidationError("Meal does not belong to this user.")

        serving = attrs.get("serving")
        if "serving" not in attrs and instance:
            serving = instance.serving
        if serving and serving.food_id != food.id:
            raise serializers.ValidationError(
                {"serving": "Serving does not belong to the selected food."}
            )

        quantity = attrs.get("quantity")
        if quantity is None and instance:
            quantity = instance.quantity
        unit = attrs.get("unit")
        if unit is None and instance:
            unit = instance.unit
        if unit is None:
            unit = MealLogItem.Unit.GRAMS
            attrs["unit"] = unit
        grams_input = attrs.get("grams_calculated")
        if "grams_calculated" not in attrs and instance:
            grams_input = instance.grams_calculated

        grams = calculate_grams_for_food(
            food=food,
            quantity=quantity,
            unit=unit,
            serving=serving,
            grams_calculated=grams_input,
        )
        snapshot = calculate_food_snapshot(food, grams)
        attrs["grams_calculated"] = grams
        attrs["calories_kcal"] = snapshot["calories_kcal"]
        attrs["macros_snapshot"] = snapshot["macros_snapshot"]
        attrs["nutrients_snapshot"] = snapshot["nutrients_snapshot"]
        attrs["source_confidence"] = snapshot["source_confidence"]
        return attrs

    def create(self, validated_data):
        request = self.context["request"]
        meal_log = self.context["meal_log"]
        return MealLogItem.objects.create(
            user=request.user,
            meal_log=meal_log,
            **validated_data,
        )


class MealLogSerializer(serializers.ModelSerializer):
    items = MealLogItemSerializer(many=True, read_only=True)

    class Meta:
        model = MealLog
        fields = (
            "id",
            "date",
            "meal_type",
            "name",
            "notes",
            "timezone",
            "is_favorite",
            "items",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "items", "created_at", "updated_at")

    def validate_timezone(self, value):
        return value or "UTC"

    def create(self, validated_data):
        request = self.context["request"]
        if not validated_data.get("timezone"):
            validated_data["timezone"] = getattr(request.user, "timezone", "UTC")
        return MealLog.objects.create(user=request.user, **validated_data)


class DailyNutritionSummarySerializer(serializers.ModelSerializer):
    macro_percentage_split = serializers.SerializerMethodField()
    daily_target_progress = serializers.SerializerMethodField()

    class Meta:
        model = DailyNutritionSummary
        fields = (
            "id",
            "date",
            "calories_kcal",
            "protein_g",
            "carbs_g",
            "fat_g",
            "fiber_g",
            "sugar_g",
            "sodium_mg",
            "micronutrients",
            "macro_percentage_split",
            "daily_target_progress",
            "generated_at",
        )

    @extend_schema_field(serializers.JSONField)
    def get_macro_percentage_split(self, obj):
        return summary_payload(obj)["macro_percentage_split"]

    @extend_schema_field(serializers.JSONField)
    def get_daily_target_progress(self, obj):
        return summary_payload(obj)["daily_target_progress"]


class CopyYesterdayMealsSerializer(serializers.Serializer):
    date = serializers.DateField()


class ManualMealAddSerializer(serializers.Serializer):
    meal_type = serializers.ChoiceField(
        choices=MealLog.MealType.choices,
        default=MealLog.MealType.SNACK,
    )
    date = serializers.DateField(default=timezone.localdate)
    food_id = serializers.PrimaryKeyRelatedField(
        source="food",
        queryset=Food.objects.none(),
    )
    quantity_value = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        min_value=Decimal("0.001"),
    )
    quantity_unit = serializers.ChoiceField(
        choices=MANUAL_QUANTITY_CHOICES,
        default="serving",
    )
    total_grams = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
        min_value=Decimal("0.001"),
    )
    timezone = serializers.CharField(max_length=64, required=False, allow_blank=True)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request:
            self.fields["food_id"].queryset = visible_foods_for_user(
                request.user
            ).prefetch_related("servings", "nutrients__nutrient", "nutrients__source")


class ManualMealAddResponseSerializer(serializers.Serializer):
    meal = MealLogSerializer()
    item = MealLogItemSerializer()
    preview = serializers.JSONField()


class QuickAddTextSerializer(serializers.Serializer):
    text = serializers.CharField()
    meal_type = serializers.ChoiceField(
        choices=MealLog.MealType.choices,
        default=MealLog.MealType.SNACK,
    )
    date = serializers.DateField(default=timezone.localdate)


class QuickAddConfirmItemSerializer(serializers.Serializer):
    raw_text = serializers.CharField(required=False, allow_blank=True)
    food_id = serializers.PrimaryKeyRelatedField(
        source="food",
        queryset=Food.objects.none(),
    )
    quantity_value = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        min_value=Decimal("0.001"),
    )
    quantity_unit = serializers.ChoiceField(
        choices=MANUAL_QUANTITY_CHOICES,
        default="serving",
    )
    effective_total_grams = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
        min_value=Decimal("0.001"),
    )
    total_grams = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
        min_value=Decimal("0.001"),
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request:
            self.fields["food_id"].queryset = visible_foods_for_user(
                request.user
            ).prefetch_related("servings", "nutrients__nutrient", "nutrients__source")


class QuickAddTextConfirmSerializer(serializers.Serializer):
    text = serializers.CharField(required=False, allow_blank=True)
    meal_type = serializers.ChoiceField(
        choices=MealLog.MealType.choices,
        default=MealLog.MealType.SNACK,
    )
    date = serializers.DateField(default=timezone.localdate)
    items = QuickAddConfirmItemSerializer(many=True, required=False)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request:
            self.fields["items"].child.fields["food_id"].queryset = (
                visible_foods_for_user(request.user).prefetch_related(
                    "servings",
                    "nutrients__nutrient",
                    "nutrients__source",
                )
            )

    def validate(self, attrs):
        if not attrs.get("text") and not attrs.get("items"):
            raise serializers.ValidationError(
                {"text": "Provide text or reviewed quick-add items."}
            )
        return attrs


class QuickAddTextResponseSerializer(serializers.Serializer):
    text = serializers.CharField()
    parsed_items = serializers.JSONField()
    confidence = serializers.DecimalField(max_digits=5, decimal_places=4)
    preview = serializers.JSONField()
    requires_review = serializers.BooleanField()


class QuickAddConfirmResponseSerializer(serializers.Serializer):
    meal = MealLogSerializer()
    items = MealLogItemSerializer(many=True)
    preview = serializers.JSONField()
