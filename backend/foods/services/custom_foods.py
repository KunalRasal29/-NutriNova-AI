from __future__ import annotations

from decimal import Decimal

from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from foods.models import (
    CustomFoodProfile,
    CustomFoodVersion,
    Food,
    FoodNutrient,
    FoodServing,
)
from foods.services.custom_food_estimation import (
    calorie_consistency_warnings,
    decimal_string,
    estimate_custom_food,
    macro_calories,
)
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
PROFILE_INPUT_FIELDS = {
    "serving_quantity",
    "serving_unit",
    "estimated_nutrients",
    "estimated_range",
    "reference_matches",
    "reference_foods",
    "confidence",
    "confidence_score",
    "estimation_method",
    "ingredients",
    "user_corrections",
    "warnings",
    "status",
    "reset_to_estimate",
}


def visible_foods_for_user(user):
    if not user.is_authenticated:
        return Food.objects.none()
    return Food.objects.filter(
        Q(created_by__isnull=True) | Q(created_by=user), is_deprecated=False
    ).filter(
        ~Q(food_type=Food.FoodType.USER_CUSTOM)
        | Q(custom_profile__status=CustomFoodProfile.Status.CONFIRMED)
        | Q(custom_profile__isnull=True)
    )


def custom_foods_for_user(user):
    if not user.is_authenticated:
        return Food.objects.none()
    return Food.objects.filter(
        created_by=user,
        food_type=Food.FoodType.USER_CUSTOM,
    )


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
    serving_grams = validated_data.get("serving_grams") or validated_data.get(
        "serving_weight_g"
    )
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


def nutrients_per_serving(validated_data: dict, serving_grams: Decimal) -> dict:
    flat = {
        field: decimal_string(Decimal(str(validated_data[field])))
        for field in CUSTOM_NUTRIENT_FIELDS
        if validated_data.get(field) not in (None, "")
    }
    if flat:
        return flat
    values = {}
    for nutrient in validated_data.get("nutrients") or []:
        output_field = next(
            (
                field
                for field, code in CUSTOM_NUTRIENT_FIELDS.items()
                if code == nutrient["nutrient_code"]
            ),
            nutrient["nutrient_code"],
        )
        amount = Decimal(nutrient["amount_per_100g"]) * serving_grams / Decimal("100")
        values[output_field] = decimal_string(amount)
    return values


def normalize_custom_food_payload(validated_data: dict) -> dict:
    payload = validated_data.copy()
    canonical_name = payload.pop("name", "") or payload.get("canonical_name", "")
    brand_name = payload.pop("brand", "") or payload.get("brand_name", "")
    notes = payload.pop("notes", "")
    serving_name = payload.pop("serving_name", "")
    serving_grams = payload.pop("serving_grams", None) or payload.pop(
        "serving_weight_g", None
    )

    payload["canonical_name"] = canonical_name
    payload["brand_name"] = brand_name
    if notes and not payload.get("description"):
        payload["description"] = notes

    flat_nutrients = flat_nutrients_to_per_100g(
        {**validated_data, "serving_grams": serving_grams}
    )
    if flat_nutrients:
        payload["nutrients"] = flat_nutrients
    payload["serving_description"] = (
        payload.get("serving_description") or serving_name or "Serving"
    )
    payload["default_serving_g"] = payload.get("default_serving_g") or serving_grams
    if serving_grams and not payload.get("servings"):
        payload["servings"] = [
            {
                "serving_name": serving_name or "Serving",
                "grams": serving_grams,
                "household_quantity": serving_name,
                "is_default": True,
            }
        ]

    for field in set(CUSTOM_NUTRIENT_FIELDS) | PROFILE_INPUT_FIELDS:
        payload.pop(field, None)
    return payload


