from __future__ import annotations

from decimal import Decimal

from django.db import transaction

from foods.models import Food, FoodNutrient, FoodServing
from meals.models import MealLog, MealLogItem
from meals.services import recompute_daily_summary
from nutrition.calculations import (
    add_snapshot_totals,
    calculate_food_snapshot,
    calculate_grams_for_food,
    decimal_to_snapshot,
    macro_percentage_split,
    quantize_decimal,
)
from nutrition.models import Nutrient, NutritionDataSource


def get_recipe_calculation_source():
    source, _ = NutritionDataSource.objects.get_or_create(
        source_type=NutritionDataSource.SourceType.USER_CUSTOM,
        defaults={
            "name": "User Custom",
            "license_name": "User provided",
            "citation": "User-entered and recipe-calculated foods in NutriNova AI.",
            "update_frequency": "User managed",
            "reliability_score": Decimal("0.5000"),
            "is_active": True,
        },
    )
    return source


@transaction.atomic
def calculate_recipe_totals(recipe) -> dict:
    totals: dict[str, Decimal] = {}
    ingredient_payloads = []
    total_weight = Decimal("0")
    for ingredient in recipe.ingredients.select_related("food").prefetch_related(
        "food__nutrients__nutrient",
        "food__nutrients__source",
    ):
        snapshot = calculate_food_snapshot(ingredient.food, ingredient.grams_calculated)
        add_snapshot_totals(totals, snapshot["nutrients_snapshot"])
        total_weight += ingredient.grams_calculated
        ingredient_payloads.append(
            {
                "id": ingredient.id,
                "food": ingredient.food_id,
                "food_name": ingredient.food.canonical_name,
                "grams_calculated": ingredient.grams_calculated,
                "calories_kcal": snapshot["calories_kcal"],
                "macros": snapshot["macros_snapshot"],
            }
        )

    if recipe.total_weight_g != total_weight:
        recipe.total_weight_g = quantize_decimal(total_weight)
        recipe.save(update_fields=["total_weight_g", "updated_at"])

    servings = recipe.servings or Decimal("1")
    per_serving = {
        code: decimal_to_snapshot(value / servings) for code, value in totals.items()
    }
    per_100g = {}
    if total_weight > 0:
        per_100g = {
            code: decimal_to_snapshot(value / total_weight * Decimal("100"))
            for code, value in totals.items()
        }
    totals_snapshot = {
        code: decimal_to_snapshot(value) for code, value in totals.items()
    }
    return {
        "recipe_id": recipe.id,
        "servings": recipe.servings,
        "total_weight_g": quantize_decimal(total_weight),
        "totals": totals_snapshot,
        "per_serving": per_serving,
        "per_100g": per_100g,
        "macro_percentage_split": macro_percentage_split(totals_snapshot),
        "ingredients": ingredient_payloads,
    }


@transaction.atomic
def upsert_recipe_food(recipe):
    calculation = calculate_recipe_totals(recipe)
    source = get_recipe_calculation_source()
    total_weight = Decimal(str(calculation["total_weight_g"]))
    serving_g = Decimal("0")
    if recipe.servings and recipe.servings > 0:
        serving_g = quantize_decimal(total_weight / recipe.servings)

    food, _ = Food.objects.update_or_create(
        source=source,
        external_id=f"recipe:{recipe.id}",
        defaults={
            "canonical_name": recipe.name,
            "brand_name": "",
            "description": recipe.description,
            "food_type": Food.FoodType.RECIPE,
            "country_code": "IN",
            "language_code": "en",
            "serving_description": "1 recipe serving",
            "default_serving_g": serving_g or None,
            "data_quality_score": Decimal("0.7000"),
            "verified": False,
            "created_by": recipe.user,
        },
    )
    if serving_g > 0:
        FoodServing.objects.update_or_create(
            food=food,
            serving_name="1 recipe serving",
            defaults={"grams": serving_g, "is_default": True},
        )

    nutrients = Nutrient.objects.in_bulk(
        calculation["per_100g"].keys(),
        field_name="code",
    )
    for code, amount in calculation["per_100g"].items():
        nutrient = nutrients.get(code)
        if not nutrient:
            continue
        FoodNutrient.objects.update_or_create(
            food=food,
            nutrient=nutrient,
            source=source,
            derivation_method=FoodNutrient.DerivationMethod.CALCULATED,
            defaults={
                "amount_per_100g": Decimal(str(amount)),
                "confidence_score": Decimal("0.7000"),
            },
        )
    return food, calculation


@transaction.atomic
def log_recipe_as_meal(recipe, user, validated_data):
    food, _ = upsert_recipe_food(recipe)
    serving = food.servings.filter(is_default=True).first()
    unit = validated_data.get("unit", "serving")
    quantity = validated_data.get("quantity", Decimal("1"))
    grams = calculate_grams_for_food(
        food=food,
        quantity=quantity,
        unit=unit,
        serving=serving if unit == "serving" else validated_data.get("serving"),
        grams_calculated=validated_data.get("grams_calculated"),
    )
    snapshot = calculate_food_snapshot(food, grams)
    meal_log = MealLog.objects.create(
        user=user,
        date=validated_data["date"],
        meal_type=validated_data["meal_type"],
        name=validated_data.get("name") or recipe.name,
        notes=validated_data.get("notes", ""),
        timezone=validated_data.get("timezone") or getattr(user, "timezone", "UTC"),
    )
    MealLogItem.objects.create(
        user=user,
        meal_log=meal_log,
        food=food,
        quantity=quantity,
        unit=unit,
        grams_calculated=grams,
        serving=serving if unit == "serving" else validated_data.get("serving"),
        calories_kcal=snapshot["calories_kcal"],
        macros_snapshot=snapshot["macros_snapshot"],
        nutrients_snapshot=snapshot["nutrients_snapshot"],
        source_confidence=snapshot["source_confidence"],
        user_confirmed=True,
    )
    recompute_daily_summary(user, meal_log.date)
    return meal_log
