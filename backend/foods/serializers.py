from decimal import Decimal

from django.utils import timezone
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from foods.models import (
    CustomFoodProfile,
    CustomFoodVersion,
    FavoriteFood,
    Food,
    FoodNutrient,
    FoodServing,
)
from foods.services.custom_foods import (
    CUSTOM_NUTRIENT_FIELDS,
    create_custom_food,
    normalize_custom_food_payload,
)
from foods.text import normalize_catalog_text
from meals.models import MealLog
from nutrition.models import Nutrient

SUMMARY_NUTRIENT_CODES = (
    "calories",
    "protein_g",
    "carbs_g",
    "fat_g",
    "fiber_g",
    "sugar_g",
    "sodium_mg",
    "calcium_mg",
    "iron_mg",
    "potassium_mg",
    "cholesterol_mg",
    "saturated_fat_g",
)


class FoodDefaultServingSummarySerializer(serializers.Serializer):
    description = serializers.CharField(allow_blank=True)
    grams = serializers.DecimalField(
        max_digits=8,
        decimal_places=2,
        allow_null=True,
    )


class FoodNutritionSummarySerializer(serializers.Serializer):
    calories = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        allow_null=True,
    )
    protein_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        allow_null=True,
    )
    carbs_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        allow_null=True,
    )
    fat_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        allow_null=True,
    )
    fiber_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        allow_null=True,
    )
    sugar_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        allow_null=True,
    )
    sodium_mg = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        allow_null=True,
    )
    calcium_mg = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        allow_null=True,
    )
    iron_mg = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        allow_null=True,
    )
    potassium_mg = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        allow_null=True,
    )
    cholesterol_mg = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        allow_null=True,
    )
    saturated_fat_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        allow_null=True,
    )


class FoodSourceSummarySerializer(serializers.Serializer):
    id = serializers.UUIDField()
    name = serializers.CharField()
    source_type = serializers.CharField()
    reliability_score = serializers.DecimalField(max_digits=5, decimal_places=4)


class FoodAliasOutputSerializer(serializers.Serializer):
    alias = serializers.CharField()
    language_code = serializers.CharField()


class FoodServingSerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodServing
        fields = (
            "id",
            "serving_name",
            "grams",
            "household_quantity",
            "is_default",
        )


class FoodNutrientSerializer(serializers.ModelSerializer):
    nutrient_code = serializers.CharField(source="nutrient.code")
    nutrient_name = serializers.CharField(source="nutrient.name")
    unit = serializers.CharField(source="nutrient.unit")
    source_name = serializers.CharField(source="source.name")
    source_type = serializers.CharField(source="source.source_type")

    class Meta:
        model = FoodNutrient
        fields = (
            "id",
            "nutrient_code",
            "nutrient_name",
            "unit",
            "amount_per_100g",
            "original_amount",
            "original_unit",
            "source_nutrient_id",
            "normalization_notes",
            "min_value",
            "max_value",
            "source_name",
            "source_type",
            "confidence_score",
            "derivation_method",
        )


class FoodSearchResultSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source="canonical_name")
    brand = serializers.CharField(source="brand_name")
    default_serving = serializers.SerializerMethodField()
    nutrition_per_100g = serializers.SerializerMethodField()
    data_source = serializers.CharField(source="source.name")
    source_type = serializers.CharField(source="source.source_type")
    source_badge = serializers.SerializerMethodField()
    confidence_score = serializers.SerializerMethodField()
    is_favorite = serializers.SerializerMethodField()
    data_classification = serializers.SerializerMethodField()
    personal_portion_preferences = serializers.SerializerMethodField()

    class Meta:
        model = Food
        fields = (
            "id",
            "name",
            "brand",
            "preparation_state",
            "dataset_type",
            "dataset_release",
            "ingredients_text",
            "allergens",
            "default_serving",
            "nutrition_per_100g",
            "data_source",
            "source_type",
            "source_badge",
            "confidence_score",
            "completeness_score",
            "quality_warnings",
            "verified",
            "data_classification",
            "is_favorite",
            "personal_portion_preferences",
        )

    @extend_schema_field(FoodDefaultServingSummarySerializer)
    def get_default_serving(self, obj):
        default_serving = next(
            (serving for serving in obj.servings.all() if serving.is_default),
            None,
        )
        if default_serving:
            return {
                "description": default_serving.serving_name,
                "grams": default_serving.grams,
            }
        return {
            "description": obj.serving_description,
            "grams": obj.default_serving_g,
        }

    @extend_schema_field(FoodNutritionSummarySerializer)
    def get_nutrition_per_100g(self, obj):
        values = {
            nutrient.nutrient.code: nutrient.amount_per_100g
            for nutrient in obj.nutrients.all()
            if nutrient.nutrient.code in SUMMARY_NUTRIENT_CODES
        }
        return {code: values.get(code) for code in SUMMARY_NUTRIENT_CODES}

    @extend_schema_field(serializers.DecimalField(max_digits=5, decimal_places=4))
    def get_confidence_score(self, obj):
        values = [
            nutrient.confidence_score
            for nutrient in obj.nutrients.all()
            if nutrient.nutrient.code in SUMMARY_NUTRIENT_CODES
        ]
        if not values:
            return obj.data_quality_score
        return sum(values) / len(values)

    @extend_schema_field(serializers.CharField)
    def get_source_badge(self, obj):
        return obj.source.source_type

    @extend_schema_field(serializers.BooleanField)
    def get_is_favorite(self, obj):
        request = self.context.get("request")
        if not request or not request.user.is_authenticated:
            return False
        return FavoriteFood.objects.filter(user=request.user, food=obj).exists()

    @extend_schema_field(serializers.CharField)
    def get_data_classification(self, obj):
        if obj.food_type == Food.FoodType.USER_CUSTOM:
            return "user_custom"
        if obj.source.source_type == "AI_ESTIMATE":
            return "ai_estimate"
        if obj.verified:
            if obj.source.source_type == "MANUAL_ADMIN_SAMPLE":
                return "trusted_seeded"
            return "official_verified"
        return "official_unverified"

    @extend_schema_field(serializers.JSONField)
    def get_personal_portion_preferences(self, obj):
        return _personal_portion_preferences(obj)