def _profile_snapshot(profile: CustomFoodProfile) -> dict:
    food = profile.food
    return {
        "food": {
            "id": str(food.id),
            "name": food.canonical_name,
            "brand": food.brand_name,
            "preparation_method": food.preparation_state,
            "serving_name": food.serving_description,
            "serving_quantity": decimal_string(profile.serving_quantity),
            "serving_unit": profile.serving_unit,
            "serving_weight_g": decimal_string(profile.serving_weight_g),
            "barcode": food.barcode,
            "notes": food.description,
            "ingredients_text": food.ingredients_text,
        },
        "status": profile.status,
        "estimation_method": profile.estimation_method,
        "original_estimated_nutrients": profile.original_estimated_nutrients,
        "estimated_nutrients": profile.estimated_nutrients,
        "estimated_range": profile.estimated_range,
        "confirmed_nutrients": profile.confirmed_nutrients,
        "reference_foods": profile.reference_foods,
        "ingredients": profile.ingredients,
        "confidence": decimal_string(profile.confidence_score, "0.0001"),
        "user_corrections": profile.user_corrections,
        "warnings": profile.warnings,
        "calculated_calories_from_macros": (
            decimal_string(profile.calculated_calories_kcal)
            if profile.calculated_calories_kcal is not None
            else None
        ),
        "confirmed_at": (
            profile.confirmed_at.isoformat() if profile.confirmed_at else None
        ),
    }


def record_custom_food_version(profile: CustomFoodProfile, event: str) -> None:
    CustomFoodVersion.objects.create(
        user=profile.user,
        food=profile.food,
        version=profile.version_number,
        event=event,
        status=profile.status,
        snapshot=_profile_snapshot(profile),
    )


def _replace_default_serving(food: Food, serving_name: str, grams: Decimal) -> None:
    FoodServing.objects.filter(food=food).delete()
    FoodServing.objects.create(
        food=food,
        serving_name=serving_name or "Serving",
        grams=grams,
        household_quantity=serving_name,
        is_default=True,
    )
    food.serving_description = serving_name or "Serving"
    food.default_serving_g = grams


def write_confirmed_nutrients(
    profile: CustomFoodProfile,
    values_per_serving: dict,
) -> None:
    if not values_per_serving:
        raise ValidationError({"final_nutrients": "Enter or accept nutrition values."})
    source = get_or_create_user_custom_source()
    nutrient_codes = {
        code
        for field, code in CUSTOM_NUTRIENT_FIELDS.items()
        if values_per_serving.get(field) not in (None, "")
    }
    nutrient_map = Nutrient.objects.in_bulk(nutrient_codes, field_name="code")
    missing = nutrient_codes - set(nutrient_map)
    if missing:
        raise ValidationError(
            {"final_nutrients": f"Unknown nutrients: {', '.join(sorted(missing))}."}
        )
    FoodNutrient.objects.filter(food=profile.food).delete()
    rows = []
    for field, code in CUSTOM_NUTRIENT_FIELDS.items():
        if values_per_serving.get(field) in (None, ""):
            continue
        per_serving = Decimal(str(values_per_serving[field]))
        per_100g = per_serving / profile.serving_weight_g * Decimal("100")
        rows.append(
            FoodNutrient(
                food=profile.food,
                nutrient=nutrient_map[code],
                amount_per_100g=quantize_decimal(per_100g, "0.0001"),
                source=source,
                confidence_score=Decimal("0.5000"),
                derivation_method=FoodNutrient.DerivationMethod.USER_ENTERED,
                normalization_notes="Confirmed by the custom-food creator.",
            )
        )
    FoodNutrient.objects.bulk_create(rows)
    profile.food.completeness_score = Decimal(
        len(nutrient_codes & {"calories", "protein_g", "carbs_g", "fat_g"})
    ) / Decimal("4")
    profile.food.data_quality_score = Decimal("0.5000")
    profile.food.verified = False


