from __future__ import annotations

from decimal import Decimal
from difflib import SequenceMatcher

from django.db.models import Q

from foods.models import Food, FoodServing
from nutrition.calculations import calculate_food_snapshot, quantize_decimal
from photos.models import PhotoDetectedFood
from photos.url_utils import public_image_url

LOW_CONFIDENCE_THRESHOLD = Decimal("0.7000")
COUNTABLE_UNITS = {
    PhotoDetectedFood.QuantityUnit.PIECE,
    PhotoDetectedFood.QuantityUnit.EGG,
    PhotoDetectedFood.QuantityUnit.SLICE,
    PhotoDetectedFood.QuantityUnit.BOWL,
    PhotoDetectedFood.QuantityUnit.CUP,
    PhotoDetectedFood.QuantityUnit.GLASS,
    PhotoDetectedFood.QuantityUnit.TABLESPOON,
    PhotoDetectedFood.QuantityUnit.TEASPOON,
    PhotoDetectedFood.QuantityUnit.SERVING,
    PhotoDetectedFood.QuantityUnit.HANDFUL,
    PhotoDetectedFood.QuantityUnit.SCOOP,
    PhotoDetectedFood.QuantityUnit.PACKET,
}
UNIT_ALIASES = {
    PhotoDetectedFood.QuantityUnit.EGG: {"egg", "eggs", "whole egg", "boiled egg"},
    PhotoDetectedFood.QuantityUnit.PIECE: {"piece", "pieces", "pc", "pcs", "unit"},
    PhotoDetectedFood.QuantityUnit.SLICE: {"slice", "slices"},
    PhotoDetectedFood.QuantityUnit.BOWL: {"bowl", "katori"},
    PhotoDetectedFood.QuantityUnit.CUP: {"cup", "cups"},
    PhotoDetectedFood.QuantityUnit.GLASS: {"glass", "glasses"},
    PhotoDetectedFood.QuantityUnit.TABLESPOON: {"tablespoon", "tbsp"},
    PhotoDetectedFood.QuantityUnit.TEASPOON: {"teaspoon", "tsp"},
    PhotoDetectedFood.QuantityUnit.SERVING: {"serving", "serve", "portion"},
    PhotoDetectedFood.QuantityUnit.HANDFUL: {"handful"},
    PhotoDetectedFood.QuantityUnit.SCOOP: {"scoop"},
    PhotoDetectedFood.QuantityUnit.PACKET: {"packet", "pack", "package"},
    PhotoDetectedFood.QuantityUnit.GRAM: {"g", "gram", "grams"},
    PhotoDetectedFood.QuantityUnit.ML: {"ml", "milliliter", "millilitre"},
}
FOOD_ALIAS_MAP = {
    "boiled egg": ["egg", "whole egg", "egg whole boiled", "boiled eggs"],
    "egg": ["boiled egg", "whole egg", "egg whole"],
    "roti": ["chapati", "phulka", "roti"],
    "chapati": ["roti", "phulka", "chapati"],
    "curd": ["yogurt", "yoghurt", "curd"],
    "yogurt": ["curd", "yoghurt", "yogurt"],
    "dal": ["lentil soup", "lentils", "dal"],
    "banana": ["banana", "ripe banana"],
}
SUMMARY_CODES = (
    "calories",
    "protein_g",
    "carbs_g",
    "fat_g",
    "fiber_g",
    "sugar_g",
    "sodium_mg",
)


def visible_foods_for_user(user):
    if not user.is_authenticated:
        return Food.objects.none()
    return Food.objects.filter(Q(created_by__isnull=True) | Q(created_by=user))


def normalize_name(value: str) -> str:
    return " ".join((value or "").lower().replace(",", " ").split())


