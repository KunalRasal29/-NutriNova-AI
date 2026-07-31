from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal

from foods.models import Food

CORE_MACROS = ("calories", "protein_g", "carbs_g", "fat_g")
COMPLETENESS_NUTRIENTS = CORE_MACROS + ("fiber_g", "sugar_g", "sodium_mg")


@dataclass(frozen=True, slots=True)
class FoodQualityAssessment:
    completeness_score: Decimal
    quality_score: Decimal
    warnings: tuple[str, ...]


def _bounded(value: Decimal) -> Decimal:
    return max(Decimal("0"), min(Decimal("1"), value))


def assess_food_quality(food: Food) -> FoodQualityAssessment:
    nutrient_values = {
        item.nutrient.code: item.amount_per_100g for item in food.nutrients.all()
    }
    present = sum(code in nutrient_values for code in COMPLETENESS_NUTRIENTS)
    completeness = Decimal(present) / Decimal(len(COMPLETENESS_NUTRIENTS))
    warnings: list[str] = []

    for code, amount in nutrient_values.items():
        if amount < 0:
            warnings.append(f"negative_nutrient:{code}")

    serving_weights = [serving.grams for serving in food.servings.all()]
    if food.default_serving_g is not None:
        serving_weights.append(food.default_serving_g)
    if any(weight <= 0 for weight in serving_weights):
        warnings.append("invalid_serving_weight")
    if any(weight > Decimal("5000") for weight in serving_weights):
        warnings.append("suspicious_serving_weight")

    missing_macros = [code for code in CORE_MACROS if code not in nutrient_values]
    if missing_macros:
        warnings.append(f"missing_core_macros:{','.join(missing_macros)}")

    calories = nutrient_values.get("calories")
    protein = nutrient_values.get("protein_g")
    carbs = nutrient_values.get("carbs_g")
    fat = nutrient_values.get("fat_g")
    if None not in (calories, protein, carbs, fat):
        calculated = protein * Decimal("4") + carbs * Decimal("4") + fat * Decimal("9")
        tolerance = max(Decimal("50"), abs(calories) * Decimal("0.35"))
        if abs(calories - calculated) > tolerance:
            warnings.append("macro_calorie_mismatch")
    if calories is not None and calories > Decimal("2000"):
        warnings.append("possible_kj_stored_as_kcal")
    if nutrient_values.get("sodium_mg", Decimal("0")) > Decimal("50000"):
        warnings.append("possible_salt_sodium_unit_error")

    source_reliability = food.source.reliability_score or Decimal("0")
    warning_penalty = min(Decimal("0.60"), Decimal(len(warnings)) * Decimal("0.10"))
    verified_bonus = Decimal("0.05") if food.verified else Decimal("0")
    quality = _bounded(
        source_reliability * Decimal("0.55")
        + completeness * Decimal("0.40")
        + verified_bonus
        - warning_penalty
    )
    return FoodQualityAssessment(
        completeness_score=completeness.quantize(Decimal("0.0001")),
        quality_score=quality.quantize(Decimal("0.0001")),
        warnings=tuple(warnings),
    )


def apply_food_quality_assessment(food: Food) -> FoodQualityAssessment:
    assessment = assess_food_quality(food)
    Food.objects.filter(pk=food.pk).update(
        completeness_score=assessment.completeness_score,
        data_quality_score=assessment.quality_score,
        quality_warnings=list(assessment.warnings),
    )
    return assessment