@transaction.atomic
def create_custom_food(user, validated_data: dict) -> Food:
    serving_grams = Decimal(
        validated_data.get("serving_grams")
        or validated_data.get("serving_weight_g")
    )
    manual_values = nutrients_per_serving(validated_data, serving_grams)
    estimated_values = validated_data.get("estimated_nutrients") or {}
    payload = normalize_custom_food_payload(validated_data)
    payload.pop("nutrients", [])
    serving_inputs = payload.pop("servings", [])
    payload.pop("default_serving_g", None)
    payload.pop("serving_description", None)
    source = get_or_create_user_custom_source()

    food = Food.objects.create(
        **payload,
        food_type=Food.FoodType.USER_CUSTOM,
        dataset_type=Food.DatasetType.USER_CUSTOM,
        source=source,
        verified=False,
        created_by=user,
        serving_description=validated_data.get("serving_name")
        or validated_data.get("serving_description")
        or "Serving",
        default_serving_g=serving_grams,
    )
    if serving_inputs:
        serving_name = serving_inputs[0]["serving_name"]
    else:
        serving_name = food.serving_description
    _replace_default_serving(food, serving_name, serving_grams)

    if manual_values:
        profile_status = CustomFoodProfile.Status.CONFIRMED
        estimation_method = CustomFoodProfile.EstimationMethod.MANUAL_ENTRY
    elif estimated_values:
        profile_status = CustomFoodProfile.Status.ESTIMATE_READY
        estimation_method = validated_data.get(
            "estimation_method",
            CustomFoodProfile.EstimationMethod.DATABASE_MATCHES,
        )
    else:
        profile_status = CustomFoodProfile.Status.DRAFT
        estimation_method = CustomFoodProfile.EstimationMethod.NONE
    confidence = validated_data.get("confidence") or validated_data.get(
        "confidence_score", 0
    )
    initial_warnings = calorie_consistency_warnings(manual_values)
    profile = CustomFoodProfile.objects.create(
        user=user,
        food=food,
        status=profile_status,
        serving_quantity=validated_data.get("serving_quantity") or 1,
        serving_unit=validated_data.get("serving_unit") or "serving",
        serving_weight_g=serving_grams,
        estimation_method=estimation_method,
        original_estimated_nutrients=estimated_values,
        estimated_nutrients=estimated_values,
        estimated_range=validated_data.get("estimated_range") or {},
        confirmed_nutrients=manual_values,
        reference_foods=validated_data.get("reference_matches")
        or validated_data.get("reference_foods")
        or [],
        ingredients=validated_data.get("ingredients") or [],
        confidence_score=confidence,
        user_corrections=validated_data.get("user_corrections") or {},
        warnings=validated_data.get("warnings") or initial_warnings,
        calculated_calories_kcal=(
            macro_calories(manual_values) if manual_values else None
        ),
        confirmed_at=timezone.now() if manual_values else None,
    )
    if manual_values:
        write_confirmed_nutrients(profile, manual_values)
        food.quality_warnings = profile.warnings
    food.save()
    record_custom_food_version(profile, "created")
    return food


@transaction.atomic
def apply_custom_food_estimate(profile: CustomFoodProfile, estimate: dict) -> dict:
    if not profile.original_estimated_nutrients and estimate["can_estimate"]:
        profile.original_estimated_nutrients = estimate["suggested_nutrients"]
    profile.estimated_nutrients = estimate["suggested_nutrients"]
    profile.estimated_range = estimate["estimated_range"]
    profile.reference_foods = estimate["reference_matches"]
    profile.confidence_score = Decimal(estimate["confidence"])
    profile.estimation_method = estimate["estimation_method"]
    profile.warnings = estimate["warnings"]
    profile.calculated_calories_kcal = Decimal(
        estimate["calculated_calories_from_macros"]
    )
    profile.status = (
        CustomFoodProfile.Status.ESTIMATE_READY
        if estimate["can_estimate"]
        else CustomFoodProfile.Status.NEEDS_REVIEW
    )
    profile.version_number += 1
    profile.save()
    record_custom_food_version(profile, "re_estimated")
    return estimate


def estimate_profile(profile: CustomFoodProfile, overrides: dict | None = None) -> dict:
    overrides = overrides or {}
    data = {
        "food_name": profile.food.canonical_name,
        "preparation_method": profile.food.preparation_state,
        "serving_name": profile.food.serving_description,
        "serving_quantity": profile.serving_quantity,
        "serving_unit": profile.serving_unit,
        "serving_weight_g": profile.serving_weight_g,
        "ingredients": profile.ingredients,
        **overrides,
    }
    estimate = estimate_custom_food(profile.user, data)
    return apply_custom_food_estimate(profile, estimate)


