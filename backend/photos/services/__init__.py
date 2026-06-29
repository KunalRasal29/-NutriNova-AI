from __future__ import annotations

import re
from decimal import Decimal, InvalidOperation

from django.db import transaction
from rest_framework.exceptions import ValidationError

from foods.models import Food, FoodNutrient, FoodServing
from meals.models import MealLog, MealLogItem
from meals.services import recompute_daily_summary
from nutrition.calculations import calculate_food_snapshot, quantize_decimal
from nutrition.models import Nutrient, NutritionDataSource
from photos.models import NutritionLabelScan, PhotoAnalysis, PhotoDetectedFood
from photos.providers import PHOTO_DISCLAIMER, get_photo_analysis_provider
from photos.services.photo_nutrition_preview import (
    COUNTABLE_UNITS,
    effective_quantity,
    effective_total_grams,
    match_food_name_for_user,
    normalize_name,
    normalize_quantity_unit,
    review_payload,
    update_item_preview_snapshot,
    visible_foods_for_user,
)

CONFIDENCE_REVIEW_THRESHOLD = Decimal("0.7000")


def parse_decimal(value, default: Decimal | None = Decimal("0")) -> Decimal | None:
    if value in (None, ""):
        return default
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError):
        return default


def parse_portion_quantity(portion: str) -> tuple[Decimal, str]:
    if not portion:
        return Decimal("1"), PhotoDetectedFood.QuantityUnit.SERVING
    value = re.search(r"(\d+(?:\.\d+)?)", portion)
    quantity = Decimal(value.group(1)) if value else Decimal("1")
    lower = portion.lower()
    if "egg" in lower:
        return quantity, PhotoDetectedFood.QuantityUnit.EGG
    if "slice" in lower:
        return quantity, PhotoDetectedFood.QuantityUnit.SLICE
    if "bowl" in lower or "katori" in lower:
        return quantity, PhotoDetectedFood.QuantityUnit.BOWL
    if "cup" in lower:
        return quantity, PhotoDetectedFood.QuantityUnit.CUP
    if "glass" in lower:
        return quantity, PhotoDetectedFood.QuantityUnit.GLASS
    if "tbsp" in lower or "tablespoon" in lower:
        return quantity, PhotoDetectedFood.QuantityUnit.TABLESPOON
    if "tsp" in lower or "teaspoon" in lower:
        return quantity, PhotoDetectedFood.QuantityUnit.TEASPOON
    if "g" in lower and "mg" not in lower:
        return quantity, PhotoDetectedFood.QuantityUnit.GRAM
    if "ml" in lower:
        return quantity, PhotoDetectedFood.QuantityUnit.ML
    return quantity, PhotoDetectedFood.QuantityUnit.SERVING


def parse_serving_grams(serving_size: str) -> Decimal | None:
    match = re.search(r"(\d+(?:\.\d+)?)\s*g\b", serving_size.lower())
    if not match:
        return None
    return Decimal(match.group(1))


@transaction.atomic
def match_detected_foods(analysis: PhotoAnalysis):
    matched = []
    for detected in analysis.detected_foods.select_related("matched_food"):
        food, score = match_food_name_for_user(
            analysis.user,
            detected.normalized_name or detected.detected_name,
        )
        detected.matched_food = food
        detected.save(update_fields=["matched_food", "updated_at"])
        update_item_preview_snapshot(detected)
        matched.append((detected, score))
    return matched


def build_review_reasons(analysis: PhotoAnalysis) -> list[str]:
    reasons = []
    if analysis.confidence_score < CONFIDENCE_REVIEW_THRESHOLD:
        reasons.append("low_overall_confidence")
    for detected in analysis.detected_foods.all():
        if detected.is_removed:
            continue
        if detected.confidence_score < CONFIDENCE_REVIEW_THRESHOLD:
            reasons.append("low_detected_food_confidence")
        if (
            detected.portion_confidence is not None
            and detected.portion_confidence < CONFIDENCE_REVIEW_THRESHOLD
        ):
            reasons.append("low_portion_confidence")
        if not detected.matched_food_id:
            reasons.append("food_match_required")
        if effective_total_grams(detected) is None:
            reasons.append("grams_required")
    return sorted(set(reasons))