def normalize_quantity_unit(value: str | None) -> str | None:
    if not value:
        return None
    normalized = normalize_name(value).replace(" ", "_")
    unit_map = {
        "eggs": PhotoDetectedFood.QuantityUnit.EGG,
        "g": PhotoDetectedFood.QuantityUnit.GRAM,
        "gram": PhotoDetectedFood.QuantityUnit.GRAM,
        "grams": PhotoDetectedFood.QuantityUnit.GRAM,
        "tablespoon": PhotoDetectedFood.QuantityUnit.TABLESPOON,
        "tbsp": PhotoDetectedFood.QuantityUnit.TABLESPOON,
        "teaspoon": PhotoDetectedFood.QuantityUnit.TEASPOON,
        "tsp": PhotoDetectedFood.QuantityUnit.TEASPOON,
        "servings": PhotoDetectedFood.QuantityUnit.SERVING,
        "cups": PhotoDetectedFood.QuantityUnit.CUP,
        "pieces": PhotoDetectedFood.QuantityUnit.PIECE,
        "slices": PhotoDetectedFood.QuantityUnit.SLICE,
    }
    if normalized in unit_map:
        return unit_map[normalized]
    valid_values = {choice.value for choice in PhotoDetectedFood.QuantityUnit}
    if normalized in valid_values:
        return normalized
    return PhotoDetectedFood.QuantityUnit.CUSTOM


def search_aliases(name: str) -> list[str]:
    normalized = normalize_name(name)
    aliases = {normalized}
    for key, values in FOOD_ALIAS_MAP.items():
        if key in normalized or normalized in key:
            aliases.update(values)
    if "egg" in normalized:
        aliases.update(FOOD_ALIAS_MAP["egg"])
    if "roti" in normalized or "chapati" in normalized:
        aliases.update(FOOD_ALIAS_MAP["roti"])
    if "curd" in normalized or "yogurt" in normalized:
        aliases.update(FOOD_ALIAS_MAP["curd"])
    if "dal" in normalized:
        aliases.update(FOOD_ALIAS_MAP["dal"])
    return [alias for alias in aliases if alias]


def food_match_score(food: Food, detected_name: str) -> Decimal:
    candidates = [
        food.canonical_name,
        food.brand_name,
        *(alias.alias for alias in food.aliases.all()),
    ]
    aliases = search_aliases(detected_name)
    best = Decimal("0")
    for alias in aliases:
        for candidate in candidates:
            candidate_value = normalize_name(candidate)
            if not alias or not candidate_value:
                continue
            if candidate_value == alias:
                return Decimal("1.0000")
            if alias in candidate_value or candidate_value in alias:
                best = max(best, Decimal("0.9000"))
            similarity = Decimal(
                str(SequenceMatcher(None, alias, candidate_value).ratio())
            )
            best = max(best, similarity)
    return quantize_decimal(best, "0.0001")


def top_food_matches_for_user(
    user,
    detected_name: str,
    *,
    limit: int = 5,
) -> list[dict]:
    scored = []
    foods = visible_foods_for_user(user).prefetch_related(
        "aliases",
        "servings",
        "nutrients__nutrient",
        "nutrients__source",
    )[:500]
    for food in foods:
        score = food_match_score(food, detected_name)
        if score >= Decimal("0.2500"):
            scored.append((score, food))
    scored.sort(key=lambda item: item[0], reverse=True)
    return [
        {
            "id": food.id,
            "name": food.canonical_name,
            "brand": food.brand_name,
            "score": str(score),
            "data_source": food.source.name,
            "verified": food.verified,
            "default_serving_g": food.default_serving_g,
        }
        for score, food in scored[:limit]
    ]


def match_food_name_for_user(user, detected_name: str):
    matches = top_food_matches_for_user(user, detected_name, limit=1)
    if not matches:
        return None, Decimal("0")
    score = Decimal(str(matches[0]["score"]))
    if score < LOW_CONFIDENCE_THRESHOLD:
        return None, score
    return Food.objects.get(id=matches[0]["id"]), score


def serving_matches_unit(serving: FoodServing, quantity_unit: str | None) -> bool:
    if not quantity_unit:
        return False
    aliases = UNIT_ALIASES.get(quantity_unit, {quantity_unit})
    text = normalize_name(
        " ".join(
            value
            for value in (
                serving.serving_name,
                serving.household_quantity,
            )
            if value
        )
    )
    return any(alias in text for alias in aliases)


