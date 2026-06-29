from __future__ import annotations

from decimal import Decimal

from django.db import transaction
from rest_framework.exceptions import ValidationError

from foods.models import Food, FoodServing
from meals.models import MealLog, MealLogItem
from meals.services import recompute_daily_summary
from nutrition.calculations import calculate_food_snapshot, quantize_decimal

MANUAL_QUANTITY_UNITS = (
    "piece",
    "egg",
    "slice",
    "bowl",
    "cup",
    "glass",
    "tablespoon",
    "teaspoon",
    "serving",
    "gram",
    "ml",
    "handful",
    "scoop",
    "packet",
    "custom",
)
MANUAL_QUANTITY_LABELS = {
    "piece": "Piece",
    "egg": "Egg",
    "slice": "Slice",
    "bowl": "Bowl",
    "cup": "Cup",
    "glass": "Glass",
    "tablespoon": "Tablespoon",
    "teaspoon": "Teaspoon",
    "serving": "Serving",
    "gram": "Gram",
    "ml": "Milliliter",
    "handful": "Handful",
    "scoop": "Scoop",
    "packet": "Packet",
    "custom": "Custom",
}
MANUAL_QUANTITY_CHOICES = tuple(
    (unit, MANUAL_QUANTITY_LABELS[unit]) for unit in MANUAL_QUANTITY_UNITS
)
COUNTABLE_UNITS = {
    "piece",
    "egg",
    "slice",
    "serving",
    "handful",
    "scoop",
    "packet",
}
UNIT_ALIASES = {
    "egg": {"egg", "eggs", "whole egg", "boiled egg"},
    "piece": {"piece", "pieces", "pc", "pcs", "unit"},
    "slice": {"slice", "slices"},
    "bowl": {"bowl", "katori"},
    "cup": {"cup", "cups"},
    "glass": {"glass", "glasses"},
    "tablespoon": {"tablespoon", "tbsp"},
    "teaspoon": {"teaspoon", "tsp"},
    "serving": {"serving", "serve", "portion"},
    "handful": {"handful"},
    "scoop": {"scoop"},
    "packet": {"packet", "pack", "package"},
    "gram": {"g", "gram", "grams"},
    "ml": {"ml", "milliliter", "millilitre"},
}
FALLBACK_GRAM_ESTIMATES = {
    "cup": Decimal("240.000"),
    "glass": Decimal("240.000"),
    "tablespoon": Decimal("15.000"),
    "teaspoon": Decimal("5.000"),
}


def normalize_manual_unit(value: str | None) -> str:
    normalized = " ".join((value or "serving").strip().lower().split())
    unit_map = {
        "g": "gram",
        "gram": "gram",
        "grams": "gram",
        "tbsp": "tablespoon",
        "tablespoon": "tablespoon",
        "tablespoons": "tablespoon",
        "tsp": "teaspoon",
        "teaspoon": "teaspoon",
        "teaspoons": "teaspoon",
        "eggs": "egg",
        "pieces": "piece",
        "slices": "slice",
        "servings": "serving",
        "cups": "cup",
        "bowls": "bowl",
        "glasses": "glass",
        "handfuls": "handful",
        "scoops": "scoop",
        "packets": "packet",
    }
    normalized = unit_map.get(normalized, normalized)
    if normalized in MANUAL_QUANTITY_UNITS:
        return normalized
    return "custom"


def serving_matches_unit(serving: FoodServing, quantity_unit: str) -> bool:
    aliases = UNIT_ALIASES.get(quantity_unit, {quantity_unit})
    text = " ".join(
        value
        for value in (
            serving.serving_name,
            serving.household_quantity,
        )
        if value
    ).lower()
    return any(alias in text for alias in aliases)


def find_serving_for_unit(food: Food, quantity_unit: str) -> FoodServing | None:
    servings = list(food.servings.all())
    for serving in servings:
        if serving_matches_unit(serving, quantity_unit):
            return serving
    default_serving = next(
        (serving for serving in servings if serving.is_default),
        None,
    )
    if quantity_unit == "serving":
        return default_serving
    return None


def meal_item_unit_for(quantity_unit: str, serving: FoodServing | None) -> str:
    if quantity_unit == "gram":
        return MealLogItem.Unit.GRAMS
    if quantity_unit == "ml":
        return MealLogItem.Unit.ML
    if quantity_unit == "cup":
        return MealLogItem.Unit.CUP
    if quantity_unit == "tablespoon":
        return MealLogItem.Unit.TBSP
    if quantity_unit == "teaspoon":
        return MealLogItem.Unit.TSP
    if quantity_unit in {"piece", "egg", "slice"}:
        return MealLogItem.Unit.PIECE
    if serving:
        return MealLogItem.Unit.SERVING
    return MealLogItem.Unit.CUSTOM