@transaction.atomic
def analyze_photo_analysis(analysis_id):
    analysis = PhotoAnalysis.objects.select_related("user").get(id=analysis_id)
    provider = get_photo_analysis_provider()
    analysis.status = PhotoAnalysis.Status.PROCESSING
    analysis.ai_provider = provider.provider_name
    analysis.error_message = ""
    analysis.save(
        update_fields=[
            "status",
            "ai_provider",
            "error_message",
            "updated_at",
        ]
    )

    try:
        if analysis.analysis_type == PhotoAnalysis.AnalysisType.NUTRITION_LABEL:
            response = provider.analyze_nutrition_label(analysis)
            _store_label_response(analysis, response)
        else:
            response = provider.analyze_meal_photo(analysis)
            _store_meal_response(analysis, response)
        analysis.save(update_fields=["confidence_score", "updated_at"])
        analysis.refresh_from_db()
        review_reasons = build_review_reasons(analysis)
        response["review_reasons"] = review_reasons
        response["requires_manual_review"] = bool(review_reasons)
        analysis.raw_ai_response = response
        analysis.status = PhotoAnalysis.Status.NEEDS_REVIEW
        analysis.save(
            update_fields=[
                "raw_ai_response",
                "status",
                "confidence_score",
                "updated_at",
            ]
        )
    except Exception as exc:
        analysis.status = PhotoAnalysis.Status.FAILED
        analysis.error_message = str(exc)
        analysis.save(update_fields=["status", "error_message", "updated_at"])
        raise
    return analysis


def _store_meal_response(analysis: PhotoAnalysis, response: dict) -> None:
    PhotoDetectedFood.objects.filter(photo_analysis=analysis).delete()
    analysis.confidence_score = quantize_decimal(
        parse_decimal(response.get("confidence")),
        "0.0001",
    )
    for item in response.get("detected_foods", []):
        portion_quantity, portion_unit = parse_portion_quantity(
            item.get("estimated_portion", "")
        )
        quantity_value = parse_decimal(item.get("quantity_value"), None)
        quantity_unit = normalize_quantity_unit(item.get("quantity_unit"))
        if quantity_value is None:
            quantity_value = portion_quantity
        if not quantity_unit:
            quantity_unit = portion_unit
        total_grams = parse_decimal(item.get("total_grams_estimate"), None)
        if total_grams is None:
            total_grams = parse_decimal(item.get("estimated_grams"), None)
        detected = PhotoDetectedFood.objects.create(
            photo_analysis=analysis,
            detected_name=item.get("name", "").strip() or "Unknown food",
            normalized_name=normalize_name(
                item.get("normalized_name") or item.get("name", "")
            ),
            quantity_estimate=quantity_value or Decimal("1"),
            unit_estimate=quantity_unit or PhotoDetectedFood.QuantityUnit.SERVING,
            quantity_value=quantity_value,
            quantity_unit=quantity_unit,
            grams_estimate=total_grams,
            grams_per_unit_estimate=parse_decimal(
                item.get("grams_per_unit_estimate"),
                None,
            ),
            total_grams_estimate=total_grams,
            min_total_grams_estimate=parse_decimal(
                item.get("min_total_grams_estimate"),
                None,
            ),
            max_total_grams_estimate=parse_decimal(
                item.get("max_total_grams_estimate"),
                None,
            ),
            confidence_score=quantize_decimal(
                parse_decimal(item.get("confidence")),
                "0.0001",
            ),
            count_confidence=parse_decimal(item.get("count_confidence"), None),
            portion_confidence=parse_decimal(item.get("portion_confidence"), None),
            bounding_box=item.get("bounding_box") or {},
            reasoning_short=item.get("reasoning_short", ""),
        )
        matched_food, _score = match_food_name_for_user(
            analysis.user,
            detected.normalized_name or detected.detected_name,
        )
        if matched_food:
            detected.matched_food = matched_food
            detected.save(update_fields=["matched_food", "updated_at"])
        update_item_preview_snapshot(detected)


