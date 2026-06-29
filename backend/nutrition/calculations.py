from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal, InvalidOperation

from django.db.models import Q
from rest_framework.exceptions import ValidationError

MACRO_CODES = ("protein_g", "carbs_g", "fat_g")
SUMMARY_NUTRIENT_CODES = (
    "calories",
    "protein_g",
    "carbs_g",
    "fat_g",
    "fiber_g",
    "sugar_g",
    "sodium_mg",
)
DEFAULT_DAILY_TARGETS = {
    "calories_kcal": Decimal("2000.000"),
    "protein_g": Decimal("75.000"),
    "carbs_g": Decimal("250.000"),
    "fat_g": Decimal("70.000"),
    "fiber_g": Decimal("30.000"),
    "sugar_g": Decimal("50.000"),
    "sodium_mg": Decimal("2300.000"),
}
VOLUME_GRAM_ESTIMATES = {
    "ml": Decimal("1.000"),
    "cup": Decimal("240.000"),
    "tbsp": Decimal("15.000"),
    "tsp": Decimal("5.000"),
}


def to_decimal(value, *, default: Decimal | None = None) -> Decimal:
    if value is None or value == "":
        if default is not None:
            return default
        raise ValidationError("A numeric value is required.")
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError) as exc:
        raise ValidationError("Enter a valid decimal value.") from exc


def quantize_decimal(value: Decimal, places: str = "0.001") -> Decimal:
    return value.quantize(Decimal(places), rounding=ROUND_HALF_UP)


def decimal_to_snapshot(value: Decimal) -> str:
    return str(quantize_decimal(value))


def snapshot_to_decimal(snapshot: dict, code: str) -> Decimal:
    return to_decimal(snapshot.get(code), default=Decimal("0"))


def get_default_serving(food):
    default_serving = next(
        (serving for serving in food.servings.all() if serving.is_default),
        None,
    )
    if default_serving:
        return default_serving
    return next(iter(food.servings.all()), None)


def calculate_grams_for_food(
    *,
    food,
    quantity,
    unit: str,
    serving=None,
    grams_calculated=None,
) -> Decimal:
    quantity_decimal = to_decimal(quantity)
    if quantity_decimal <= 0:
        raise ValidationError({"quantity": "Quantity must be greater than zero."})

    provided_grams = (
        to_decimal(grams_calculated) if grams_calculated not in (None, "") else None
    )
    if provided_grams is not None and provided_grams <= 0:
        raise ValidationError(
            {"grams_calculated": "Calculated grams must be greater than zero."}
        )

    if unit == "grams":
        return quantize_decimal(quantity_decimal)

    if unit == "serving":
        serving = serving or get_default_serving(food)
        if not serving:
            raise ValidationError(
                {"serving": "Choose a serving or log this food in grams."}
            )
        if serving.food_id != food.id:
            raise ValidationError({"serving": "Serving does not belong to this food."})
        return quantize_decimal(quantity_decimal * serving.grams)

    if unit == "piece":
        if food.default_serving_g:
            return quantize_decimal(quantity_decimal * food.default_serving_g)
        if provided_grams is not None:
            return quantize_decimal(provided_grams)
        raise ValidationError(
            {"grams_calculated": "Piece logging requires a known gram weight."}
        )

    if unit in VOLUME_GRAM_ESTIMATES:
        if provided_grams is not None:
            return quantize_decimal(provided_grams)
        return quantize_decimal(quantity_decimal * VOLUME_GRAM_ESTIMATES[unit])

    if unit == "custom" and provided_grams is not None:
        return quantize_decimal(provided_grams)

    raise ValidationError(
        {"grams_calculated": "This unit requires an explicit gram conversion."}
    )


def select_best_nutrient_values(food):
    selected = {}
    for value in food.nutrients.select_related("nutrient", "source").all():
        current = selected.get(value.nutrient.code)
        current_score = (
            (
                current.confidence_score,
                current.source.reliability_score,
            )
            if current
            else None
        )
        value_score = (
            value.confidence_score,
            value.source.reliability_score,
        )
        if current is None or value_score > current_score:
            selected[value.nutrient.code] = value
    return selected


def calculate_food_snapshot(food, grams: Decimal) -> dict:
    selected_values = select_best_nutrient_values(food)
    scale = grams / Decimal("100")
    nutrients_snapshot = {}
    confidences = []

    for code, value in selected_values.items():
        amount = quantize_decimal(value.amount_per_100g * scale)
        nutrients_snapshot[code] = decimal_to_snapshot(amount)
        confidences.append(value.confidence_score)

    macros_snapshot = {
        code: nutrients_snapshot.get(code, decimal_to_snapshot(Decimal("0")))
        for code in SUMMARY_NUTRIENT_CODES
        if code != "calories"
    }
    calories = snapshot_to_decimal(nutrients_snapshot, "calories")
    if confidences:
        source_confidence = quantize_decimal(
            sum(confidences) / Decimal(len(confidences)),
            "0.0001",
        )
    else:
        source_confidence = quantize_decimal(food.data_quality_score, "0.0001")

    return {
        "calories_kcal": calories,
        "macros_snapshot": macros_snapshot,
        "nutrients_snapshot": nutrients_snapshot,
        "source_confidence": source_confidence,
    }


def add_snapshot_totals(totals: dict[str, Decimal], snapshot: dict) -> None:
    for code, value in snapshot.items():
        totals[code] = totals.get(code, Decimal("0")) + to_decimal(value)


def macro_percentage_split(values: dict) -> dict[str, str]:
    protein_calories = to_decimal(values.get("protein_g"), default=Decimal("0")) * 4
    carbs_calories = to_decimal(values.get("carbs_g"), default=Decimal("0")) * 4
    fat_calories = to_decimal(values.get("fat_g"), default=Decimal("0")) * 9
    macro_calories = protein_calories + carbs_calories + fat_calories
    if macro_calories <= 0:
        return {"protein": "0.0", "carbs": "0.0", "fat": "0.0"}
    return {
        "protein": str(
            quantize_decimal(protein_calories / macro_calories * 100, "0.1")
        ),
        "carbs": str(quantize_decimal(carbs_calories / macro_calories * 100, "0.1")),
        "fat": str(quantize_decimal(fat_calories / macro_calories * 100, "0.1")),
    }


def daily_targets_for_user(user, date) -> dict[str, Decimal]:
    targets = DEFAULT_DAILY_TARGETS.copy()
    from goals.models import Goal

    goals = Goal.objects.filter(
        Q(end_date__isnull=True) | Q(end_date__gte=date),
        user=user,
        start_date__lte=date,
        status=Goal.Status.ACTIVE,
    )
    for goal in goals:
        if goal.goal_type == Goal.GoalType.CALORIES:
            targets["calories_kcal"] = quantize_decimal(goal.target_value)
        elif goal.goal_type == Goal.GoalType.PROTEIN:
            targets["protein_g"] = quantize_decimal(goal.target_value)
    return targets


def target_progress_for_values(values: dict, targets: dict[str, Decimal]) -> dict:
    progress = {}
    for code, target in targets.items():
        consumed = to_decimal(values.get(code), default=Decimal("0"))
        percent = Decimal("0")
        if target > 0:
            percent = consumed / target * 100
        progress[code] = {
            "consumed": decimal_to_snapshot(consumed),
            "target": decimal_to_snapshot(target),
            "percent": str(quantize_decimal(percent, "0.1")),
        }
    return progress
