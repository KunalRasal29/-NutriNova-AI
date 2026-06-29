from __future__ import annotations

import re
from dataclasses import dataclass
from decimal import Decimal
from difflib import SequenceMatcher

from django.db import transaction
from rest_framework.exceptions import ValidationError

from foods.models import Food
from foods.services.custom_foods import visible_foods_for_user
from meals.models import MealLog
from meals.services.manual_add import (
    MANUAL_QUANTITY_UNITS,
    add_food_to_meal,
    manual_food_preview,
    normalize_manual_unit,
)
from nutrition.calculations import quantize_decimal

QUICK_ADD_CONFIDENCE_THRESHOLD = Decimal("0.7000")
COUNTABLE_FOOD_TERMS = {
    "banana": "banana",
    "bananas": "banana",
    "chapati": "chapati",
    "chapatis": "chapati",
    "roti": "roti",
    "rotis": "roti",
    "idli": "idli",
    "idlis": "idli",
    "dosa": "dosa",
    "dosas": "dosa",
    "apple": "apple",
    "apples": "apple",
}
UNIT_TERMS = {
    "egg": ("egg", "egg"),
    "eggs": ("egg", "egg"),
    "piece": ("piece", ""),
    "pieces": ("piece", ""),
    "slice": ("slice", ""),
    "slices": ("slice", ""),
    "bowl": ("bowl", ""),
    "bowls": ("bowl", ""),
    "cup": ("cup", ""),
    "cups": ("cup", ""),
    "glass": ("glass", ""),
    "glasses": ("glass", ""),
    "scoop": ("scoop", ""),
    "scoops": ("scoop", ""),
    "packet": ("packet", ""),
    "packets": ("packet", ""),
    "serving": ("serving", ""),
    "servings": ("serving", ""),
    "tbsp": ("tablespoon", ""),
    "tablespoon": ("tablespoon", ""),
    "tablespoons": ("tablespoon", ""),
    "tsp": ("teaspoon", ""),
    "teaspoon": ("teaspoon", ""),
    "teaspoons": ("teaspoon", ""),
}
ALIAS_HINTS = {
    "boiled egg": ["egg", "whole egg"],
    "egg": ["boiled egg", "whole egg"],
    "roti": ["chapati", "phulka"],
    "chapati": ["roti", "phulka"],
    "curd": ["yogurt", "yoghurt"],
    "yogurt": ["curd", "yoghurt"],
    "dal": ["lentil soup", "lentils"],
}


@dataclass(frozen=True)
class ParsedQuickText:
    food_query: str
    quantity_value: Decimal
    quantity_unit: str
    raw_text: str
    parse_confidence: Decimal


def normalize_query(value: str) -> str:
    return " ".join((value or "").lower().replace(",", " ").split())


def split_quick_add_text(text: str) -> list[str]:
    parts = re.split(r"\s*,\s*|\s+\+\s+", text.strip())
    return [part.strip() for part in parts if part.strip()]


def parse_quick_text_item(text: str) -> ParsedQuickText:
    value = text.strip()
    attached_unit = re.match(
        r"^(?P<quantity>\d+(?:\.\d+)?)\s*(?P<unit>g|grams?|ml)\s+(?P<food>.+)$",
        value,
        flags=re.IGNORECASE,
    )
    if attached_unit:
        unit = normalize_manual_unit(attached_unit.group("unit"))
        return ParsedQuickText(
            food_query=normalize_query(attached_unit.group("food")),
            quantity_value=Decimal(attached_unit.group("quantity")),
            quantity_unit=unit,
            raw_text=text,
            parse_confidence=Decimal("0.9500"),
        )

    spaced = re.match(
        r"^(?P<quantity>\d+(?:\.\d+)?)\s+(?P<head>[^\s]+)(?:\s+(?P<tail>.+))?$",
        value,
        flags=re.IGNORECASE,
    )
    if spaced:
        quantity = Decimal(spaced.group("quantity"))
        head = normalize_query(spaced.group("head"))
        tail = normalize_query(spaced.group("tail") or "")
        if head in UNIT_TERMS:
            unit, default_food = UNIT_TERMS[head]
            food_query = tail or default_food or head
            return ParsedQuickText(
                food_query=food_query,
                quantity_value=quantity,
                quantity_unit=unit,
                raw_text=text,
                parse_confidence=Decimal("0.9000"),
            )
        if head in COUNTABLE_FOOD_TERMS:
            return ParsedQuickText(
                food_query=COUNTABLE_FOOD_TERMS[head],
                quantity_value=quantity,
                quantity_unit="piece",
                raw_text=text,
                parse_confidence=Decimal("0.8500"),
            )
        return ParsedQuickText(
            food_query=normalize_query(f"{head} {tail}".strip()),
            quantity_value=quantity,
            quantity_unit="serving",
            raw_text=text,
            parse_confidence=Decimal("0.6500"),
        )

    return ParsedQuickText(
        food_query=normalize_query(value),
        quantity_value=Decimal("1"),
        quantity_unit="serving",
        raw_text=text,
        parse_confidence=Decimal("0.5000"),
    )


def search_aliases(query: str) -> set[str]:
    normalized = normalize_query(query)
    aliases = {normalized}
    for key, values in ALIAS_HINTS.items():
        if key in normalized or normalized in key:
            aliases.update(values)
    return {alias for alias in aliases if alias}


def food_match_score(food: Food, query: str) -> Decimal:
    candidates = [
        food.canonical_name,
        food.brand_name,
        *(alias.alias for alias in food.aliases.all()),
    ]
    best = Decimal("0")
    for alias in search_aliases(query):
        for candidate in candidates:
            candidate_value = normalize_query(candidate)
            if not candidate_value:
                continue
            if candidate_value == alias:
                return Decimal("1.0000")
            if alias in candidate_value or candidate_value in alias:
                best = max(best, Decimal("0.9000"))
            best = max(
                best,
                Decimal(str(SequenceMatcher(None, alias, candidate_value).ratio())),
            )
    return quantize_decimal(best, "0.0001")