def _store_label_response(analysis: PhotoAnalysis, response: dict) -> None:
    confidence = quantize_decimal(parse_decimal(response.get("confidence")), "0.0001")
    analysis.confidence_score = confidence
    NutritionLabelScan.objects.update_or_create(
        photo_analysis=analysis,
        defaults={
            "product_name": response.get("product_name", ""),
            "brand": response.get("brand", ""),
            "serving_size": response.get("serving_size", ""),
            "barcode": response.get("barcode", ""),
            "parsed_nutrients": response.get("parsed_nutrients", {}),
            "ingredients_text": response.get("ingredients_text", ""),
            "allergens": response.get("allergens", []),
            "confidence_score": confidence,
        },
    )


@transaction.atomic
def update_detected_food(detected: PhotoDetectedFood, validated_data: dict):
    updated_fields = set(validated_data)
    if "matched_food" in validated_data:
        matched_food = validated_data.pop("matched_food")
        detected.matched_food = matched_food
    for field, value in validated_data.items():
        setattr(detected, field, value)
    if {
        "user_quantity_value",
        "user_quantity_unit",
        "user_total_grams",
        "user_corrected_grams",
        "matched_food",
    } & updated_fields:
        detected.is_user_corrected = True
    if detected.user_total_grams is not None:
        detected.user_corrected_grams = detected.user_total_grams
    detected.save()
    return update_item_preview_snapshot(detected)


@transaction.atomic
def increment_detected_food(detected: PhotoDetectedFood):
    quantity, unit = effective_quantity(detected)
    unit = unit or PhotoDetectedFood.QuantityUnit.SERVING
    if unit not in COUNTABLE_UNITS:
        raise ValidationError({"quantity_unit": "This unit cannot be incremented."})
    quantity = quantity or Decimal("0")
    detected.user_quantity_value = quantity + Decimal("1")
    detected.user_quantity_unit = unit
    detected.user_total_grams = None
    detected.user_corrected_grams = None
    detected.is_user_corrected = True
    detected.is_removed = False
    detected.user_confirmed = True
    detected.save()
    return update_item_preview_snapshot(detected)


@transaction.atomic
def decrement_detected_food(detected: PhotoDetectedFood):
    quantity, unit = effective_quantity(detected)
    unit = unit or PhotoDetectedFood.QuantityUnit.SERVING
    if unit not in COUNTABLE_UNITS:
        raise ValidationError({"quantity_unit": "This unit cannot be decremented."})
    quantity = max((quantity or Decimal("0")) - Decimal("1"), Decimal("0"))
    detected.user_quantity_value = quantity
    detected.user_quantity_unit = unit
    detected.user_total_grams = None
    detected.user_corrected_grams = None
    detected.is_user_corrected = True
    detected.is_removed = quantity == 0
    detected.user_confirmed = quantity > 0
    detected.save()
    return update_item_preview_snapshot(detected)


@transaction.atomic
def add_manual_food_to_analysis(analysis: PhotoAnalysis, validated_data: dict):
    food = validated_data["food"]
    quantity_value = validated_data.get("quantity_value")
    quantity_unit = validated_data.get("quantity_unit")
    total_grams = validated_data.get("total_grams")
    detected = PhotoDetectedFood.objects.create(
        photo_analysis=analysis,
        detected_name=food.canonical_name,
        normalized_name=normalize_name(food.canonical_name),
        matched_food=food,
        quantity_estimate=quantity_value or Decimal("1"),
        unit_estimate=quantity_unit or PhotoDetectedFood.QuantityUnit.SERVING,
        quantity_value=quantity_value,
        quantity_unit=quantity_unit,
        total_grams_estimate=total_grams,
        user_quantity_value=quantity_value,
        user_quantity_unit=quantity_unit,
        user_total_grams=total_grams,
        user_corrected_grams=total_grams,
        confidence_score=Decimal("1.0000"),
        count_confidence=Decimal("1.0000"),
        portion_confidence=Decimal("1.0000"),
        user_confirmed=True,
        is_user_corrected=True,
        added_manually=True,
    )
    return update_item_preview_snapshot(detected)