class FoodDetailSerializer(serializers.ModelSerializer):
    source = serializers.SerializerMethodField()
    created_by = serializers.UUIDField(source="created_by_id", read_only=True)
    aliases = serializers.SerializerMethodField()
    servings = FoodServingSerializer(many=True, read_only=True)
    nutrients = FoodNutrientSerializer(many=True, read_only=True)
    is_favorite = serializers.SerializerMethodField()
    source_badge = serializers.SerializerMethodField()
    confidence_score = serializers.SerializerMethodField()
    data_classification = serializers.SerializerMethodField()
    personal_portion_preferences = serializers.SerializerMethodField()
    custom_food = serializers.SerializerMethodField()

    class Meta:
        model = Food
        fields = (
            "id",
            "canonical_name",
            "brand_name",
            "description",
            "ingredients_text",
            "allergens",
            "food_type",
            "preparation_state",
            "dataset_type",
            "dataset_release",
            "imported_at",
            "source_updated_at",
            "edible_portion_percent",
            "source",
            "source_badge",
            "external_id",
            "country_code",
            "language_code",
            "barcode",
            "serving_description",
            "default_serving_g",
            "data_quality_score",
            "completeness_score",
            "quality_warnings",
            "confidence_score",
            "verified",
            "is_deprecated",
            "replacement_food",
            "data_classification",
            "created_by",
            "aliases",
            "servings",
            "nutrients",
            "is_favorite",
            "personal_portion_preferences",
            "custom_food",
            "created_at",
            "updated_at",
        )

    @extend_schema_field(FoodSourceSummarySerializer)
    def get_source(self, obj):
        return {
            "id": obj.source_id,
            "name": obj.source.name,
            "source_type": obj.source.source_type,
            "reliability_score": obj.source.reliability_score,
        }

    @extend_schema_field(FoodAliasOutputSerializer(many=True))
    def get_aliases(self, obj):
        return [
            {"alias": alias.alias, "language_code": alias.language_code}
            for alias in obj.aliases.all()
        ]

    @extend_schema_field(serializers.BooleanField)
    def get_is_favorite(self, obj):
        request = self.context.get("request")
        if not request or not request.user.is_authenticated:
            return False
        return FavoriteFood.objects.filter(user=request.user, food=obj).exists()

    @extend_schema_field(serializers.CharField)
    def get_source_badge(self, obj):
        return obj.source.source_type

    @extend_schema_field(serializers.DecimalField(max_digits=5, decimal_places=4))
    def get_confidence_score(self, obj):
        values = [
            nutrient.confidence_score
            for nutrient in obj.nutrients.all()
            if nutrient.nutrient.code in SUMMARY_NUTRIENT_CODES
        ]
        if not values:
            return obj.data_quality_score
        return sum(values) / len(values)

    @extend_schema_field(serializers.CharField)
    def get_data_classification(self, obj):
        if obj.food_type == Food.FoodType.USER_CUSTOM:
            return "user_custom"
        if obj.source.source_type == "AI_ESTIMATE":
            return "ai_estimate"
        if obj.verified:
            if obj.source.source_type == "MANUAL_ADMIN_SAMPLE":
                return "trusted_seeded"
            return "official_verified"
        return "official_unverified"

    @extend_schema_field(serializers.JSONField)
    def get_personal_portion_preferences(self, obj):
        return _personal_portion_preferences(obj)

    @extend_schema_field(serializers.JSONField)
    def get_custom_food(self, obj):
        try:
            profile = obj.custom_profile
        except CustomFoodProfile.DoesNotExist:
            return None
        if profile.status == CustomFoodProfile.Status.ESTIMATE_READY:
            base_values = profile.estimated_nutrients
        else:
            base_values = profile.confirmed_nutrients or profile.estimated_nutrients
        effective_values = {**base_values, **profile.user_corrections}
        return {
            "status": profile.status,
            "serving_quantity": profile.serving_quantity,
            "serving_unit": profile.serving_unit,
            "serving_weight_g": profile.serving_weight_g,
            "estimation_method": profile.estimation_method,
            "original_estimated_nutrients": profile.original_estimated_nutrients,
            "estimated_nutrients": profile.estimated_nutrients,
            "estimated_range": profile.estimated_range,
            "confirmed_nutrients": profile.confirmed_nutrients,
            "effective_review_nutrients": effective_values,
            "reference_foods": profile.reference_foods,
            "ingredients": profile.ingredients,
            "confidence": profile.confidence_score,
            "user_corrections": profile.user_corrections,
            "warnings": profile.warnings,
            "calculated_calories_from_macros": profile.calculated_calories_kcal,
            "confirmed_at": profile.confirmed_at,
            "version": profile.version_number,
            "requires_review": profile.status != CustomFoodProfile.Status.CONFIRMED,
            "accuracy_notice": (
                "Estimates are database-based suggestions, not laboratory results."
            ),
        }


def _personal_portion_preferences(obj):
    preferences = getattr(obj, "request_portions", ())
    return [
        {
            "unit": preference.unit,
            "grams_per_unit": preference.grams_per_unit,
            "times_used": preference.times_used,
        }
        for preference in preferences
    ]


class CustomFoodNutrientInputSerializer(serializers.Serializer):
    nutrient_code = serializers.CharField(max_length=64)
    amount_per_100g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        min_value=Decimal("0"),
        max_value=Decimal("1000000"),
    )
    min_value = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        allow_null=True,
    )
    max_value = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        allow_null=True,
    )
    confidence_score = serializers.DecimalField(
        max_digits=5,
        decimal_places=4,
        required=False,
        default=Decimal("0.5000"),
        min_value=Decimal("0"),
        max_value=Decimal("1"),
    )
    derivation_method = serializers.ChoiceField(
        choices=FoodNutrient.DerivationMethod.choices,
        default=FoodNutrient.DerivationMethod.USER_ENTERED,
    )

    def validate_nutrient_code(self, value):
        return value.lower()


