from __future__ import annotations

from decimal import Decimal
from difflib import SequenceMatcher

from django.contrib.postgres.search import TrigramSimilarity
from django.db.models import Q
from rest_framework.exceptions import ValidationError

from foods.models import Food
from foods.text import normalize_catalog_text
from nutrition.calculations import quantize_decimal, select_best_nutrient_values
from nutrition.models import NutritionDataSource

ESTIMATE_FIELDS = {
    "calories_kcal": "calories",
    "protein_g": "protein_g",
    "carbs_g": "carbs_g",
    "fat_g": "fat_g",
    "fiber_g": "fiber_g",
    "sugar_g": "sugar_g",
    "sodium_mg": "sodium_mg",
}
CORE_CODES = {"calories", "protein_g", "carbs_g", "fat_g"}
UNTRUSTED_ESTIMATE_SOURCES = {
    NutritionDataSource.SourceType.AI_ESTIMATE,
    NutritionDataSource.SourceType.USER_CUSTOM,
}


def decimal_string(value: Decimal, places: str = "0.001") -> str:
    return str(quantize_decimal(Decimal(str(value)), places))


def macro_calories(nutrients: dict) -> Decimal:
    protein = Decimal(str(nutrients.get("protein_g") or 0))
    carbs = Decimal(str(nutrients.get("carbs_g") or 0))
    fat = Decimal(str(nutrients.get("fat_g") or 0))
    return quantize_decimal((protein * 4) + (carbs * 4) + (fat * 9), "0.0001")


def calorie_consistency_warnings(nutrients: dict) -> list[str]:
    label_calories = Decimal(str(nutrients.get("calories_kcal") or 0))
    calculated = macro_calories(nutrients)
    difference = abs(label_calories - calculated)
    tolerance = max(Decimal("30"), label_calories * Decimal("0.20"))
    if label_calories > 0 and difference > tolerance:
        return [
            "Calories differ notably from the 4/4/9 macro calculation. "
            "This can be valid because of fibre, rounding, or label rules; review it."
        ]
    return []


def _trusted_catalog():
    return (
        Food.objects.filter(
            created_by__isnull=True,
            is_deprecated=False,
            source__is_active=True,
        )
        .exclude(source__source_type__in=UNTRUSTED_ESTIMATE_SOURCES)
        .select_related("source")
        .prefetch_related("aliases", "nutrients__nutrient", "nutrients__source")
    )


def _reference_nutrients(food: Food, serving_weight_g: Decimal) -> dict[str, Decimal]:
    selected = select_best_nutrient_values(food)
    scale = serving_weight_g / Decimal("100")
    return {
        output_field: quantize_decimal(selected[code].amount_per_100g * scale)
        for output_field, code in ESTIMATE_FIELDS.items()
        if code in selected
    }


def _name_score(query: str, food: Food) -> Decimal:
    names = [food.normalized_name]
    names.extend(alias.normalized_alias for alias in food.aliases.all())
    scores = []
    for candidate in names:
        if not candidate:
            continue
        if candidate == query:
            scores.append(Decimal("1"))
        elif query in candidate or candidate in query:
            scores.append(Decimal("0.82"))
        else:
            scores.append(
                Decimal(str(SequenceMatcher(None, query, candidate).ratio()))
            )
    return max(scores, default=Decimal("0"))


