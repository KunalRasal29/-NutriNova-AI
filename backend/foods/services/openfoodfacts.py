from __future__ import annotations

import time
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from urllib.error import HTTPError, URLError

from django.core.cache import cache
from django.utils import timezone
from django.utils.dateparse import parse_datetime

from foods.importers import (
    ImportResult,
    create_import_job,
    fail_import_job,
    fetch_json,
    finish_import_job,
    get_data_source,
    normalize_barcode,
    normalize_decimal,
    seed_core_reference_data,
    upsert_food_nutrients,
    upsert_food_record,
    upsert_food_serving,
)
from foods.models import Food, FoodDataImportJob, FoodNutrient
from foods.services.nutrient_normalization import (
    OPENFOODFACTS_NUTRIENT_CODE_BY_KEY,
    normalize_openfoodfacts_nutrient,
)
from nutrition.models import NutritionDataSource


def _text(value) -> str:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, list):
        return ", ".join(str(item).strip() for item in value if item)
    return ""


def _country_code(product: dict) -> str:
    tags = product.get("countries_tags") or []
    if isinstance(tags, str):
        tags = [tags]
    if tags:
        candidate = str(tags[0]).split(":")[-1].strip().upper()
        if len(candidate) == 2:
            return candidate
    return "US"


def _source_modified_at(product: dict):
    value = product.get("last_modified_t") or product.get("last_modified_datetime")
    if value in (None, ""):
        return timezone.now()
    try:
        return datetime.fromtimestamp(int(value), tz=UTC)
    except (TypeError, ValueError, OSError):
        return parse_datetime(str(value)) or timezone.now()


def sync_openfoodfacts_product(
    barcode: str,
    *,
    user_agent: str,
    force: bool = False,
) -> Food | None:
    """Fetch and duplicate-safely cache one OFF product plus an import job."""
    if not user_agent:
        raise ValueError("OPENFOODFACTS_USER_AGENT is required.")

    seed_core_reference_data()
    source = get_data_source(NutritionDataSource.SourceType.OPEN_FOOD_FACTS)
    normalized_barcode = normalize_barcode(barcode)
    any_existing = Food.objects.filter(barcode=normalized_barcode).first()
    if any_existing is not None and any_existing.source_id != source.id:
        return any_existing
    existing = any_existing
    if (
        existing
        and not force
        and existing.source_updated_at
        and existing.source_updated_at >= timezone.now() - timedelta(days=7)
    ):
        return existing
    job = create_import_job(source, file_name=f"barcode:{normalized_barcode}")
    result = ImportResult(errors=[])

    try:
        url = (
            f"https://world.openfoodfacts.org/api/v3/product/{normalized_barcode}.json"
        )
        cache_key = f"openfoodfacts:product:v3:{normalized_barcode}"
        payload = None if force else cache.get(cache_key)
        if payload is None:
            for attempt in range(3):
                try:
                    payload = fetch_json(
                        url,
                        headers={"User-Agent": user_agent},
                        timeout=12,
                    )
                    cache.set(cache_key, payload, timeout=60 * 60 * 24)
                    break
                except HTTPError as exc:
                    if exc.code != 429 and exc.code < 500:
                        raise
                    if attempt == 2:
                        raise
                except URLError:
                    if attempt == 2:
                        raise
                time.sleep(2**attempt)
        if payload is None:
            raise RuntimeError("Open Food Facts did not return a response.")
        product = payload.get("product") or {}
        if not product:
            result.add_error(
                "Product not found.",
                {"barcode": normalized_barcode},
            )
            finish_import_job(
                job,
                result,
                status=FoodDataImportJob.Status.PARTIAL,
            )
            return None

        result.rows_processed = 1
        nutriments = product.get("nutriments") or {}
        nutrients = {}
        for off_key in OPENFOODFACTS_NUTRIENT_CODE_BY_KEY:
            normalized = normalize_openfoodfacts_nutrient(
                key=off_key,
                amount=nutriments.get(off_key),
            )
            if normalized is not None:
                # Prefer explicit sodium over salt-derived sodium when both exist.
                if off_key == "salt_100g" and "sodium_mg" in nutrients:
                    continue
                nutrients[normalized.code] = normalized

        completeness_codes = {
            "calories",
            "protein_g",
            "carbs_g",
            "fat_g",
            "fiber_g",
            "sugar_g",
            "sodium_mg",
        }
        completeness = Decimal(len(set(nutrients) & completeness_codes)) / Decimal("7")
        data_quality_score = Decimal("0.4500") + completeness * Decimal("0.3000")
        product_name = (
            _text(product.get("product_name"))
            or _text(product.get("generic_name"))
            or f"Open Food Facts product {normalized_barcode}"
        )
        food, created = upsert_food_record(
            source=source,
            canonical_name=product_name,
            external_id=normalized_barcode,
            brand_name=_text(product.get("brands")),
            description=_text(product.get("generic_name")),
            food_type=Food.FoodType.BRANDED,
            preparation_state=Food.PreparationState.AS_SOLD,
            dataset_type=Food.DatasetType.OPEN_FOOD_FACTS,
            dataset_release="live-v3",
            source_updated_at=_source_modified_at(product),
            country_code=_country_code(product),
            language_code=_text(product.get("lang")) or "en",
            barcode=normalized_barcode,
            serving_description=_text(product.get("serving_size")),
            data_quality_score=data_quality_score,
            completeness_score=completeness.quantize(Decimal("0.0001")),
            verified=False,
            ingredients_text=_text(product.get("ingredients_text")),
            allergens=[
                str(item).replace("en:", "")
                for item in (product.get("allergens_tags") or [])
                if item
            ],
            metadata={
                "openfoodfacts_code": product.get("code") or normalized_barcode,
                "ecoscore_grade": product.get("ecoscore_grade", ""),
                "nutriscore_grade": product.get("nutriscore_grade", ""),
            },
        )
        result.rows_created += int(created)
        result.rows_updated += int(not created)

        serving_g = normalize_decimal(product.get("serving_quantity"))
        if serving_g and serving_g > 0:
            upsert_food_serving(
                food,
                serving_name=_text(product.get("serving_size")) or "Serving",
                grams=serving_g,
                is_default=True,
            )
        upsert_food_nutrients(
            food,
            source,
            nutrients,
            confidence_score=data_quality_score,
            derivation_method=FoodNutrient.DerivationMethod.LABEL,
        )
    except Exception as exc:
        fail_import_job(job, str(exc))
        raise

    finish_import_job(job, result)
    return food