def find_serving_grams(food: Food, quantity_unit: str | None) -> Decimal | None:
    servings = list(food.servings.all())
    for serving in servings:
        if serving_matches_unit(serving, quantity_unit):
            return Decimal(serving.grams)
    default_serving = next(
        (serving for serving in servings if serving.is_default),
        None,
    )
    if quantity_unit == PhotoDetectedFood.QuantityUnit.SERVING and default_serving:
        return Decimal(default_serving.grams)
    if (
        quantity_unit
        in {
            PhotoDetectedFood.QuantityUnit.PIECE,
            PhotoDetectedFood.QuantityUnit.SERVING,
        }
        and food.default_serving_g
    ):
        return Decimal(food.default_serving_g)
    return None


def effective_quantity(
    detected: PhotoDetectedFood,
) -> tuple[Decimal | None, str | None]:
    quantity = (
        detected.user_quantity_value
        if detected.user_quantity_value is not None
        else detected.quantity_value
    )
    unit = detected.user_quantity_unit or detected.quantity_unit
    return quantity, unit


def effective_total_grams(detected: PhotoDetectedFood) -> Decimal | None:
    if detected.user_total_grams is not None:
        return Decimal(detected.user_total_grams)
    if detected.user_corrected_grams is not None:
        return Decimal(detected.user_corrected_grams)

    quantity, unit = effective_quantity(detected)
    if quantity is not None and unit == PhotoDetectedFood.QuantityUnit.GRAM:
        return Decimal(quantity)
    if quantity is not None and unit == PhotoDetectedFood.QuantityUnit.ML:
        return Decimal(quantity)

    if quantity is not None and detected.matched_food_id:
        serving_grams = find_serving_grams(detected.matched_food, unit)
        if serving_grams:
            return quantize_decimal(Decimal(quantity) * serving_grams)

    if quantity is not None and detected.grams_per_unit_estimate:
        return quantize_decimal(Decimal(quantity) * detected.grams_per_unit_estimate)

    if detected.total_grams_estimate is not None:
        return Decimal(detected.total_grams_estimate)
    if detected.grams_estimate is not None:
        return Decimal(detected.grams_estimate)
    return None


def source_badges_for_food(food: Food | None) -> list[dict]:
    if not food:
        return []
    return [
        {
            "source_name": food.source.name,
            "source_type": food.source.source_type,
            "reliability_score": str(food.source.reliability_score),
            "food_verified": food.verified,
        }
    ]


def item_warnings(
    detected: PhotoDetectedFood,
    effective_grams: Decimal | None,
) -> list[str]:
    warnings = []
    if detected.is_removed:
        return ["removed"]
    if not detected.matched_food_id:
        warnings.append("low confidence food match")
    if detected.confidence_score < LOW_CONFIDENCE_THRESHOLD:
        warnings.append("AI estimate needs review")
    if (
        detected.count_confidence is not None
        and detected.count_confidence < LOW_CONFIDENCE_THRESHOLD
    ):
        warnings.append("low confidence portion estimate")
    if (
        detected.portion_confidence is not None
        and detected.portion_confidence < LOW_CONFIDENCE_THRESHOLD
    ):
        warnings.append("low confidence portion estimate")
    if effective_grams is None or effective_grams <= 0:
        warnings.append("grams missing")
    return sorted(set(warnings))


