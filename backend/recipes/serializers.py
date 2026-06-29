from __future__ import annotations

from decimal import Decimal

from django.utils import timezone
from rest_framework import serializers

from foods.models import FoodServing
from meals.models import MealLog, MealLogItem
from meals.serializers import MealLogSerializer, visible_foods_for_user
from nutrition.calculations import calculate_grams_for_food
from recipes.models import Recipe, RecipeIngredient
from recipes.services import calculate_recipe_totals


class RecipeIngredientSerializer(serializers.ModelSerializer):
    food_name = serializers.CharField(source="food.canonical_name", read_only=True)
    brand_name = serializers.CharField(source="food.brand_name", read_only=True)
    serving_name = serializers.CharField(source="serving.serving_name", read_only=True)

    class Meta:
        model = RecipeIngredient
        fields = (
            "id",
            "food",
            "food_name",
            "brand_name",
            "quantity",
            "unit",
            "grams_calculated",
            "serving",
            "serving_name",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "food_name",
            "brand_name",
            "serving_name",
            "created_at",
            "updated_at",
        )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request:
            self.fields["food"].queryset = visible_foods_for_user(
                request.user
            ).prefetch_related("servings", "nutrients__nutrient", "nutrients__source")
        self.fields["serving"].queryset = FoodServing.objects.select_related("food")

    def validate(self, attrs):
        food = attrs.get("food") or getattr(self.instance, "food", None)
        if food is None:
            raise serializers.ValidationError({"food": "Food is required."})
        serving = attrs.get("serving")
        if "serving" not in attrs and self.instance:
            serving = self.instance.serving
        if serving and serving.food_id != food.id:
            raise serializers.ValidationError(
                {"serving": "Serving does not belong to the selected food."}
            )
        quantity = attrs.get("quantity")
        if quantity is None and self.instance:
            quantity = self.instance.quantity
        unit = attrs.get("unit")
        if unit is None and self.instance:
            unit = self.instance.unit
        if unit is None:
            unit = RecipeIngredient.Unit.GRAMS
            attrs["unit"] = unit
        grams_input = attrs.get("grams_calculated")
        if "grams_calculated" not in attrs and self.instance:
            grams_input = self.instance.grams_calculated
        attrs["grams_calculated"] = calculate_grams_for_food(
            food=food,
            quantity=quantity,
            unit=unit,
            serving=serving,
            grams_calculated=grams_input,
        )
        return attrs


class RecipeSerializer(serializers.ModelSerializer):
    ingredients = RecipeIngredientSerializer(many=True, required=False)

    class Meta:
        model = Recipe
        fields = (
            "id",
            "name",
            "description",
            "servings",
            "total_weight_g",
            "visibility",
            "instructions",
            "cuisine",
            "tags",
            "ingredients",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "total_weight_g", "created_at", "updated_at")

    def validate_servings(self, value):
        if value <= 0:
            raise serializers.ValidationError("Servings must be greater than zero.")
        return value

    def validate_tags(self, value):
        if not isinstance(value, list):
            raise serializers.ValidationError("Tags must be a list.")
        return value

    def create(self, validated_data):
        request = self.context["request"]
        ingredients_data = validated_data.pop("ingredients", [])
        recipe = Recipe.objects.create(user=request.user, **validated_data)
        self._replace_ingredients(recipe, ingredients_data)
        calculate_recipe_totals(recipe)
        return recipe

    def update(self, instance, validated_data):
        ingredients_data = validated_data.pop("ingredients", None)
        for field, value in validated_data.items():
            setattr(instance, field, value)
        instance.save()
        if ingredients_data is not None:
            instance.ingredients.all().delete()
            self._replace_ingredients(instance, ingredients_data)
            calculate_recipe_totals(instance)
        return instance

    def _replace_ingredients(self, recipe, ingredients_data):
        request = self.context["request"]
        RecipeIngredient.objects.bulk_create(
            [
                RecipeIngredient(user=request.user, recipe=recipe, **ingredient)
                for ingredient in ingredients_data
            ]
        )


class RecipeLogAsMealSerializer(serializers.Serializer):
    date = serializers.DateField(default=timezone.localdate)
    meal_type = serializers.ChoiceField(
        choices=MealLog.MealType.choices,
        default=MealLog.MealType.CUSTOM,
    )
    name = serializers.CharField(max_length=160, required=False, allow_blank=True)
    notes = serializers.CharField(required=False, allow_blank=True)
    timezone = serializers.CharField(max_length=64, required=False, allow_blank=True)
    quantity = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        default=Decimal("1"),
    )
    unit = serializers.ChoiceField(
        choices=MealLogItem.Unit.choices,
        default=MealLogItem.Unit.SERVING,
    )
    grams_calculated = serializers.DecimalField(
        max_digits=10,
        decimal_places=3,
        required=False,
        allow_null=True,
    )
    serving = serializers.PrimaryKeyRelatedField(
        queryset=FoodServing.objects.all(),
        required=False,
        allow_null=True,
    )


class RecipeCalculationSerializer(serializers.Serializer):
    recipe_id = serializers.UUIDField()
    servings = serializers.DecimalField(max_digits=8, decimal_places=2)
    total_weight_g = serializers.DecimalField(max_digits=10, decimal_places=3)
    totals = serializers.JSONField()
    per_serving = serializers.JSONField()
    per_100g = serializers.JSONField()
    macro_percentage_split = serializers.JSONField()
    ingredients = serializers.JSONField()


class RecipeLogAsMealResponseSerializer(serializers.Serializer):
    meal = MealLogSerializer()