def _find_reference_foods(
    *,
    name: str,
    preparation_state: str,
    preferred_reference_food_id=None,
) -> list[tuple[Food, Decimal]]:
    query = normalize_catalog_text(name)
    catalog = _trusted_catalog()
    if preferred_reference_food_id:
        preferred = catalog.filter(id=preferred_reference_food_id).first()
        if preferred is None:
            raise ValidationError(
                {"reference_food_id": "Choose an available trusted catalog food."}
            )
        selected = [preferred]
    else:
        tokens = [token for token in query.split() if len(token) >= 3]
        direct_filter = Q(normalized_name__icontains=query) | Q(
            aliases__normalized_alias__icontains=query
        )
        for token in tokens:
            direct_filter |= Q(normalized_name__icontains=token)
            direct_filter |= Q(aliases__normalized_alias__icontains=token)
        selected = list(catalog.filter(direct_filter).distinct()[:40])
        if len(selected) < 5:
            fuzzy = list(
                catalog.annotate(
                    name_similarity=TrigramSimilarity("normalized_name", query)
                )
                .filter(name_similarity__gte=0.15)
                .order_by("-name_similarity")[:25]
            )
            known_ids = {food.id for food in selected}
            selected.extend(food for food in fuzzy if food.id not in known_ids)

    ranked = []
    for food in selected:
        name_score = _name_score(query, food)
        if name_score < Decimal("0.32") and not preferred_reference_food_id:
            continue
        selected_nutrients = select_best_nutrient_values(food)
        if not CORE_CODES.issubset(selected_nutrients):
            continue
        prep_bonus = (
            Decimal("0.12")
            if preparation_state
            and food.preparation_state == preparation_state
            else Decimal("0")
        )
        quality_bonus = Decimal(food.data_quality_score) * Decimal("0.08")
        ranked.append((food, name_score + prep_bonus + quality_bonus, name_score))
    ranked.sort(key=lambda item: (item[1], item[0].verified), reverse=True)
    return [(food, name_score) for food, _, name_score in ranked[:5]]


def _reference_payload(
    food: Food,
    name_score: Decimal,
    serving_weight_g: Decimal,
) -> dict:
    nutrients = _reference_nutrients(food, serving_weight_g)
    return {
        "food_id": str(food.id),
        "name": food.canonical_name,
        "brand": food.brand_name,
        "preparation_state": food.preparation_state,
        "source": {
            "name": food.source.name,
            "source_type": food.source.source_type,
            "reliability_score": decimal_string(
                food.source.reliability_score, "0.0001"
            ),
        },
        "source_badge": food.source.source_type,
        "name_match_score": decimal_string(name_score, "0.0001"),
        "data_quality_score": decimal_string(food.data_quality_score, "0.0001"),
        "nutrients_for_entered_serving": {
            field: decimal_string(value) for field, value in nutrients.items()
        },
    }


def _combine_reference_estimates(
    references: list[tuple[Food, Decimal]],
    serving_weight_g: Decimal,
) -> tuple[dict, dict]:
    weighted_values: dict[str, list[tuple[Decimal, Decimal]]] = {
        field: [] for field in ESTIMATE_FIELDS
    }
    for food, name_score in references:
        weight = max(Decimal("0.10"), name_score) * max(
            Decimal("0.25"), Decimal(food.data_quality_score)
        )
        for field, value in _reference_nutrients(food, serving_weight_g).items():
            weighted_values[field].append((value, weight))

    likely = {}
    ranges = {}
    for field, values in weighted_values.items():
        if not values:
            continue
        total_weight = sum((weight for _, weight in values), Decimal("0"))
        likely_value = sum(
            (value * weight for value, weight in values), Decimal("0")
        ) / total_weight
        raw_values = [value for value, _ in values]
        likely[field] = decimal_string(likely_value)
        ranges[field] = {
            "min": decimal_string(min(raw_values)),
            "likely": decimal_string(likely_value),
            "max": decimal_string(max(raw_values)),
        }
    return likely, ranges


def _reference_confidence(
    references: list[tuple[Food, Decimal]],
    preparation_state: str,
    likely: dict,
    ranges: dict,
) -> Decimal:
    best_name_score = references[0][1]
    average_quality = sum(
        (Decimal(food.data_quality_score) for food, _ in references), Decimal("0")
    ) / Decimal(len(references))
    prep_match = Decimal(
        "1"
        if preparation_state
        and any(food.preparation_state == preparation_state for food, _ in references)
        else "0.5"
    )
    calories = Decimal(str(likely.get("calories_kcal") or 0))
    calorie_range = ranges.get("calories_kcal", {})
    spread = Decimal(str(calorie_range.get("max") or 0)) - Decimal(
        str(calorie_range.get("min") or 0)
    )
    agreement = max(
        Decimal("0"),
        Decimal("1") - (spread / max(calories, Decimal("1"))),
    )
    confidence = (
        best_name_score * Decimal("0.45")
        + average_quality * Decimal("0.30")
        + prep_match * Decimal("0.15")
        + agreement * Decimal("0.10")
    )
    return quantize_decimal(min(confidence, Decimal("0.95")), "0.0001")