class CustomFoodServingInputSerializer(serializers.Serializer):
    serving_name = serializers.CharField(max_length=160)
    grams = serializers.DecimalField(
        max_digits=8,
        decimal_places=2,
        min_value=Decimal("0.01"),
        max_value=Decimal("100000"),
    )
    household_quantity = serializers.CharField(
        max_length=120,
        required=False,
        allow_blank=True,
    )
    is_default = serializers.BooleanField(required=False, default=False)


class CustomFoodCreateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=255, required=False)
    canonical_name = serializers.CharField(max_length=255, required=False)
    brand = serializers.CharField(max_length=255, required=False, allow_blank=True)
    brand_name = serializers.CharField(max_length=255, required=False, allow_blank=True)
    notes = serializers.CharField(required=False, allow_blank=True)
    description = serializers.CharField(required=False, allow_blank=True)
    preparation_state = serializers.ChoiceField(
        choices=Food.PreparationState.choices,
        required=False,
        default=Food.PreparationState.PREPARED,
    )
    preparation_method = serializers.ChoiceField(
        choices=Food.PreparationState.choices,
        required=False,
    )
    country_code = serializers.CharField(max_length=2, required=False, default="IN")
    language_code = serializers.CharField(max_length=12, required=False, default="en")
    barcode = serializers.CharField(max_length=64, required=False, allow_blank=True)
    serving_name = serializers.CharField(
        max_length=160,
        required=False,
        allow_blank=True,
    )
    serving_grams = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
        min_value=Decimal("0.001"),
        max_value=Decimal("100000"),
    )
    serving_weight_g = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
        min_value=Decimal("0.001"),
        max_value=Decimal("100000"),
    )
    serving_quantity = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        default=Decimal("1"),
        min_value=Decimal("0.001"),
        max_value=Decimal("100000"),
    )
    serving_unit = serializers.CharField(
        max_length=32, required=False, default="serving"
    )
    serving_description = serializers.CharField(
        max_length=160,
        required=False,
        allow_blank=True,
    )
    default_serving_g = serializers.DecimalField(
        max_digits=8,
        decimal_places=2,
        required=False,
        allow_null=True,
    )
    data_quality_score = serializers.DecimalField(
        max_digits=5,
        decimal_places=4,
        required=False,
        default=Decimal("0.5000"),
        min_value=Decimal("0"),
        max_value=Decimal("1"),
    )
    calories_kcal = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("10000"),
    )
    protein_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("2000"),
    )
    carbs_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("5000"),
    )
    fat_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("2000"),
    )
    fiber_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("2000"),
    )
    sugar_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("5000"),
    )
    sodium_mg = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("1000000"),
    )
    ingredients_text = serializers.CharField(required=False, allow_blank=True)
    ingredients = serializers.ListField(
        child=serializers.DictField(), required=False, allow_empty=True
    )
    estimated_nutrients = serializers.DictField(required=False)
    estimated_range = serializers.DictField(required=False)
    reference_matches = serializers.ListField(
        child=serializers.DictField(), required=False
    )
    confidence = serializers.DecimalField(
        max_digits=5,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("1"),
    )
    estimation_method = serializers.ChoiceField(
        choices=CustomFoodProfile.EstimationMethod.choices,
        required=False,
    )
    warnings = serializers.ListField(
        child=serializers.CharField(), required=False
    )
    nutrients = CustomFoodNutrientInputSerializer(
        many=True,
        required=False,
        allow_empty=False,
    )
    servings = CustomFoodServingInputSerializer(many=True, required=False)

    def validate_country_code(self, value):
        return value.upper()

    def validate_barcode(self, value):
        if value and Food.objects.filter(barcode=value).exists():
            raise serializers.ValidationError(
                "A food with this barcode already exists."
            )
        return value

    def validate(self, attrs):
        if not attrs.get("name") and not attrs.get("canonical_name"):
            raise serializers.ValidationError({"name": "Food name is required."})

        if attrs.get("preparation_method"):
            attrs["preparation_state"] = attrs.pop("preparation_method")
        if attrs.get("serving_weight_g"):
            attrs["serving_grams"] = attrs.pop("serving_weight_g")
        if not attrs.get("serving_grams") and attrs.get("default_serving_g"):
            attrs["serving_grams"] = attrs["default_serving_g"]
        if not attrs.get("serving_name") and attrs.get("serving_description"):
            attrs["serving_name"] = attrs["serving_description"]

        if not attrs.get("serving_grams"):
            raise serializers.ValidationError(
                {"serving_grams": "Serving weight in grams is required."}
            )
        if attrs.get("serving_grams") is not None and attrs["serving_grams"] <= 0:
            raise serializers.ValidationError(
                {"serving_grams": "Serving grams must be greater than zero."}
            )
        normalized_payload = normalize_custom_food_payload(attrs)
        nutrient_codes = {
            item["nutrient_code"]
            for item in normalized_payload.get("nutrients", [])
        }
        nutrient_map = Nutrient.objects.in_bulk(nutrient_codes, field_name="code")
        missing = sorted(nutrient_codes - set(nutrient_map))
        if missing:
            raise serializers.ValidationError(
                {"nutrients": f"Unknown nutrient code(s): {', '.join(missing)}"}
            )
        estimate = attrs.get("estimated_nutrients") or {}
        invalid_estimate_fields = sorted(set(estimate) - set(CUSTOM_NUTRIENT_FIELDS))
        if invalid_estimate_fields:
            raise serializers.ValidationError(
                {
                    "estimated_nutrients": (
                        "Unknown fields: " + ", ".join(invalid_estimate_fields)
                    )
                }
            )
        for field, value in estimate.items():
            try:
                decimal_value = Decimal(str(value))
            except Exception as exc:
                raise serializers.ValidationError(
                    {"estimated_nutrients": f"{field} must be numeric."}
                ) from exc
            if decimal_value < 0:
                raise serializers.ValidationError(
                    {"estimated_nutrients": f"{field} cannot be negative."}
                )

        request = self.context.get("request")
        if request and request.user.is_authenticated:
            name = attrs.get("name") or attrs.get("canonical_name")
            brand = attrs.get("brand") or attrs.get("brand_name") or ""
            if Food.objects.filter(
                created_by=request.user,
                food_type=Food.FoodType.USER_CUSTOM,
                normalized_name=normalize_catalog_text(name),
                brand_name__iexact=brand,
                is_deprecated=False,
            ).exists():
                raise serializers.ValidationError(
                    {"name": "You already have an active custom food with this name."}
                )
        return attrs

    def create(self, validated_data):
        request = self.context["request"]
        return create_custom_food(request.user, validated_data)


