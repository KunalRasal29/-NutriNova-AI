from decimal import Decimal

from django.core.management.base import BaseCommand, CommandError

from foods.importers import (
    ImportResult,
    build_url,
    create_import_job,
    fail_import_job,
    fetch_json,
    finish_import_job,
    get_data_source,
    get_env,
    normalize_decimal,
    seed_core_reference_data,
    upsert_food_nutrients,
    upsert_food_record,
    upsert_food_serving,
)
from foods.models import Food, FoodNutrient
from foods.services.nutrient_normalization import normalize_usda_nutrient
from nutrition.models import NutritionDataSource


class Command(BaseCommand):
    help = "Search USDA FoodData Central API and import selected food details."

    def add_arguments(self, parser):
        parser.add_argument("--query", required=True, help="Food search query.")
        parser.add_argument("--limit", type=int, default=5)

    def handle(self, *args, **options):
        api_key = get_env("USDA_FDC_API_KEY")
        if not api_key:
            raise CommandError("USDA_FDC_API_KEY is required for API sync.")

        seed_core_reference_data()
        source = get_data_source(NutritionDataSource.SourceType.USDA_FDC)
        job = create_import_job(source, file_name=f"api:{options['query']}")
        result = ImportResult(errors=[])

        try:
            search_url = build_url(
                "https://api.nal.usda.gov/fdc/v1/foods/search",
                {
                    "api_key": api_key,
                    "query": options["query"],
                    "pageSize": max(1, min(options["limit"], 50)),
                },
            )
            search_payload = fetch_json(search_url)
            foods = search_payload.get("foods", [])[: options["limit"]]
            for search_food in foods:
                result.rows_processed += 1
                fdc_id = str(search_food.get("fdcId") or "")
                if not fdc_id:
                    continue
                detail_url = build_url(
                    f"https://api.nal.usda.gov/fdc/v1/food/{fdc_id}",
                    {"api_key": api_key},
                )
                try:
                    detail = fetch_json(detail_url)
                except Exception as exc:  # noqa: BLE001
                    result.add_error(str(exc), {"fdc_id": fdc_id})
                    continue

                food, created = upsert_food_record(
                    source=source,
                    canonical_name=detail.get("description")
                    or search_food.get("description")
                    or f"USDA food {fdc_id}",
                    external_id=fdc_id,
                    brand_name=detail.get("brandOwner") or "",
                    description=detail.get("dataType") or "",
                    food_type=(
                        Food.FoodType.BRANDED
                        if detail.get("brandOwner")
                        else Food.FoodType.GENERIC
                    ),
                    dataset_type={
                        "Foundation": Food.DatasetType.USDA_FOUNDATION,
                        "Survey (FNDDS)": Food.DatasetType.USDA_FNDDS,
                        "SR Legacy": Food.DatasetType.USDA_SR_LEGACY,
                        "Branded": Food.DatasetType.USDA_BRANDED,
                        "Experimental": Food.DatasetType.USDA_EXPERIMENTAL,
                    }.get(detail.get("dataType"), Food.DatasetType.UNKNOWN),
                    dataset_release=str(detail.get("publicationDate") or ""),
                    country_code="US",
                    barcode=detail.get("gtinUpc") or "",
                    serving_description=detail.get("servingSizeUnit") or "",
                    default_serving_g=normalize_decimal(detail.get("servingSize")),
                    data_quality_score=Decimal("0.9500"),
                    verified=True,
                    ingredients_text=detail.get("ingredients") or "",
                    metadata={"fdc_api": True},
                )
                result.rows_created += int(created)
                result.rows_updated += int(not created)

                if food.default_serving_g:
                    upsert_food_serving(
                        food,
                        serving_name=food.serving_description or "Serving",
                        grams=food.default_serving_g,
                        is_default=True,
                    )

                nutrients = {}
                for nutrient_row in detail.get("foodNutrients", []):
                    nutrient = nutrient_row.get("nutrient") or {}
                    normalized = normalize_usda_nutrient(
                        nutrient_id=str(nutrient.get("id") or "").strip(),
                        name=str(nutrient.get("name") or ""),
                        unit=str(nutrient.get("unitName") or ""),
                        amount=nutrient_row.get("amount"),
                    )
                    if normalized is not None:
                        nutrients[normalized.code] = normalized
                upsert_food_nutrients(
                    food,
                    source,
                    nutrients,
                    confidence_score=Decimal("0.9500"),
                    derivation_method=FoodNutrient.DerivationMethod.LAB,
                )
        except Exception as exc:  # noqa: BLE001 - command records failed job.
            fail_import_job(job, str(exc))
            raise

        finish_import_job(job, result)
        self.stdout.write(
            self.style.SUCCESS(
                "Synced USDA FDC API: "
                f"{result.rows_created} created, {result.rows_updated} updated, "
                f"{len(result.errors or [])} errors."
            )
        )