def _ingredient_grams(food: Food, ingredient: dict) -> Decimal:
    explicit = ingredient.get("grams") or ingredient.get("total_grams")
    if explicit not in (None, ""):
        grams = Decimal(str(explicit))
        if grams <= 0:
            raise ValidationError({"ingredients": "Ingredient grams must be positive."})
        return grams
    quantity = Decimal(str(ingredient.get("quantity") or 1))
    unit = str(ingredient.get("unit") or "serving").lower()
    if quantity <= 0:
        raise ValidationError({"ingredients": "Ingredient quantity must be positive."})
    if unit in {"g", "gram", "grams", "ml"}:
        return quantity
    servings = list(food.servings.all())
    serving = next(
        (
            item
            for item in servings
            if unit in item.serving_name.lower()
            or unit in item.household_quantity.lower()
        ),
        None,
    )
    serving = serving or next((item for item in servings if item.is_default), None)
    grams_per_unit = serving.grams if serving else food.default_serving_g
    if not grams_per_unit:
        raise ValidationError(
            {"ingredients": f"Enter grams for ingredient '{food.canonical_name}'."}
        )
    return quantity * grams_per_unit


def _estimate_from_ingredients(user, data: dict) -> dict:
    ingredients = data["ingredients"]
    food_ids = [item["food_id"] for item in ingredients]
    visible = Food.objects.filter(
        Q(created_by__isnull=True) | Q(created_by=user),
        id__in=food_ids,
        is_deprecated=False,
    ).filter(
        ~Q(food_type=Food.FoodType.USER_CUSTOM)
        | Q(custom_profile__status="confirmed")
        | Q(custom_profile__isnull=True)
    ).select_related("source").prefetch_related(
        "servings", "nutrients__nutrient", "nutrients__source"
    )
    food_map = {str(food.id): food for food in visible}
    if len(food_map) != len(set(map(str, food_ids))):
        raise ValidationError(
            {"ingredients": "One or more ingredient foods are unavailable."}
        )

    totals = {field: Decimal("0") for field in ESTIMATE_FIELDS}
    ingredient_refs = []
    total_recipe_grams = Decimal("0")
    confidences = []
    for item in ingredients:
        food = food_map[str(item["food_id"])]
        selected_nutrients = select_best_nutrient_values(food)
        if not CORE_CODES.issubset(selected_nutrients):
            raise ValidationError(
                {
                    "ingredients": (
                        f"'{food.canonical_name}' is missing calories or core macros."
                    )
                }
            )
        grams = _ingredient_grams(food, item)
        total_recipe_grams += grams
        values = _reference_nutrients(food, grams)
        for field, value in values.items():
            totals[field] += value
        confidences.append(Decimal(food.data_quality_score))
        ingredient_refs.append(
            {
                "food_id": str(food.id),
                "name": food.canonical_name,
                "grams": decimal_string(grams),
                "source": food.source.name,
                "source_badge": food.source.source_type,
            }
        )
    if total_recipe_grams <= 0:
        raise ValidationError({"ingredients": "Recipe weight must be positive."})

    entered_weight_value = (
        data.get("serving_weight_g")
        or data.get("serving_grams")
        or total_recipe_grams
    )
    entered_weight = Decimal(str(entered_weight_value))
    scale = entered_weight / total_recipe_grams
    likely = {field: decimal_string(value * scale) for field, value in totals.items()}
    ranges = {
        field: {"min": value, "likely": value, "max": value}
        for field, value in likely.items()
    }
    confidence = quantize_decimal(
        sum(confidences, Decimal("0")) / Decimal(len(confidences)), "0.0001"
    )
    warnings = [
        "Recipe estimate assumes the entered ingredient amounts and does not model "
        "cooking loss, oil absorption, or discarded portions."
    ]
    warnings.extend(calorie_consistency_warnings(likely))
    return _base_response(
        data=data,
        serving_weight_g=entered_weight,
        likely=likely,
        ranges=ranges,
        references=ingredient_refs,
        source_badges=sorted({item["source_badge"] for item in ingredient_refs}),
        confidence=confidence,
        warnings=warnings,
        method="ingredient_sum",
        can_estimate=True,
    )