@transaction.atomic
def update_custom_food(profile: CustomFoodProfile, validated_data: dict) -> Food:
    food = profile.food
    field_map = {
        "name": "canonical_name",
        "canonical_name": "canonical_name",
        "brand": "brand_name",
        "brand_name": "brand_name",
        "preparation_method": "preparation_state",
        "preparation_state": "preparation_state",
        "notes": "description",
        "description": "description",
        "ingredients_text": "ingredients_text",
        "barcode": "barcode",
    }
    for input_field, model_field in field_map.items():
        if input_field in validated_data:
            setattr(food, model_field, validated_data[input_field])
    serving_grams = validated_data.get("serving_weight_g") or validated_data.get(
        "serving_grams"
    )
    if serving_grams:
        profile.serving_weight_g = serving_grams
        _replace_default_serving(
            food,
            validated_data.get("serving_name") or food.serving_description,
            serving_grams,
        )
        if profile.status == CustomFoodProfile.Status.CONFIRMED:
            profile.user_corrections = profile.confirmed_nutrients.copy()
            profile.status = CustomFoodProfile.Status.NEEDS_REVIEW
    elif "serving_name" in validated_data:
        _replace_default_serving(
            food, validated_data["serving_name"], profile.serving_weight_g
        )
    if "serving_quantity" in validated_data:
        profile.serving_quantity = validated_data["serving_quantity"]
    if "serving_unit" in validated_data:
        profile.serving_unit = validated_data["serving_unit"]
    if "ingredients" in validated_data:
        profile.ingredients = validated_data["ingredients"]
        if profile.confirmed_nutrients and not profile.user_corrections:
            profile.user_corrections = profile.confirmed_nutrients.copy()
        profile.status = CustomFoodProfile.Status.NEEDS_REVIEW
        profile.warnings = [
            "Ingredients changed. Re-estimate or review nutrition before confirming."
        ]

    correction_values = {
        field: decimal_string(Decimal(str(validated_data[field])))
        for field in CUSTOM_NUTRIENT_FIELDS
        if field in validated_data
    }
    if validated_data.get("final_nutrients"):
        correction_values.update(
            {
                field: decimal_string(Decimal(str(value)))
                for field, value in validated_data["final_nutrients"].items()
            }
        )
    if correction_values:
        profile.user_corrections = {
            **profile.user_corrections,
            **correction_values,
        }
        base_values = profile.confirmed_nutrients or profile.estimated_nutrients
        effective_values = {**base_values, **profile.user_corrections}
        profile.status = CustomFoodProfile.Status.NEEDS_REVIEW
        profile.warnings = calorie_consistency_warnings(effective_values)
        profile.calculated_calories_kcal = macro_calories(effective_values)
    if validated_data.get("reset_to_estimate"):
        if not profile.estimated_nutrients:
            raise ValidationError({"reset_to_estimate": "No estimate is available."})
        profile.user_corrections = {}
        profile.status = CustomFoodProfile.Status.ESTIMATE_READY
        profile.warnings = calorie_consistency_warnings(profile.estimated_nutrients)
        profile.calculated_calories_kcal = macro_calories(
            profile.estimated_nutrients
        )
    if validated_data.get("status") == CustomFoodProfile.Status.ARCHIVED:
        profile.status = CustomFoodProfile.Status.ARCHIVED
        food.is_deprecated = True
    food.save()
    profile.version_number += 1
    profile.save()
    record_custom_food_version(profile, "updated")
    return food


@transaction.atomic
def confirm_custom_food(
    profile: CustomFoodProfile,
    *,
    final_nutrients: dict | None = None,
    use_estimate: bool = False,
    serving_weight_g: Decimal | None = None,
) -> Food:
    if use_estimate:
        values = profile.estimated_nutrients
    else:
        base_values = profile.confirmed_nutrients or profile.estimated_nutrients
        changes = final_nutrients or profile.user_corrections
        values = {**base_values, **changes} if changes else {}
    if not values:
        raise ValidationError(
            {"final_nutrients": "Edit values or explicitly accept the estimate."}
        )
    if serving_weight_g is not None:
        profile.serving_weight_g = serving_weight_g
        _replace_default_serving(
            profile.food,
            profile.food.serving_description,
            serving_weight_g,
        )
    normalized_values = {
        field: decimal_string(Decimal(str(value)))
        for field, value in values.items()
        if field in CUSTOM_NUTRIENT_FIELDS and value not in (None, "")
    }
    profile.user_corrections = {
        field: value
        for field, value in normalized_values.items()
        if value != profile.estimated_nutrients.get(field)
    }
    profile.confirmed_nutrients = normalized_values
    profile.calculated_calories_kcal = macro_calories(normalized_values)
    profile.warnings = calorie_consistency_warnings(normalized_values)
    profile.status = CustomFoodProfile.Status.CONFIRMED
    profile.confirmed_at = timezone.now()
    profile.food.is_deprecated = False
    write_confirmed_nutrients(profile, normalized_values)
    profile.food.quality_warnings = profile.warnings
    profile.food.save()
    profile.food._prefetched_objects_cache = {}
    profile.version_number += 1
    profile.save()
    record_custom_food_version(profile, "confirmed")
    return profile.food
