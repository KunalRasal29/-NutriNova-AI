import csv
from decimal import Decimal
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from foods.importers import (
    ImportResult,
    create_import_job,
    fail_import_job,
    finish_import_job,
    get_data_source,
    normalize_decimal,
    seed_core_reference_data,
    upsert_food_aliases,
    upsert_food_nutrients,
    upsert_food_record,
    upsert_food_serving,
)
from foods.models import Food, FoodNutrient
from nutrition.models import NutritionDataSource


class Command(BaseCommand):
    help = (
        "Import Indian food/recipe nutrition from a user-provided CSV. "
        "Do not use this to scrape copyrighted PDFs."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--path", required=True, help="Path to authorized CSV file."
        )
        parser.add_argument(
            "--source",
            choices=[
                NutritionDataSource.SourceType.IFCT_2017,
                NutritionDataSource.SourceType.INDB,
            ],
            default=NutritionDataSource.SourceType.IFCT_2017,
        )

    def handle(self, *args, **options):
        seed_core_reference_data()
        path = Path(options["path"])
        if not path.exists():
            raise CommandError(f"CSV file not found: {path}")

        source = get_data_source(options["source"])
        job = create_import_job(source, file_name=str(path))
        result = ImportResult(errors=[])
        nutrient_columns = {
            "calories_kcal": "calories",
            "protein_g": "protein_g",
            "carbs_g": "carbs_g",
            "fat_g": "fat_g",
            "fiber_g": "fiber_g",
            "sugar_g": "sugar_g",
            "sodium_mg": "sodium_mg",
            "potassium_mg": "potassium_mg",
            "calcium_mg": "calcium_mg",
            "iron_mg": "iron_mg",
            "cholesterol_mg": "cholesterol_mg",
            "saturated_fat_g": "saturated_fat_g",
        }

        try:
            with path.open(newline="", encoding="utf-8-sig") as handle:
                reader = csv.DictReader(handle)
                for row in reader:
                    result.rows_processed += 1
                    name = (row.get("name") or "").strip()
                    if not name:
                        result.add_error("Missing required name.", row)
                        continue
                    food, created = upsert_food_record(
                        source=source,
                        canonical_name=name,
                        external_id=row.get("source_external_id", ""),
                        description=f"Imported Indian food from {source.name}.",
                        food_type=Food.FoodType.GENERIC,
                        country_code="IN",
                        language_code="en",
                        serving_description=row.get("serving_g", "") and "Serving",
                        default_serving_g=normalize_decimal(row.get("serving_g")),
                        data_quality_score=Decimal("0.8500"),
                        verified=True,
                        region=row.get("region", ""),
                        metadata={"source_argument": options["source"]},
                    )
                    result.rows_created += int(created)
                    result.rows_updated += int(not created)

                    if food.default_serving_g:
                        upsert_food_serving(
                            food,
                            serving_name="Serving",
                            grams=food.default_serving_g,
                            is_default=True,
                        )

                    aliases = [
                        alias.strip()
                        for alias in (row.get("language_aliases") or "").split("|")
                    ]
                    upsert_food_aliases(food, aliases, language_code="hi")
                    upsert_food_nutrients(
                        food,
                        source,
                        {
                            code: row.get(column)
                            for column, code in nutrient_columns.items()
                        },
                        confidence_score=Decimal("0.8500"),
                        derivation_method=FoodNutrient.DerivationMethod.CALCULATED,
                    )
        except Exception as exc:  # noqa: BLE001 - command records failed job.
            fail_import_job(job, str(exc))
            raise

        finish_import_job(job, result)
        self.stdout.write(
            self.style.SUCCESS(
                "Imported Indian foods CSV: "
                f"{result.rows_created} created, {result.rows_updated} updated, "
                f"{len(result.errors or [])} errors."
            )
        )
