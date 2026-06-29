from decimal import Decimal

from django.core.management.base import BaseCommand, CommandError

from foods.importers import (
    MICROGRAM_NUTRIENTS_FROM_GRAMS,
    MILLIGRAM_NUTRIENTS_FROM_GRAMS,
    OPENFOODFACTS_TO_NUTRIENT_CODE,
    ImportResult,
    create_import_job,
    fail_import_job,
    fetch_json,
    finish_import_job,
    get_data_source,
    get_env,
    normalize_barcode,
    normalize_decimal,
    seed_core_reference_data,
    upsert_food_nutrients,
    upsert_food_record,
    upsert_food_serving,
)
from foods.models import Food, FoodDataImportJob, FoodNutrient
from nutrition.models import NutritionDataSource


class Command(BaseCommand):
    help = "Sync a packaged product from Open Food Facts API v3 by barcode."

    def add_arguments(self, parser):
        parser.add_argument("--barcode", required=True)

    def handle(self, *args, **options):
        user_agent = get_env("OPENFOODFACTS_USER_AGENT")
        if not user_agent:
            raise CommandError("OPENFOODFACTS_USER_AGENT is required for OFF sync.")

        seed_core_reference_data()
        source = get_data_source(NutritionDataSource.SourceType.OPEN_FOOD_FACTS)
        barcode = normalize_barcode(options["barcode"])
        job = create_import_job(source, file_name=f"barcode:{barcode}")
        result = ImportResult(errors=[])

        try:
            payload = fetch_json(
                f"https://world.openfoodfacts.org/api/v3/product/{barcode}.json",
                headers={"User-Agent": user_agent},
            )
            product = payload.get("product")
            if not product:
                result.add_error("Product not found.", {"barcode": barcode})
                finish_import_job(
                    job,
                    result,
                    status=FoodDataImportJob.Status.PARTIAL,
                )
                self.stdout.write(
                    self.style.WARNING(f"No product found for {barcode}.")
                )
                return

            result.rows_processed = 1
            nutriments = product.get("nutriments") or {}
            nutrients = {}
            for off_key, code in OPENFOODFACTS_TO_NUTRIENT_CODE.items():
                amount = normalize_decimal(nutriments.get(off_key))
                if amount is None:
                    continue
                if code in MILLIGRAM_NUTRIENTS_FROM_GRAMS:
                    amount *= Decimal("1000")
                if code in MICROGRAM_NUTRIENTS_FROM_GRAMS:
                    amount *= Decimal("1000000")
                nutrients[code] = amount

            data_quality_score = Decimal("0.7500") if nutrients else Decimal("0.4500")
            product_name = (
                product.get("product_name")
                or product.get("generic_name")
                or f"Open Food Facts product {barcode}"
            )
            food, created = upsert_food_record(
                source=source,
                canonical_name=product_name,
                external_id=barcode,
                brand_name=product.get("brands") or "",
                description=product.get("generic_name") or "",
                food_type=Food.FoodType.BRANDED,
                country_code=(product.get("countries_tags") or [""])[0][-2:].upper()
                or "US",
                language_code=product.get("lang") or "en",
                barcode=barcode,
                serving_description=product.get("serving_size") or "",
                data_quality_score=data_quality_score,
                verified=False,
                ingredients_text=product.get("ingredients_text") or "",
                allergens=[
                    item.replace("en:", "")
                    for item in product.get("allergens_tags", [])
                    if item
                ],
                metadata={
                    "openfoodfacts_code": product.get("code") or barcode,
                    "ecoscore_grade": product.get("ecoscore_grade", ""),
                    "nutriscore_grade": product.get("nutriscore_grade", ""),
                },
            )
            result.rows_created += int(created)
            result.rows_updated += int(not created)

            serving_g = normalize_decimal(product.get("serving_quantity"))
            if serving_g:
                upsert_food_serving(
                    food,
                    serving_name=product.get("serving_size") or "Serving",
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
        except Exception as exc:  # noqa: BLE001 - command records failed job.
            fail_import_job(job, str(exc))
            raise

        finish_import_job(job, result)
        self.stdout.write(
            self.style.SUCCESS(
                "Synced Open Food Facts barcode: "
                f"{result.rows_created} created, {result.rows_updated} updated, "
                f"{len(result.errors or [])} errors."
            )
        )