@transaction.atomic
def recalculate_analysis_preview(analysis: PhotoAnalysis):
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
    ):
        update_item_preview_snapshot(detected)
    return review_payload(analysis)


@transaction.atomic
def confirm_analysis_as_meal(analysis: PhotoAnalysis, validated_data: dict) -> MealLog:
    if analysis.analysis_type != PhotoAnalysis.AnalysisType.MEAL_PHOTO:
        raise ValidationError("Only meal photo analyses can be confirmed as meals.")
    if analysis.status not in {
        PhotoAnalysis.Status.NEEDS_REVIEW,
        PhotoAnalysis.Status.CONFIRMED,
    }:
        raise ValidationError("Analysis is not ready for confirmation.")

    item_payloads = validated_data.get("items", [])
    if item_payloads:
        _apply_detection_corrections(analysis, item_payloads)

    confirmed_items = list(
        analysis.detected_foods.filter(is_removed=False)
        .select_related(
            "matched_food",
            "photo_analysis",
            "photo_analysis__user",
        )
        .prefetch_related(
            "matched_food__servings",
            "matched_food__nutrients__nutrient",
            "matched_food__nutrients__source",
            "matched_food__aliases",
        )
    )
    if not confirmed_items:
        raise ValidationError({"items": "Confirm at least one detected food."})

    meal_log = MealLog.objects.create(
        user=analysis.user,
        date=validated_data["date"],
        meal_type=validated_data["meal_type"],
        name=validated_data.get("name") or "Photo meal",
        notes=validated_data.get("notes", ""),
        timezone=validated_data.get("timezone")
        or getattr(analysis.user, "timezone", "UTC"),
    )
    for detected in confirmed_items:
        food = detected.matched_food
        if not food:
            raise ValidationError(
                {"items": f"Choose a food match for {detected.detected_name}."}
            )
        grams = effective_total_grams(detected)
        if not grams or grams <= 0:
            raise ValidationError(
                {"items": f"Enter grams for {detected.detected_name}."}
            )
        quantity, unit = effective_quantity(detected)
        snapshot = calculate_food_snapshot(food, grams)
        MealLogItem.objects.create(
            user=analysis.user,
            meal_log=meal_log,
            food=food,
            quantity=quantity or grams,
            unit=MealLogItem.Unit.GRAMS,
            grams_calculated=grams,
            calories_kcal=snapshot["calories_kcal"],
            macros_snapshot=snapshot["macros_snapshot"],
            nutrients_snapshot=snapshot["nutrients_snapshot"],
            source_confidence=min(
                snapshot["source_confidence"],
                detected.confidence_score,
            ),
            user_confirmed=True,
        )
        detected.user_confirmed = True
        detected.save(update_fields=["user_confirmed", "updated_at"])

    analysis.status = PhotoAnalysis.Status.CONFIRMED
    analysis.save(update_fields=["status", "updated_at"])
    recompute_daily_summary(analysis.user, meal_log.date)
    return meal_log


def _apply_detection_corrections(analysis: PhotoAnalysis, item_payloads: list[dict]):
    detections = {
        str(detected.id): detected for detected in analysis.detected_foods.all()
    }
    for payload in item_payloads:
        detected = detections.get(str(payload["detected_food"]))
        if not detected:
            raise ValidationError(
                {"items": "Detected food does not belong to analysis."}
            )
        updates = {
            "user_confirmed": payload.get("user_confirmed", True),
        }
        if payload.get("matched_food"):
            try:
                updates["matched_food"] = visible_foods_for_user(analysis.user).get(
                    id=payload["matched_food"]
                )
            except Food.DoesNotExist as exc:
                raise ValidationError(
                    {"items": "Food does not belong to this user."}
                ) from exc
        for field in (
            "user_corrected_name",
            "user_corrected_grams",
            "user_quantity_value",
            "user_quantity_unit",
            "user_total_grams",
            "is_removed",
            "correction_note",
        ):
            if field in payload:
                updates[field] = payload[field]
        update_detected_food(detected, updates)


