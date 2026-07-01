from decimal import Decimal

from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from foods.models import FavoriteFood, Food, FoodNutrient, FoodServing
from foods.services.custom_foods import (
    CUSTOM_NUTRIENT_FIELDS,
    create_custom_food,
    normalize_custom_food_payload,
)
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

    class Meta:
        model = Food
        fields = (
            "id",
            "name",
            "brand",
            "default_serving",
            "nutrition_per_100g",
            "data_source",
            "source_type",
            "source_badge",
            "confidence_score",
            "verified",
            "data_classification",
            "is_favorite",
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

    class Meta:
        model = Food
        fields = (
            "id",
            "canonical_name",
            "brand_name",
            "description",
            "food_type",
            "source",
            "source_badge",
            "external_id",
            "country_code",
            "language_code",
            "barcode",
            "serving_description",
            "default_serving_g",
            "data_quality_score",
            "confidence_score",
            "verified",
            "data_classification",
            "created_by",
            "aliases",
            "servings",
            "nutrients",
            "is_favorite",
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


class CustomFoodNutrientInputSerializer(serializers.Serializer):
    nutrient_code = serializers.CharField(max_length=64)
    amount_per_100g = serializers.DecimalField(max_digits=12, decimal_places=4)
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
    grams = serializers.DecimalField(max_digits=8, decimal_places=2)
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
    country_code = serializers.CharField(max_length=2, required=False, default="IN")
    language_code = serializers.CharField(max_length=12, required=False, default="en")
    barcode = serializers.CharField(max_length=64, required=False, allow_blank=True)
    serving_name = serializers.CharField(
        max_length=160,
        required=False,
        allow_blank=True,
    )
    serving_grams = serializers.DecimalField(
        max_digits=8,
        decimal_places=2,
        required=False,
        allow_null=True,
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
    )
    protein_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
    )
    carbs_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
    )
    fat_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
    )
    fiber_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
    )
    sugar_g = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
    )
    sodium_mg = serializers.DecimalField(
        max_digits=12,
        decimal_places=4,
        required=False,
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

        flat_fields = {
            field for field in CUSTOM_NUTRIENT_FIELDS if attrs.get(field) is not None
        }
        if flat_fields and not attrs.get("serving_grams"):
            raise serializers.ValidationError(
                {"serving_grams": "Serving grams are required for flat nutrition."}
            )
        if attrs.get("serving_grams") is not None and attrs["serving_grams"] <= 0:
            raise serializers.ValidationError(
                {"serving_grams": "Serving grams must be greater than zero."}
            )
        if not flat_fields and not attrs.get("nutrients"):
            raise serializers.ValidationError(
                {
                    "nutrients": (
                        "Provide nutrients or flat calories/macros for this "
                        "custom food."
                    )
                }
            )

        normalized_payload = normalize_custom_food_payload(attrs)
        nutrient_codes = {
            item["nutrient_code"] for item in normalized_payload["nutrients"]
        }
        nutrient_map = Nutrient.objects.in_bulk(nutrient_codes, field_name="code")
        missing = sorted(nutrient_codes - set(nutrient_map))
        if missing:
            raise serializers.ValidationError(
                {"nutrients": f"Unknown nutrient code(s): {', '.join(missing)}"}
            )
        return attrs

    def create(self, validated_data):
        request = self.context["request"]
        return create_custom_food(request.user, validated_data)