def item_nutrition_preview(detected: PhotoDetectedFood, *, include_alternatives=True):
    quantity, unit = effective_quantity(detected)
    grams = effective_total_grams(detected)
    snapshot = {
        "calories_kcal": Decimal("0"),
        "macros_snapshot": {},
        "nutrients_snapshot": {},
        "source_confidence": Decimal("0"),
    }
    if grams and grams > 0 and detected.matched_food_id and not detected.is_removed:
        snapshot = calculate_food_snapshot(detected.matched_food, grams)
    nutrients = snapshot["nutrients_snapshot"]
    payload = {
        "id": detected.id,
        "detected_name": detected.detected_name,
        "normalized_name": detected.normalized_name,
        "matched_food": detected.matched_food_id,
        "matched_food_name": (
            detected.matched_food.canonical_name if detected.matched_food_id else ""
        ),
        "quantity_value": detected.quantity_value,
        "quantity_unit": detected.quantity_unit,
        "user_quantity_value": detected.user_quantity_value,
        "user_quantity_unit": detected.user_quantity_unit,
        "effective_quantity_value": quantity,
        "effective_quantity_unit": unit,
        "grams_per_unit_estimate": detected.grams_per_unit_estimate,
        "total_grams_estimate": detected.total_grams_estimate,
        "min_total_grams_estimate": detected.min_total_grams_estimate,
        "max_total_grams_estimate": detected.max_total_grams_estimate,
        "user_total_grams": detected.user_total_grams,
        "effective_total_grams": grams,
        "calories_kcal": snapshot["calories_kcal"],
        "protein_g": nutrients.get("protein_g", "0.000"),
        "carbs_g": nutrients.get("carbs_g", "0.000"),
        "fat_g": nutrients.get("fat_g", "0.000"),
        "fiber_g": nutrients.get("fiber_g", "0.000"),
        "sugar_g": nutrients.get("sugar_g", "0.000"),
        "sodium_mg": nutrients.get("sodium_mg", "0.000"),
        "nutrients_snapshot": nutrients,
        "confidence_score": detected.confidence_score,
        "count_confidence": detected.count_confidence,
        "portion_confidence": detected.portion_confidence,
        "source_confidence": snapshot["source_confidence"],
        "source_badges": source_badges_for_food(detected.matched_food),
        "warnings": item_warnings(detected, grams),
        "is_user_corrected": detected.is_user_corrected,
        "is_removed": detected.is_removed,
        "added_manually": detected.added_manually,
        "correction_note": detected.correction_note,
        "reasoning_short": detected.reasoning_short,
        "alternative_matches": [],
    }
    if include_alternatives and detected.photo_analysis_id:
        payload["alternative_matches"] = top_food_matches_for_user(
            detected.photo_analysis.user,
            detected.normalized_name or detected.detected_name,
            limit=5,
        )
    return payload


def update_item_preview_snapshot(detected: PhotoDetectedFood):
    preview = item_nutrition_preview(detected, include_alternatives=False)
    detected.nutrition_preview_snapshot = _json_safe(preview)
    detected.save(update_fields=["nutrition_preview_snapshot", "updated_at"])
    return preview


def meal_preview_for_analysis(analysis) -> dict:
    items = [
        item_nutrition_preview(detected)
        for detected in analysis.detected_foods.select_related(
            "matched_food",
            "matched_food__source",
            "photo_analysis",
            "photo_analysis__user",
        ).prefetch_related(
            "matched_food__servings",
            "matched_food__nutrients__nutrient",
            "matched_food__nutrients__source",
            "matched_food__aliases",
        )
    ]
    total = {code: Decimal("0") for code in SUMMARY_CODES}
    warnings = []
    for item in items:
        if item["is_removed"]:
            continue
        total["calories"] += Decimal(str(item["calories_kcal"]))
        total["protein_g"] += Decimal(str(item["protein_g"]))
        total["carbs_g"] += Decimal(str(item["carbs_g"]))
        total["fat_g"] += Decimal(str(item["fat_g"]))
        total["fiber_g"] += Decimal(str(item["fiber_g"]))
        total["sugar_g"] += Decimal(str(item["sugar_g"]))
        total["sodium_mg"] += Decimal(str(item["sodium_mg"]))
        warnings.extend(item["warnings"])
    return {
        "items": items,
        "total_preview": {
            "calories_kcal": quantize_decimal(total["calories"]),
            "protein_g": quantize_decimal(total["protein_g"]),
            "carbs_g": quantize_decimal(total["carbs_g"]),
            "fat_g": quantize_decimal(total["fat_g"]),
            "fiber_g": quantize_decimal(total["fiber_g"]),
            "sugar_g": quantize_decimal(total["sugar_g"]),
            "sodium_mg": quantize_decimal(total["sodium_mg"]),
        },
        "warnings": sorted(set(warnings)),
    }


def review_payload(analysis, request=None) -> dict:
    preview = meal_preview_for_analysis(analysis)
    return {
        "analysis_id": analysis.id,
        "status": analysis.status,
        "image_url": public_image_url(analysis.image, request),
        "disclaimer": (
            "Photo nutrition is an estimate. Confirm food and portion size for "
            "better accuracy."
        ),
        "items": preview["items"],
        "total_preview": preview["total_preview"],
        "warnings": preview["warnings"],
    }


def _json_safe(value):
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, dict):
        return {key: _json_safe(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_json_safe(item) for item in value]
    if hasattr(value, "hex") and hasattr(value, "version"):
        return str(value)
    return value