class CustomFoodIngredientSerializer(serializers.Serializer):
    food_id = serializers.UUIDField()
    quantity = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        default=Decimal("1"),
        min_value=Decimal("0.001"),
    )
    unit = serializers.CharField(max_length=32, required=False, default="serving")
    grams = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
        min_value=Decimal("0.001"),
        max_value=Decimal("100000"),
    )


class CustomFoodEstimateRequestSerializer(serializers.Serializer):
    food_name = serializers.CharField(max_length=255)
    brand = serializers.CharField(max_length=255, required=False, allow_blank=True)
    preparation_method = serializers.ChoiceField(
        choices=Food.PreparationState.choices,
        required=False,
        default=Food.PreparationState.PREPARED,
    )
    serving_name = serializers.CharField(
        max_length=160, required=False, default="Serving"
    )
    serving_quantity = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        default=Decimal("1"),
        min_value=Decimal("0.001"),
    )
    serving_unit = serializers.CharField(
        max_length=32, required=False, default="serving"
    )
    serving_weight_g = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
        min_value=Decimal("0.001"),
        max_value=Decimal("100000"),
    )
    ingredients = CustomFoodIngredientSerializer(many=True, required=False)
    ingredients_text = serializers.CharField(required=False, allow_blank=True)
    reference_food_id = serializers.UUIDField(required=False, allow_null=True)

    def validate(self, attrs):
        if not attrs.get("serving_weight_g") and not attrs.get("ingredients"):
            raise serializers.ValidationError(
                {"serving_weight_g": "Enter serving grams or structured ingredients."}
            )
        return attrs