def _base_response(
    *,
    data: dict,
    serving_weight_g: Decimal,
    likely: dict,
    ranges: dict,
    references: list,
    source_badges: list,
    confidence: Decimal,
    warnings: list[str],
    method: str,
    can_estimate: bool,
) -> dict:
    calculated = macro_calories(likely)
    label_calories = Decimal(str(likely.get("calories_kcal") or 0))
    return {
        "normalized_food_name": normalize_catalog_text(data["food_name"]),
        "entered_serving": {
            "name": data.get("serving_name") or "Serving",
            "quantity": decimal_string(
                Decimal(str(data.get("serving_quantity") or 1))
            ),
            "unit": data.get("serving_unit") or "serving",
            "weight_g": decimal_string(serving_weight_g),
        },
        "suggested_nutrients": likely,
        "estimated_range": ranges,
        "reference_matches": references,
        "source_badges": source_badges,
        "confidence": decimal_string(confidence, "0.0001"),
        "estimation_method": method,
        "calculated_calories_from_macros": decimal_string(calculated),
        "calorie_difference": decimal_string(abs(label_calories - calculated)),
        "warnings": warnings,
        "requires_review": True,
        "can_estimate": can_estimate,
        "message": (
            "Review and edit every value before confirming."
            if can_estimate
            else "Unable to estimate reliably. Enter nutrition manually."
        ),
        "accuracy_notice": (
            "This is a database-based estimate, not a laboratory measurement."
        ),
    }


def estimate_custom_food(user, data: dict) -> dict:
    if data.get("ingredients"):
        return _estimate_from_ingredients(user, data)

    serving_weight = data.get("serving_weight_g") or data.get("serving_grams")
    if serving_weight in (None, ""):
        raise ValidationError(
            {"serving_weight_g": "Serving weight is required for name estimation."}
        )
    serving_weight_g = Decimal(str(serving_weight))
    references = _find_reference_foods(
        name=data["food_name"],
        preparation_state=data.get("preparation_method")
        or data.get("preparation_state")
        or "",
        preferred_reference_food_id=data.get("reference_food_id"),
    )
    if not references:
        return _base_response(
            data=data,
            serving_weight_g=serving_weight_g,
            likely={},
            ranges={},
            references=[],
            source_badges=[],
            confidence=Decimal("0"),
            warnings=["No sufficiently similar trusted reference food was found."],
            method="database_matches",
            can_estimate=False,
        )

    likely, ranges = _combine_reference_estimates(references, serving_weight_g)
    preparation_state = (
        data.get("preparation_method") or data.get("preparation_state") or ""
    )
    confidence = _reference_confidence(
        references, preparation_state, likely, ranges
    )
    reference_payloads = [
        _reference_payload(food, name_score, serving_weight_g)
        for food, name_score in references
    ]
    warnings = calorie_consistency_warnings(likely)
    if confidence < Decimal("0.60"):
        warnings.append(
            "Reference match confidence is low. Choose a reference or enter values "
            "manually."
        )
    return _base_response(
        data=data,
        serving_weight_g=serving_weight_g,
        likely=likely,
        ranges=ranges,
        references=reference_payloads,
        source_badges=sorted(
            {payload["source_badge"] for payload in reference_payloads}
        ),
        confidence=confidence,
        warnings=warnings,
        method="database_matches",
        can_estimate=confidence >= Decimal("0.35"),
    )