def calculate_manual_grams(
    *,
    food: Food,
    quantity_value: Decimal,
    quantity_unit: str,
    total_grams: Decimal | None = None,
) -> tuple[Decimal, FoodServing | None, list[str]]:
    warnings = []
    quantity_unit = normalize_manual_unit(quantity_unit)
    if quantity_value <= 0:
        raise ValidationError({"quantity_value": "Quantity must be greater than zero."})
    if total_grams is not None:
        if total_grams <= 0:
            raise ValidationError({"total_grams": "Total grams must be positive."})
        return quantize_decimal(total_grams), None, warnings
    if quantity_unit == "gram":
        return quantize_decimal(quantity_value), None, warnings
    if quantity_unit == "ml":
        return quantize_decimal(quantity_value), None, warnings

    serving = find_serving_for_unit(food, quantity_unit)
    if serving:
        return quantize_decimal(quantity_value * serving.grams), serving, warnings

    if quantity_unit in COUNTABLE_UNITS and food.default_serving_g:
        return quantize_decimal(quantity_value * food.default_serving_g), None, warnings

    if quantity_unit in FALLBACK_GRAM_ESTIMATES:
        warnings.append("estimated volume to grams conversion")
        return (
            quantize_decimal(quantity_value * FALLBACK_GRAM_ESTIMATES[quantity_unit]),
            None,
            warnings,
        )

    raise ValidationError(
        {
            "total_grams": (
                "Enter grams because this food does not have a matching serving."
            )
        }
    )


def manual_food_preview(
    *,
    food: Food,
    quantity_value: Decimal,
    quantity_unit: str,
    total_grams: Decimal | None = None,
) -> dict:
    quantity_unit = normalize_manual_unit(quantity_unit)
    grams, serving, warnings = calculate_manual_grams(
        food=food,
        quantity_value=quantity_value,
        quantity_unit=quantity_unit,
        total_grams=total_grams,
    )
    snapshot = calculate_food_snapshot(food, grams)
    nutrients = snapshot["nutrients_snapshot"]
    return {
        "food_id": food.id,
        "food_name": food.canonical_name,
        "brand": food.brand_name,
        "quantity_value": quantity_value,
        "quantity_unit": quantity_unit,
        "serving_id": serving.id if serving else None,
        "effective_total_grams": grams,
        "calories_kcal": snapshot["calories_kcal"],
        "protein_g": nutrients.get("protein_g", "0.000"),
        "carbs_g": nutrients.get("carbs_g", "0.000"),
        "fat_g": nutrients.get("fat_g", "0.000"),
        "fiber_g": nutrients.get("fiber_g", "0.000"),
        "sugar_g": nutrients.get("sugar_g", "0.000"),
        "sodium_mg": nutrients.get("sodium_mg", "0.000"),
        "macros_snapshot": snapshot["macros_snapshot"],
        "nutrients_snapshot": nutrients,
        "source_confidence": snapshot["source_confidence"],
        "source_badge": food.source.source_type,
        "warnings": warnings,
    }


def get_or_create_manual_meal(user, *, date, meal_type, timezone_name="UTC") -> MealLog:
    meal_log = (
        MealLog.objects.filter(user=user, date=date, meal_type=meal_type)
        .order_by("created_at")
        .first()
    )
    if meal_log:
        return meal_log
    return MealLog.objects.create(
        user=user,
        date=date,
        meal_type=meal_type,
        name=meal_type.replace("_", " ").title(),
        timezone=timezone_name or getattr(user, "timezone", "UTC"),
    )


@transaction.atomic
def add_food_to_meal(user, validated_data: dict) -> tuple[MealLog, MealLogItem, dict]:
    food = validated_data["food"]
    quantity_value = validated_data["quantity_value"]
    quantity_unit = normalize_manual_unit(validated_data.get("quantity_unit"))
    total_grams = validated_data.get("total_grams")
    preview = manual_food_preview(
        food=food,
        quantity_value=quantity_value,
        quantity_unit=quantity_unit,
        total_grams=total_grams,
    )
    serving = None
    if preview["serving_id"]:
        serving = FoodServing.objects.get(id=preview["serving_id"])
    meal_log = get_or_create_manual_meal(
        user,
        date=validated_data["date"],
        meal_type=validated_data["meal_type"],
        timezone_name=(
            validated_data.get("timezone") or getattr(user, "timezone", "UTC")
        ),
    )
    item = MealLogItem.objects.create(
        user=user,
        meal_log=meal_log,
        food=food,
        quantity=quantity_value,
        unit=meal_item_unit_for(quantity_unit, serving),
        grams_calculated=preview["effective_total_grams"],
        serving=serving,
        calories_kcal=preview["calories_kcal"],
        macros_snapshot=preview["macros_snapshot"],
        nutrients_snapshot=preview["nutrients_snapshot"],
        source_confidence=preview["source_confidence"],
        user_confirmed=True,
    )
    recompute_daily_summary(user, meal_log.date)
    return meal_log, item, preview