class CustomFoodNutrientValuesSerializer(serializers.Serializer):
    calories_kcal = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("10000"),
    )
    protein_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("2000"),
    )
    carbs_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("5000"),
    )
    fat_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("2000"),
    )
    fiber_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("2000"),
    )
    sugar_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("5000"),
    )
    sodium_mg = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
        min_value=Decimal("0"),
        max_value=Decimal("1000000"),
    )


class CustomFoodUpdateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=255, required=False)
    brand = serializers.CharField(max_length=255, required=False, allow_blank=True)
    preparation_method = serializers.ChoiceField(
        choices=Food.PreparationState.choices, required=False
    )
    serving_name = serializers.CharField(max_length=160, required=False)
    serving_quantity = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        min_value=Decimal("0.001"),
    )
    serving_unit = serializers.CharField(max_length=32, required=False)
    serving_weight_g = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        min_value=Decimal("0.001"),
        max_value=Decimal("100000"),
    )
    barcode = serializers.CharField(max_length=64, required=False, allow_blank=True)
    notes = serializers.CharField(required=False, allow_blank=True)
    ingredients_text = serializers.CharField(required=False, allow_blank=True)
    ingredients = CustomFoodIngredientSerializer(many=True, required=False)
    final_nutrients = CustomFoodNutrientValuesSerializer(required=False)
    reset_to_estimate = serializers.BooleanField(required=False, default=False)
    status = serializers.ChoiceField(
        choices=(CustomFoodProfile.Status.ARCHIVED,), required=False
    )

    def validate_barcode(self, value):
        food = self.context.get("food")
        query = Food.objects.filter(barcode=value) if value else Food.objects.none()
        if food:
            query = query.exclude(id=food.id)
        if query.exists():
            raise serializers.ValidationError(
                "A food with this barcode already exists."
            )
        return value


class CustomFoodConfirmSerializer(serializers.Serializer):
    final_nutrients = CustomFoodNutrientValuesSerializer(required=False)
    use_estimate = serializers.BooleanField(required=False, default=False)
    serving_weight_g = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        min_value=Decimal("0.001"),
        max_value=Decimal("100000"),
    )

    def validate(self, attrs):
        if attrs.get("use_estimate") and attrs.get("final_nutrients"):
            raise serializers.ValidationError(
                "Choose either the estimate or edited final values, not both."
            )
        return attrs


class CustomFoodReEstimateSerializer(CustomFoodEstimateRequestSerializer):
    food_name = serializers.CharField(max_length=255, required=False)


class CustomFoodLogSerializer(serializers.Serializer):
    meal_type = serializers.ChoiceField(
        choices=MealLog.MealType.choices,
        default=MealLog.MealType.SNACK,
    )
    date = serializers.DateField(default=timezone.localdate)
    quantity_value = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        min_value=Decimal("0.001"),
        default=Decimal("1"),
    )
    quantity_unit = serializers.CharField(max_length=32, default="serving")
    total_grams = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
        min_value=Decimal("0.001"),
    )
    timezone = serializers.CharField(max_length=64, required=False, allow_blank=True)


class CustomFoodVersionSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomFoodVersion
        fields = ("id", "version", "event", "status", "snapshot", "created_at")
