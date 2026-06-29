from __future__ import annotations

from decimal import Decimal

from django.db import transaction
from django.db.models import Q

from foods.models import Food, FoodNutrient, FoodServing
from nutrition.calculations import quantize_decimal
from nutrition.models import Nutrient, NutritionDataSource

CUSTOM_NUTRIENT_FIELDS = {
    "calories_kcal": "calories",
    "protein_g": "protein_g",
    "carbs_g": "carbs_g",
    "fat_g": "fat_g",
    "fiber_g": "fiber_g",
    "sugar_g": "sugar_g",
    "sodium_mg": "sodium_mg",
}


def visible_foods_for_user(user):
    if not user.is_authenticated:
        return Food.objects.none()
    return Food.objects.filter(Q(created_by__isnull=True) | Q(created_by=user))


def get_or_create_user_custom_source():
    source, _ = NutritionDataSource.objects.get_or_create(
        source_type=NutritionDataSource.SourceType.USER_CUSTOM,
        defaults={
            "name": "User Custom",
            "license_name": "User provided",
            "citation": "User-entered foods created inside NutriNova AI.",
            "update_frequency": "User managed",
            "reliability_score": Decimal("0.5000"),
            "is_active": True,
        },
    )
    return source


def flat_nutrients_to_per_100g(validated_data: dict) -> list[dict]:
    serving_grams = validated_data.get("serving_grams")
    if not serving_grams or serving_grams <= 0:
        return []

    nutrients = []
    for input_field, nutrient_code in CUSTOM_NUTRIENT_FIELDS.items():
        value = validated_data.get(input_field)
        if value in (None, ""):
            continue
        amount_per_100g = Decimal(value) / Decimal(serving_grams) * Decimal("100")
        nutrients.append(
            {
                "nutrient_code": nutrient_code,
                "amount_per_100g": quantize_decimal(amount_per_100g, "0.0001"),
                "confidence_score": Decimal("0.5000"),
                "derivation_method": FoodNutrient.DerivationMethod.USER_ENTERED,
            }
        )
    return nutrients


def normalize_custom_food_payload(validated_data: dict) -> dict:
    payload = validated_data.copy()
    canonical_name = payload.pop("name", "") or payload.get("canonical_name", "")
    brand_name = payload.pop("brand", "") or payload.get("brand_name", "")
    notes = payload.pop("notes", "")
    serving_name = payload.pop("serving_name", "")
    serving_grams = payload.pop("serving_grams", None)

    payload["canonical_name"] = canonical_name
    payload["brand_name"] = brand_name
    if notes and not payload.get("description"):
        payload["description"] = notes

    flat_nutrients = flat_nutrients_to_per_100g(
        {
            **validated_data,
            "serving_grams": serving_grams,
        }
    )
    if flat_nutrients:
        payload["nutrients"] = flat_nutrients
        payload["serving_description"] = (
            payload.get("serving_description") or serving_name
        )
        payload["default_serving_g"] = payload.get("default_serving_g") or serving_grams
        payload["servings"] = [
            {
                "serving_name": serving_name or "Default serving",
                "grams": serving_grams,
                "household_quantity": serving_name,
                "is_default": True,
            }
        ]

    for field in CUSTOM_NUTRIENT_FIELDS:
        payload.pop(field, None)
    return payload


@transaction.atomic
def create_custom_food(user, validated_data: dict) -> Food:
    payload = normalize_custom_food_payload(validated_data)
    nutrient_inputs = payload.pop("nutrients")
    serving_inputs = payload.pop("servings", [])
    nutrient_codes = {item["nutrient_code"] for item in nutrient_inputs}
    nutrient_map = Nutrient.objects.in_bulk(nutrient_codes, field_name="code")
    source = get_or_create_user_custom_source()

    food = Food.objects.create(
        **payload,
        food_type=Food.FoodType.USER_CUSTOM,
        source=source,
        verified=False,
        created_by=user,
    )

    if food.default_serving_g and not serving_inputs:
        FoodServing.objects.create(
            food=food,
            serving_name=food.serving_description or "Default serving",
            grams=food.default_serving_g,
            is_default=True,
        )

    for serving_input in serving_inputs:
        if serving_input.get("is_default"):
            FoodServing.objects.filter(food=food, is_default=True).update(
                is_default=False
            )
        FoodServing.objects.create(food=food, **serving_input)

    FoodNutrient.objects.bulk_create(
        [
            FoodNutrient(
                food=food,
                nutrient=nutrient_map[nutrient_input["nutrient_code"]],
                amount_per_100g=nutrient_input["amount_per_100g"],
                min_value=nutrient_input.get("min_value"),
                max_value=nutrient_input.get("max_value"),
                source=source,
                confidence_score=nutrient_input["confidence_score"],
                derivation_method=nutrient_input["derivation_method"],
            )
            for nutrient_input in nutrient_inputs
        ]
    )
    return food
