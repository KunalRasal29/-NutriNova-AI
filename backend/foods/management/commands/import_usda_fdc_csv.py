from decimal import Decimal
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from foods.importers import (
    NUTRIENT_CODE_BY_FDC_ID,
    NUTRIENT_CODE_BY_NAME,
    ImportResult,
    calculate_checksum,
    create_import_job,
    csv_source_path,
    fail_import_job,
    find_csv,
    finish_import_job,
    get_data_source,
    normalize_decimal,
    seed_core_reference_data,
    stream_csv,
    upsert_food_record,
    upsert_food_serving,
)
from foods.models import Food, FoodNutrient
from nutrition.models import Nutrient, NutritionDataSource


class Command(BaseCommand):
    help = (
        "Import official USDA FoodData Central CSV downloads from a zip or folder. "
        "This command streams CSV rows and records FoodDataImportJob status."
    )

    def add_arguments(self, parser):
        parser.add_argument("--path", required=True, help="Path to FDC zip or folder.")
        parser.add_argument(
            "--limit",
            type=int,
            default=0,
            help="Optional row limit for development smoke tests.",
        )
        parser.add_argument(
            "--batch-size",
            type=int,
            default=1000,
            help="Batch size for bulk nutrient upserts.",
        )

    def handle(self, *args, **options):
        seed_core_reference_data()
        path = Path(options["path"])
        if not path.exists():
            raise CommandError(f"Path not found: {path}")

        source = get_data_source(NutritionDataSource.SourceType.USDA_FDC)
        checksum = calculate_checksum(path) if path.is_file() else ""
        job = create_import_job(source, file_name=str(path), checksum=checksum)
        result = ImportResult(errors=[])
        nutrient_batch = []
        batch_size = max(options["batch_size"], 1)
        nutrient_map = Nutrient.objects.in_bulk(field_name="code")

        def flush_nutrient_batch():
            if not nutrient_batch:
                return
            FoodNutrient.objects.bulk_create(
                nutrient_batch,
                batch_size=batch_size,
                update_conflicts=True,
                update_fields=("amount_per_100g", "confidence_score"),
                unique_fields=("food", "nutrient", "source", "derivation_method"),
            )
            nutrient_batch.clear()

        try:
            with csv_source_path(path) as root:
                food_csv = find_csv(root, "food.csv")
                nutrient_csv = find_csv(root, "nutrient.csv")
                food_nutrient_csv = find_csv(root, "food_nutrient.csv")
                portion_csv = find_csv(root, "food_portion.csv")

                if food_csv is None:
                    raise CommandError("USDA CSV import requires food.csv.")

                nutrient_code_by_id = dict(NUTRIENT_CODE_BY_FDC_ID)
                if nutrient_csv:
                    for row in stream_csv(nutrient_csv):
                        nutrient_id = str(row.get("id") or "").strip()
                        name = str(row.get("name") or "").strip().lower()
                        unit = str(row.get("unit_name") or "").strip().lower()
                        code = NUTRIENT_CODE_BY_NAME.get(name)
                        if code == "calories" and unit not in {"kcal", "cal"}:
                            continue
                        if nutrient_id and code:
                            nutrient_code_by_id[nutrient_id] = code

                imported_food_ids = set()
                for row in stream_csv(food_csv):
                    if options["limit"] and result.rows_processed >= options["limit"]:
                        break
                    result.rows_processed += 1
                    fdc_id = str(row.get("fdc_id") or row.get("id") or "").strip()
                    if not fdc_id:
                        result.add_error("Missing fdc_id.", row)
                        continue
                    food, created = upsert_food_record(
                        source=source,
                        canonical_name=row.get("description") or f"USDA food {fdc_id}",
                        external_id=fdc_id,
                        description=row.get("data_type", ""),
                        food_type=(
                            Food.FoodType.BRANDED
                            if "branded" in (row.get("data_type") or "").lower()
                            else Food.FoodType.GENERIC
                        ),
                        country_code="US",
                        language_code="en",
                        data_quality_score=Decimal("0.9500"),
                        verified=True,
                        metadata={"publication_date": row.get("publication_date", "")},
                    )
                    imported_food_ids.add(fdc_id)
                    result.rows_created += int(created)
                    result.rows_updated += int(not created)

                if food_nutrient_csv:
                    for row in stream_csv(food_nutrient_csv):
                        fdc_id = str(row.get("fdc_id") or "").strip()
                        if imported_food_ids and fdc_id not in imported_food_ids:
                            continue
                        nutrient_code = nutrient_code_by_id.get(
                            str(row.get("nutrient_id") or "").strip()
                        )
                        amount = normalize_decimal(row.get("amount"))
                        if not nutrient_code or amount is None:
                            continue
                        food = Food.objects.filter(
                            source=source,
                            external_id=fdc_id,
                        ).first()
                        if food is None:
                            continue
                        nutrient = nutrient_map.get(nutrient_code)
                        if nutrient is None:
                            continue
                        nutrient_batch.append(
                            FoodNutrient(
                                food=food,
                                nutrient=nutrient,
                                source=source,
                                amount_per_100g=amount,
                                confidence_score=Decimal("0.9500"),
                                derivation_method=FoodNutrient.DerivationMethod.LAB,
                            )
                        )
                        if len(nutrient_batch) >= batch_size:
                            flush_nutrient_batch()
                    flush_nutrient_batch()

                if portion_csv:
                    for row in stream_csv(portion_csv):
                        fdc_id = str(row.get("fdc_id") or "").strip()
                        if imported_food_ids and fdc_id not in imported_food_ids:
                            continue
                        food = Food.objects.filter(
                            source=source,
                            external_id=fdc_id,
                        ).first()
                        grams = normalize_decimal(row.get("gram_weight"))
                        if food is None or grams is None:
                            continue
                        portion_description = (
                            row.get("portion_description")
                            or row.get("modifier")
                            or row.get("measure_unit_name")
                            or "USDA portion"
                        )
                        upsert_food_serving(
                            food,
                            serving_name=portion_description,
                            grams=grams,
                            is_default=False,
                        )
        except Exception as exc:  # noqa: BLE001 - command records failed job.
            fail_import_job(job, str(exc))
            raise

        finish_import_job(job, result)
        self.stdout.write(
            self.style.SUCCESS(
                "Imported USDA FDC CSV: "
                f"{result.rows_created} created, {result.rows_updated} updated, "
                f"{len(result.errors or [])} errors."
            )
        )