def get_or_create_label_source(label_scan: NutritionLabelScan):
    if label_scan.barcode:
        source_type = NutritionDataSource.SourceType.OPEN_FOOD_FACTS
        defaults = {
            "name": "Open Food Facts",
            "license_name": "Open Database License",
            "license_url": "https://opendatacommons.org/licenses/odbl/1-0/",
            "citation": "Open Food Facts contributors. Open Food Facts database.",
            "update_frequency": "Community updated continuously",
            "reliability_score": Decimal("0.7500"),
            "is_active": True,
        }
    else:
        source_type = NutritionDataSource.SourceType.USER_CUSTOM
        defaults = {
            "name": "User Custom",
            "license_name": "User provided",
            "citation": "User-entered foods created inside NutriNova AI.",
            "update_frequency": "User managed",
            "reliability_score": Decimal("0.5000"),
            "is_active": True,
        }
    source, _ = NutritionDataSource.objects.get_or_create(
        source_type=source_type,
        defaults=defaults,
    )
    return source


@transaction.atomic
def confirm_label_as_food(analysis: PhotoAnalysis) -> Food:
    if analysis.analysis_type != PhotoAnalysis.AnalysisType.NUTRITION_LABEL:
        raise ValidationError("Only nutrition label analyses can create label foods.")
    label_scan = analysis.nutrition_label_scan
    source = get_or_create_label_source(label_scan)
    serving_g = parse_serving_grams(label_scan.serving_size)
    food_defaults = {
        "canonical_name": label_scan.product_name or "Scanned product",
        "brand_name": label_scan.brand,
        "description": "Created from a user-confirmed nutrition label scan.",
        "ingredients_text": label_scan.ingredients_text,
        "allergens": label_scan.allergens,
        "food_type": (
            Food.FoodType.BRANDED if label_scan.barcode else Food.FoodType.USER_CUSTOM
        ),
        "country_code": "IN",
        "language_code": "en",
        "barcode": label_scan.barcode,
        "serving_description": label_scan.serving_size,
        "default_serving_g": serving_g,
        "data_quality_score": label_scan.confidence_score,
        "verified": False,
        "created_by": analysis.user,
    }
    lookup = {
        "source": source,
        "external_id": (
            f"label:{label_scan.barcode}"
            if label_scan.barcode
            else f"label-scan:{analysis.id}"
        ),
    }
    food, _ = Food.objects.update_or_create(**lookup, defaults=food_defaults)
    if serving_g:
        FoodServing.objects.update_or_create(
            food=food,
            serving_name=label_scan.serving_size or "Label serving",
            defaults={
                "grams": serving_g,
                "is_default": True,
            },
        )

    nutrient_map = Nutrient.objects.in_bulk(
        label_scan.parsed_nutrients.keys(),
        field_name="code",
    )
    for code, value in label_scan.parsed_nutrients.items():
        nutrient = nutrient_map.get(code)
        if not nutrient:
            continue
        amount = parse_decimal(value)
        amount_per_100g = amount
        if serving_g and serving_g > 0:
            amount_per_100g = amount / serving_g * Decimal("100")
        FoodNutrient.objects.update_or_create(
            food=food,
            nutrient=nutrient,
            source=source,
            derivation_method=FoodNutrient.DerivationMethod.LABEL,
            defaults={
                "amount_per_100g": quantize_decimal(amount_per_100g, "0.0001"),
                "confidence_score": label_scan.confidence_score,
            },
        )

    analysis.status = PhotoAnalysis.Status.CONFIRMED
    analysis.save(update_fields=["status", "updated_at"])
    return food


def response_disclaimer() -> dict[str, str]:
    return {"disclaimer": PHOTO_DISCLAIMER}
