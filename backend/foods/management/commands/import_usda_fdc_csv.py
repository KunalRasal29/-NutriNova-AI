from __future__ import annotations

from datetime import datetime, time
from decimal import Decimal
from functools import lru_cache
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone
from django.utils.dateparse import parse_date

from foods.importers import (
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
from foods.models import Food, FoodDataImportJob, FoodNutrient
from foods.services.nutrient_normalization import normalize_usda_nutrient
from nutrition.models import Nutrient, NutritionDataSource

DATASET_CONFIGURATION = {
    "foundation": {
        "model_value": Food.DatasetType.USDA_FOUNDATION,
        "data_types": {"foundation", "foundation_food"},
        "quality": Decimal("0.9800"),
        "derivation": FoodNutrient.DerivationMethod.LAB,
    },
    "fndds": {
        "model_value": Food.DatasetType.USDA_FNDDS,
        "data_types": {"survey (fndds)", "survey", "survey_fndds_food"},
        "quality": Decimal("0.9300"),
        "derivation": FoodNutrient.DerivationMethod.CALCULATED,
    },
    "sr_legacy": {
        "model_value": Food.DatasetType.USDA_SR_LEGACY,
        "data_types": {"sr legacy", "sr_legacy_food"},
        "quality": Decimal("0.9400"),
        "derivation": FoodNutrient.DerivationMethod.LAB,
    },
    "branded": {
        "model_value": Food.DatasetType.USDA_BRANDED,
        "data_types": {"branded", "branded_food"},
        "quality": Decimal("0.8200"),
        "derivation": FoodNutrient.DerivationMethod.LABEL,
    },
    "experimental": {
        "model_value": Food.DatasetType.USDA_EXPERIMENTAL,
        "data_types": {"experimental", "experimental_food"},
        "quality": Decimal("0.9000"),
        "derivation": FoodNutrient.DerivationMethod.LAB,
    },
}


def _source_datetime(value: str | None):
    parsed = parse_date(str(value or ""))
    if parsed is None:
        return None
    return timezone.make_aware(datetime.combine(parsed, time.min))


class Command(BaseCommand):
    help = (
        "Stream an official USDA FoodData Central CSV download into the local "
        "catalog with provenance, resumable food-row progress, and batch nutrients."
    )

    def add_arguments(self, parser):
        parser.add_argument("--path", required=True, help="FDC zip or folder path.")
        parser.add_argument(
            "--dataset",
            choices=tuple(DATASET_CONFIGURATION) + ("all",),
            default="all",
        )
        parser.add_argument(
            "--mode",
            choices=("starter", "full"),
            default="full",
            help="Starter imports at most 2,000 foods unless --limit is supplied.",
        )
        parser.add_argument("--release-version", default="")
        parser.add_argument("--resume", action="store_true")
        parser.add_argument("--limit", type=int, default=0)
        parser.add_argument("--batch-size", type=int, default=1000)

    def handle(self, *args, **options):
        seed_core_reference_data()
        path = Path(options["path"])
        if not path.exists():
            raise CommandError(f"Path not found: {path}")

        dataset_name = options["dataset"]
        limit = options["limit"]
        if options["mode"] == "starter" and not limit:
            limit = 2000
        checksum = calculate_checksum(path) if path.is_file() else ""
        source = get_data_source(NutritionDataSource.SourceType.USDA_FDC)
        resume_offset = 0
        if options["resume"]:
            previous = (
                FoodDataImportJob.objects.filter(
                    source=source,
                    file_name=str(path),
                    checksum=checksum,
                    dataset_type=dataset_name,
                )
                .exclude(status=FoodDataImportJob.Status.COMPLETED)
                .order_by("-created_at")
                .first()
            )
            if previous:
                resume_offset = previous.resume_offset

        job = create_import_job(
            source,
            file_name=str(path),
            checksum=checksum,
            dataset_type=dataset_name,
            release_version=options["release_version"],
            resume_offset=resume_offset,
            metadata={"mode": options["mode"], "limit": limit},
        )
        result = ImportResult(errors=[])
        batch_size = max(options["batch_size"], 1)
        nutrient_batch: list[FoodNutrient] = []
        nutrient_map = Nutrient.objects.in_bulk(field_name="code")

        selected_configs = (
            DATASET_CONFIGURATION.values()
            if dataset_name == "all"
            else (DATASET_CONFIGURATION[dataset_name],)
        )

        def config_for_row(data_type: str):
            normalized = " ".join((data_type or "").strip().lower().split())
            for name, config in DATASET_CONFIGURATION.items():
                if normalized in config["data_types"]:
                    if dataset_name in {"all", name}:
                        return config
                    return None
            return None

        def flush_nutrients():
            if not nutrient_batch:
                return
            deduplicated = {}
            for item in nutrient_batch:
                key = (
                    item.food_id,
                    item.nutrient_id,
                    item.source_id,
                    item.derivation_method,
                )
                if key in deduplicated:
                    result.rows_skipped += 1
                    continue
                deduplicated[key] = item
            FoodNutrient.objects.bulk_create(
                deduplicated.values(),
                batch_size=batch_size,
                update_conflicts=True,
                update_fields=(
                    "amount_per_100g",
                    "min_value",
                    "max_value",
                    "confidence_score",
                    "original_amount",
                    "original_unit",
                    "source_nutrient_id",
                    "normalization_notes",
                ),
                unique_fields=("food", "nutrient", "source", "derivation_method"),
            )
            nutrient_batch.clear()

        @lru_cache(maxsize=5000)
        def imported_food(external_id: str):
            return Food.objects.filter(
                source=source,
                external_id=external_id,
                dataset_type__in=[config["model_value"] for config in selected_configs],
            ).first()

        try:
            with csv_source_path(path) as root:
                food_csv = find_csv(root, "food.csv")
                nutrient_csv = find_csv(root, "nutrient.csv")
                food_nutrient_csv = find_csv(root, "food_nutrient.csv")
                portion_csv = find_csv(root, "food_portion.csv")
                branded_csv = find_csv(root, "branded_food.csv")
                if food_csv is None:
                    raise CommandError("USDA CSV import requires food.csv.")

                nutrient_definitions = {}
                if nutrient_csv:
                    for row in stream_csv(nutrient_csv):
                        nutrient_id = str(row.get("id") or "").strip()
                        if nutrient_id:
                            nutrient_definitions[nutrient_id] = {
                                "name": row.get("name") or "",
                                "unit": row.get("unit_name") or "",
                            }

                selected_row_index = 0
                for row in stream_csv(food_csv):
                    config = config_for_row(row.get("data_type") or "")
                    if config is None:
                        continue
                    selected_row_index += 1
                    if selected_row_index <= resume_offset:
                        result.rows_skipped += 1
                        continue
                    if limit and result.rows_processed >= limit:
                        break

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
                            if config["model_value"] == Food.DatasetType.USDA_BRANDED
                            else Food.FoodType.GENERIC
                        ),
                        dataset_type=config["model_value"],
                        dataset_release=options["release_version"],
                        source_updated_at=_source_datetime(row.get("publication_date")),
                        country_code="US",
                        language_code="en",
                        data_quality_score=config["quality"],
                        verified=True,
                        metadata={"publication_date": row.get("publication_date", "")},
                    )
                    result.rows_processed += 1
                    result.rows_created += int(created)
                    result.rows_updated += int(not created)
                    job.resume_offset = selected_row_index
                    if result.rows_processed % 500 == 0:
                        job.rows_processed = result.rows_processed
                        job.resume_offset = selected_row_index
                        job.save(
                            update_fields=(
                                "rows_processed",
                                "resume_offset",
                                "updated_at",
                            )
                        )

                imported_food.cache_clear()

                if branded_csv and dataset_name in {"all", "branded"}:
                    for row in stream_csv(branded_csv):
                        food = imported_food(str(row.get("fdc_id") or "").strip())
                        if food is None:
                            continue
                        barcode = str(row.get("gtin_upc") or "").strip()
                        if (
                            barcode
                            and Food.objects.filter(barcode=barcode)
                            .exclude(pk=food.pk)
                            .exists()
                        ):
                            barcode = ""
                            result.rows_skipped += 1
                        serving_unit = str(row.get("serving_size_unit") or "").lower()
                        food.brand_name = (
                            row.get("brand_owner") or row.get("brand_name") or ""
                        )
                        food.barcode = barcode
                        food.ingredients_text = row.get("ingredients") or ""
                        food.serving_description = row.get("serving_size_unit") or ""
                        food.default_serving_g = (
                            normalize_decimal(row.get("serving_size"))
                            if serving_unit in {"g", "gram", "grams"}
                            else None
                        )
                        food.source_updated_at = _source_datetime(
                            row.get("modified_date") or row.get("available_date")
                        )
                        food.save()

                if food_nutrient_csv:
                    for row in stream_csv(food_nutrient_csv):
                        fdc_id = str(row.get("fdc_id") or "").strip()
                        food = imported_food(fdc_id)
                        if food is None:
                            continue
                        source_id = str(row.get("nutrient_id") or "").strip()
                        definition = nutrient_definitions.get(source_id, {})
                        normalized = normalize_usda_nutrient(
                            nutrient_id=source_id,
                            name=definition.get("name", ""),
                            unit=definition.get("unit", ""),
                            amount=row.get("amount"),
                        )
                        if normalized is None:
                            continue
                        normalized_min = normalize_usda_nutrient(
                            nutrient_id=source_id,
                            name=definition.get("name", ""),
                            unit=definition.get("unit", ""),
                            amount=row.get("min"),
                        )
                        normalized_max = normalize_usda_nutrient(
                            nutrient_id=source_id,
                            name=definition.get("name", ""),
                            unit=definition.get("unit", ""),
                            amount=row.get("max"),
                        )
                        nutrient = nutrient_map.get(normalized.code)
                        if nutrient is None:
                            continue
                        config = next(
                            value
                            for value in DATASET_CONFIGURATION.values()
                            if value["model_value"] == food.dataset_type
                        )
                        nutrient_batch.append(
                            FoodNutrient(
                                food=food,
                                nutrient=nutrient,
                                source=source,
                                amount_per_100g=normalized.amount,
                                min_value=(
                                    normalized_min.amount if normalized_min else None
                                ),
                                max_value=(
                                    normalized_max.amount if normalized_max else None
                                ),
                                original_amount=normalized.original_amount,
                                original_unit=normalized.original_unit,
                                source_nutrient_id=normalized.source_nutrient_id,
                                normalization_notes=normalized.normalization_notes,
                                confidence_score=config["quality"],
                                derivation_method=config["derivation"],
                            )
                        )
                        if len(nutrient_batch) >= batch_size:
                            flush_nutrients()
                    flush_nutrients()

                if portion_csv:
                    for row in stream_csv(portion_csv):
                        food = imported_food(str(row.get("fdc_id") or "").strip())
                        grams = normalize_decimal(row.get("gram_weight"))
                        if food is None or grams is None or grams <= 0:
                            continue
                        description = (
                            row.get("portion_description")
                            or row.get("modifier")
                            or row.get("measure_unit_name")
                            or "USDA portion"
                        )
                        upsert_food_serving(
                            food,
                            serving_name=description,
                            grams=grams,
                            is_default=False,
                        )
        except Exception as exc:  # noqa: BLE001 - import jobs retain failure details.
            fail_import_job(job, str(exc))
            raise

        job.resume_offset = max(
            job.resume_offset,
            resume_offset + result.rows_processed,
        )
        finish_import_job(job, result)
        self.stdout.write(
            self.style.SUCCESS(
                "Imported USDA FDC: "
                f"{result.rows_created} created, {result.rows_updated} updated, "
                f"{result.rows_skipped} skipped source rows, "
                f"{len(result.errors or [])} errors."
            )
        )