def top_food_matches(user, query: str, *, limit: int = 5) -> list[dict]:
    scored = []
    foods = visible_foods_for_user(user).prefetch_related(
        "aliases",
        "servings",
        "nutrients__nutrient",
        "nutrients__source",
    )[:500]
    for food in foods:
        score = food_match_score(food, query)
        if score >= Decimal("0.2500"):
            scored.append((score, food))
    scored.sort(key=lambda item: item[0], reverse=True)
    return [
        {
            "id": food.id,
            "name": food.canonical_name,
            "brand": food.brand_name,
            "score": score,
            "source_badge": food.source.source_type,
            "verified": food.verified,
        }
        for score, food in scored[:limit]
    ]


def build_quick_add_item(user, parsed: ParsedQuickText) -> dict:
    warnings = []
    alternatives = top_food_matches(user, parsed.food_query)
    matched = alternatives[0] if alternatives else None
    match_score = Decimal(str(matched["score"])) if matched else Decimal("0")
    food = None
    preview = {}
    if matched and match_score >= QUICK_ADD_CONFIDENCE_THRESHOLD:
        food = visible_foods_for_user(user).get(id=matched["id"])
    else:
        warnings.append("food match needs review")

    if food:
        try:
            preview = manual_food_preview(
                food=food,
                quantity_value=parsed.quantity_value,
                quantity_unit=parsed.quantity_unit,
            )
            warnings.extend(preview["warnings"])
        except ValidationError as exc:
            warnings.append("portion grams need review")
            preview = {"error": exc.detail}

    confidence = quantize_decimal(
        min(parsed.parse_confidence, match_score or Decimal("0")),
        "0.0001",
    )
    if warnings:
        confidence = min(confidence, Decimal("0.6900"))

    return {
        "raw_text": parsed.raw_text,
        "food_query": parsed.food_query,
        "food_id": food.id if food else None,
        "food_name": food.canonical_name if food else "",
        "quantity_value": parsed.quantity_value,
        "quantity_unit": parsed.quantity_unit,
        "effective_total_grams": preview.get("effective_total_grams"),
        "nutrition_preview": preview,
        "confidence": confidence,
        "requires_review": bool(warnings),
        "warnings": sorted(set(warnings)),
        "alternative_matches": alternatives,
    }


def total_preview(items: list[dict]) -> dict:
    totals = {
        "calories_kcal": Decimal("0"),
        "protein_g": Decimal("0"),
        "carbs_g": Decimal("0"),
        "fat_g": Decimal("0"),
    }
    for item in items:
        preview = item.get("nutrition_preview") or {}
        for key in totals:
            value = preview.get(key)
            if value is not None:
                totals[key] += Decimal(str(value))
    return {key: quantize_decimal(value) for key, value in totals.items()}


def parse_quick_add_text(user, text: str) -> dict:
    if not text or not text.strip():
        raise ValidationError({"text": "Enter a food description."})
    parsed_items = [
        build_quick_add_item(user, parse_quick_text_item(part))
        for part in split_quick_add_text(text)
    ]
    requires_review = any(item["requires_review"] for item in parsed_items)
    confidence = min(
        (Decimal(str(item["confidence"])) for item in parsed_items),
        default=Decimal("0"),
    )
    return {
        "text": text,
        "parsed_items": parsed_items,
        "confidence": quantize_decimal(confidence, "0.0001"),
        "preview": total_preview(parsed_items),
        "requires_review": requires_review,
    }


def item_payload_from_parsed(user, parsed_item: dict, *, date, meal_type) -> dict:
    food = parsed_item.get("food")
    food_id = parsed_item.get("food_id")
    if not food and not food_id:
        raise ValidationError({"items": "Choose a food before confirming."})
    if not food:
        try:
            food = visible_foods_for_user(user).get(id=food_id)
        except Food.DoesNotExist as exc:
            raise ValidationError(
                {"items": "Food is not available to this user."}
            ) from exc
    quantity_unit = normalize_manual_unit(parsed_item.get("quantity_unit"))
    if quantity_unit not in MANUAL_QUANTITY_UNITS:
        quantity_unit = "custom"
    return {
        "date": date,
        "meal_type": meal_type,
        "food": food,
        "quantity_value": parsed_item["quantity_value"],
        "quantity_unit": quantity_unit,
        "total_grams": parsed_item.get("total_grams")
        or parsed_item.get("effective_total_grams"),
    }


@transaction.atomic
def confirm_quick_add_text(user, validated_data: dict) -> dict:
    date = validated_data["date"]
    meal_type = validated_data["meal_type"]
    if validated_data.get("items"):
        parsed_items = validated_data["items"]
    else:
        parsed = parse_quick_add_text(user, validated_data["text"])
        if parsed["requires_review"]:
            raise ValidationError(
                {
                    "requires_review": True,
                    "parsed_items": parsed["parsed_items"],
                }
            )
        parsed_items = parsed["parsed_items"]

    meal_log = None
    saved_items = []
    previews = []
    for parsed_item in parsed_items:
        payload = item_payload_from_parsed(
            user,
            parsed_item,
            date=date,
            meal_type=meal_type,
        )
        meal_log, item, preview = add_food_to_meal(user, payload)
        saved_items.append(item)
        previews.append(preview)

    return {
        "meal": meal_log or MealLog.objects.none(),
        "items": saved_items,
        "preview": total_preview(
            [{"nutrition_preview": preview} for preview in previews]
        ),
    }
