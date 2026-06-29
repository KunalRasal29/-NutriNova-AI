from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from meals.models import DailyNutritionSummary, MealLog, MealLogItem
from nutrition.calculations import (
    SUMMARY_NUTRIENT_CODES,
    add_snapshot_totals,
    daily_targets_for_user,
    decimal_to_snapshot,
    macro_percentage_split,
    target_progress_for_values,
)

SUMMARY_MODEL_CODE_MAP = {
    "calories": "calories_kcal",
    "protein_g": "protein_g",
    "carbs_g": "carbs_g",
    "fat_g": "fat_g",
    "fiber_g": "fiber_g",
    "sugar_g": "sugar_g",
    "sodium_mg": "sodium_mg",
}


def _zero_totals() -> dict[str, Decimal]:
    return {code: Decimal("0") for code in SUMMARY_NUTRIENT_CODES}


def build_daily_totals(user, date) -> dict[str, Decimal]:
    totals = _zero_totals()
    items = MealLogItem.objects.filter(
        user=user,
        meal_log__date=date,
    ).only("nutrients_snapshot")
    for item in items:
        add_snapshot_totals(totals, item.nutrients_snapshot)
    return totals


def recompute_daily_summary(user, date) -> DailyNutritionSummary:
    totals = build_daily_totals(user, date)
    defaults = {
        model_field: totals.get(code, Decimal("0"))
        for code, model_field in SUMMARY_MODEL_CODE_MAP.items()
    }
    defaults["micronutrients"] = {
        code: decimal_to_snapshot(value)
        for code, value in totals.items()
        if code not in SUMMARY_NUTRIENT_CODES
    }
    defaults["generated_at"] = timezone.now()
    summary, _ = DailyNutritionSummary.objects.update_or_create(
        user=user,
        date=date,
        defaults=defaults,
    )
    return summary


def summary_payload(summary: DailyNutritionSummary) -> dict:
    values = {
        "calories_kcal": summary.calories_kcal,
        "protein_g": summary.protein_g,
        "carbs_g": summary.carbs_g,
        "fat_g": summary.fat_g,
        "fiber_g": summary.fiber_g,
        "sugar_g": summary.sugar_g,
        "sodium_mg": summary.sodium_mg,
    }
    targets = daily_targets_for_user(summary.user, summary.date)
    return {
        "id": summary.id,
        "date": summary.date,
        **values,
        "micronutrients": summary.micronutrients,
        "macro_percentage_split": macro_percentage_split(values),
        "daily_target_progress": target_progress_for_values(values, targets),
        "generated_at": summary.generated_at,
    }


def get_or_recompute_daily_summary(user, date) -> DailyNutritionSummary:
    return recompute_daily_summary(user, date)


@transaction.atomic
def copy_meals_from_previous_day(user, target_date):
    source_date = target_date - timedelta(days=1)
    source_meals = (
        MealLog.objects.filter(user=user, date=source_date)
        .prefetch_related("items")
        .order_by("created_at")
    )
    copied_meals = []
    for source_meal in source_meals:
        copied_meal = MealLog.objects.create(
            user=user,
            date=target_date,
            meal_type=source_meal.meal_type,
            name=source_meal.name,
            notes=source_meal.notes,
            timezone=source_meal.timezone,
            is_favorite=source_meal.is_favorite,
        )
        copied_items = [
            MealLogItem(
                user=user,
                meal_log=copied_meal,
                food=item.food,
                quantity=item.quantity,
                unit=item.unit,
                grams_calculated=item.grams_calculated,
                serving=item.serving,
                calories_kcal=item.calories_kcal,
                macros_snapshot=item.macros_snapshot,
                nutrients_snapshot=item.nutrients_snapshot,
                source_confidence=item.source_confidence,
                user_confirmed=item.user_confirmed,
            )
            for item in source_meal.items.all()
        ]
        MealLogItem.objects.bulk_create(copied_items)
        copied_meals.append(copied_meal)

    recompute_daily_summary(user, target_date)
    return copied_meals
