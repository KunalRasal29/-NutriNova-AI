import csv
import hashlib
import json
import logging
import os
import tempfile
import urllib.parse
import urllib.request
import zipfile
from collections.abc import Iterable
from contextlib import contextmanager
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from pathlib import Path

from django.db import transaction
from django.utils import timezone

from foods.models import Food, FoodAlias, FoodDataImportJob, FoodNutrient, FoodServing
from nutrition.management.commands.seed_core_nutrition import DATA_SOURCES, NUTRIENTS
from nutrition.models import Nutrient, NutritionDataSource

logger = logging.getLogger(__name__)

NUTRIENT_CODE_BY_FDC_ID = {
    "1008": "calories",
    "1003": "protein_g",
    "1005": "carbs_g",
    "1004": "fat_g",
    "1079": "fiber_g",
    "2000": "sugar_g",
    "1093": "sodium_mg",
    "1092": "potassium_mg",
    "1087": "calcium_mg",
    "1089": "iron_mg",
    "1106": "vitamin_a_mcg",
    "1162": "vitamin_c_mg",
    "1114": "vitamin_d_mcg",
    "1253": "cholesterol_mg",
    "1258": "saturated_fat_g",
    "1257": "trans_fat_g",
}

NUTRIENT_CODE_BY_NAME = {
    "energy": "calories",
    "energy kcal": "calories",
    "protein": "protein_g",
    "carbohydrate": "carbs_g",
    "carbohydrate, by difference": "carbs_g",
    "total carbohydrate": "carbs_g",
    "fat": "fat_g",
    "total lipid (fat)": "fat_g",
    "fiber": "fiber_g",
    "fiber, total dietary": "fiber_g",
    "sugars": "sugar_g",
    "sugars, total including nlea": "sugar_g",
    "sodium": "sodium_mg",
    "potassium": "potassium_mg",
    "calcium": "calcium_mg",
    "iron": "iron_mg",
    "vitamin a": "vitamin_a_mcg",
    "vitamin c": "vitamin_c_mg",
    "vitamin d": "vitamin_d_mcg",
    "cholesterol": "cholesterol_mg",
    "fatty acids, total saturated": "saturated_fat_g",
    "fatty acids, total trans": "trans_fat_g",
}

OPENFOODFACTS_TO_NUTRIENT_CODE = {
    "energy-kcal_100g": "calories",
    "proteins_100g": "protein_g",
    "carbohydrates_100g": "carbs_g",
    "fat_100g": "fat_g",
    "fiber_100g": "fiber_g",
    "sugars_100g": "sugar_g",
    "sodium_100g": "sodium_mg",
    "potassium_100g": "potassium_mg",
    "calcium_100g": "calcium_mg",
    "iron_100g": "iron_mg",
    "vitamin-a_100g": "vitamin_a_mcg",
    "vitamin-c_100g": "vitamin_c_mg",
    "vitamin-d_100g": "vitamin_d_mcg",
    "cholesterol_100g": "cholesterol_mg",
    "saturated-fat_100g": "saturated_fat_g",
    "trans-fat_100g": "trans_fat_g",
}

MILLIGRAM_NUTRIENTS_FROM_GRAMS = {
    "sodium_mg",
    "potassium_mg",
    "calcium_mg",
    "iron_mg",
    "vitamin_c_mg",
    "cholesterol_mg",
}

MICROGRAM_NUTRIENTS_FROM_GRAMS = {"vitamin_a_mcg", "vitamin_d_mcg"}


@dataclass(slots=True)
class ImportResult:
    rows_processed: int = 0
    rows_created: int = 0
    rows_updated: int = 0
    errors: list[dict] | None = None

    def add_error(self, message: str, row: dict | None = None) -> None:
        if self.errors is None:
            self.errors = []
        error = {"message": message}
        if row is not None:
            error["row"] = row
        self.errors.append(error)


def normalize_decimal(value, default=None):
    if value in (None, ""):
        return default
    try:
        return Decimal(str(value).strip())
    except (InvalidOperation, ValueError):
        return default


def normalize_barcode(value: str | None) -> str:
    return "".join(character for character in str(value or "") if character.isdigit())


def parse_bool(value) -> bool:
    if isinstance(value, bool):
        return value
    return str(value or "").strip().lower() in {"1", "true", "yes", "y"}


def get_fixture_path(name: str) -> Path:
    return Path(__file__).resolve().parent / "fixtures" / name


def seed_core_reference_data() -> None:
    for source in DATA_SOURCES:
        NutritionDataSource.objects.update_or_create(
            name=source["name"],
            defaults=source,
        )
    for nutrient in NUTRIENTS:
        Nutrient.objects.update_or_create(
            code=nutrient["code"],
            defaults=nutrient,
        )


def get_data_source(source_type, *, name: str | None = None):
    seed_core_reference_data()
    source = NutritionDataSource.objects.filter(source_type=source_type).first()
    if source:
        return source
    if not name:
        name = str(source_type).replace("_", " ").title()
    return NutritionDataSource.objects.create(
        name=name,
        source_type=source_type,
        license_name="Source-specific terms",
        update_frequency="Manual",
        reliability_score=Decimal("0.5000"),
        is_active=True,
    )


def get_manual_sample_source():
    return NutritionDataSource.objects.update_or_create(
        name="Manual Admin Sample",
        defaults={
            "source_type": NutritionDataSource.SourceType.MANUAL_ADMIN_SAMPLE,
            "license_name": "Project sample data",
            "license_url": "",
            "citation": (
                "Small NutriNova AI development fixture with approximate values. "
                "Use verified sources before production distribution."
            ),
            "source_url": "",
            "update_frequency": "Static sample",
            "reliability_score": Decimal("0.6500"),
            "is_active": True,
        },
    )[0]


def create_import_job(source, *, file_name="", checksum=""):
    return FoodDataImportJob.objects.create(
        source=source,
        status=FoodDataImportJob.Status.RUNNING,
        started_at=timezone.now(),
        file_name=file_name,
        checksum=checksum,
    )


def finish_import_job(job, result: ImportResult, status=None):
    if status is None:
        status = (
            FoodDataImportJob.Status.PARTIAL
            if result.errors
            else FoodDataImportJob.Status.COMPLETED
        )
    job.status = status
    job.finished_at = timezone.now()
    job.rows_processed = result.rows_processed
    job.rows_created = result.rows_created
    job.rows_updated = result.rows_updated
    job.errors = result.errors or []
    job.save()
    return job


def fail_import_job(job, message: str):
    job.status = FoodDataImportJob.Status.FAILED
    job.finished_at = timezone.now()
    job.errors = [{"message": message}]
    job.save()
    return job


def calculate_checksum(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json_fixture(path: Path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def upsert_food_record(
    *,
    source,
    canonical_name,
    external_id="",
    brand_name="",
    description="",
    food_type=Food.FoodType.GENERIC,
    country_code="US",
    language_code="en",
    barcode="",
    serving_description="",
    default_serving_g=None,
    data_quality_score=Decimal("0.7000"),
    verified=False,
    ingredients_text="",
    allergens=None,
    region="",
    metadata=None,
):
    barcode = normalize_barcode(barcode)
    defaults = {
        "canonical_name": canonical_name,
        "brand_name": brand_name or "",
        "description": description or "",
        "ingredients_text": ingredients_text or "",
        "allergens": allergens or [],
        "region": region or "",
        "metadata": metadata or {},
        "food_type": food_type,
        "country_code": (country_code or "US").upper(),
        "language_code": language_code or "en",
        "barcode": barcode,
        "serving_description": serving_description or "",
        "default_serving_g": default_serving_g,
        "data_quality_score": data_quality_score,
        "verified": verified,
    }

    lookup = None
    if external_id:
        lookup = {"source": source, "external_id": str(external_id)}
    elif barcode:
        lookup = {"barcode": barcode}
    if lookup:
        food, created = Food.objects.update_or_create(
            **lookup,
            defaults={
                **defaults,
                "source": source,
                "external_id": str(external_id or ""),
            },
        )
    else:
        food, created = Food.objects.update_or_create(
            source=source,
            canonical_name=canonical_name,
            brand_name=brand_name or "",
            defaults={**defaults, "external_id": str(external_id or "")},
        )
    return food, created


def upsert_food_serving(
    food, *, serving_name, grams, household_quantity="", is_default=False
):
    if not serving_name or grams is None:
        return None
    if is_default:
        FoodServing.objects.filter(food=food, is_default=True).update(is_default=False)
    serving, _ = FoodServing.objects.update_or_create(
        food=food,
        serving_name=serving_name,
        defaults={
            "grams": grams,
            "household_quantity": household_quantity or "",
            "is_default": is_default,
        },
    )
    return serving


def upsert_food_aliases(food, aliases: Iterable[str], language_code="en"):
    for alias in aliases:
        cleaned = str(alias or "").strip()
        if not cleaned:
            continue
        FoodAlias.objects.update_or_create(
            food=food,
            alias=cleaned,
            language_code=language_code or "en",
        )


def upsert_food_nutrients(
    food,
    source,
    nutrients: dict,
    *,
    confidence_score=Decimal("0.7500"),
    derivation_method=FoodNutrient.DerivationMethod.ESTIMATED,
):
    nutrient_map = Nutrient.objects.in_bulk(nutrients.keys(), field_name="code")
    for code, amount in nutrients.items():
        decimal_amount = normalize_decimal(amount)
        nutrient = nutrient_map.get(code)
        if nutrient is None or decimal_amount is None:
            continue
        FoodNutrient.objects.update_or_create(
            food=food,
            nutrient=nutrient,
            source=source,
            derivation_method=derivation_method,
            defaults={
                "amount_per_100g": decimal_amount,
                "confidence_score": confidence_score,
            },
        )


def import_json_food_records(records: list[dict], source, *, default_food_type):
    result = ImportResult(errors=[])
    for record in records:
        result.rows_processed += 1
        try:
            with transaction.atomic():
                food, created = upsert_food_record(
                    source=source,
                    canonical_name=record["canonical_name"],
                    external_id=record.get("external_id", ""),
                    brand_name=record.get("brand_name", ""),
                    description=record.get("description", ""),
                    food_type=record.get("food_type", default_food_type),
                    country_code=record.get("country_code", "US"),
                    language_code=record.get("language_code", "en"),
                    barcode=record.get("barcode", ""),
                    serving_description=record.get("serving_description", ""),
                    default_serving_g=normalize_decimal(
                        record.get("default_serving_g")
                    ),
                    data_quality_score=normalize_decimal(
                        record.get("data_quality_score"),
                        Decimal("0.7000"),
                    ),
                    verified=parse_bool(record.get("verified")),
                    ingredients_text=record.get("ingredients_text", ""),
                    allergens=record.get("allergens", []),
                    region=record.get("region", ""),
                    metadata=record.get("metadata", {}),
                )
                result.rows_created += int(created)
                result.rows_updated += int(not created)
                for serving in record.get("servings", []):
                    upsert_food_serving(
                        food,
                        serving_name=serving.get("serving_name"),
                        grams=normalize_decimal(serving.get("grams")),
                        household_quantity=serving.get("household_quantity", ""),
                        is_default=parse_bool(serving.get("is_default")),
                    )
                if not record.get("servings") and food.default_serving_g:
                    upsert_food_serving(
                        food,
                        serving_name=food.serving_description or "Default serving",
                        grams=food.default_serving_g,
                        is_default=True,
                    )
                upsert_food_aliases(
                    food, record.get("aliases", []), record.get("language_code", "en")
                )
                upsert_food_nutrients(
                    food,
                    source,
                    record.get("nutrients", {}),
                    confidence_score=normalize_decimal(
                        record.get("confidence_score"),
                        Decimal("0.7500"),
                    ),
                    derivation_method=record.get(
                        "derivation_method",
                        FoodNutrient.DerivationMethod.ESTIMATED,
                    ),
                )
        except Exception as exc:  # noqa: BLE001 - importer records row-level errors.
            logger.exception("Failed importing food fixture record")
            result.add_error(str(exc), record)
    return result


def stream_csv(path: Path):
    with path.open(newline="", encoding="utf-8-sig") as handle:
        yield from csv.DictReader(handle)


@contextmanager
def csv_source_path(path: Path):
    if path.is_dir():
        yield path
        return
    if not zipfile.is_zipfile(path):
        raise ValueError(f"{path} is not a folder or zip file.")
    with tempfile.TemporaryDirectory() as temp_dir:
        with zipfile.ZipFile(path) as archive:
            archive.extractall(temp_dir)
        yield Path(temp_dir)


def find_csv(root: Path, *names: str):
    wanted = {name.lower() for name in names}
    for child in root.rglob("*.csv"):
        if child.name.lower() in wanted:
            return child
    return None


def fetch_json(url, *, headers=None, timeout=20):
    request = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        status = getattr(response, "status", 200)
        if status >= 400:
            raise RuntimeError(f"HTTP {status} while requesting {url}")
        return json.loads(response.read().decode("utf-8"))


def build_url(base_url, query_params):
    return f"{base_url}?{urllib.parse.urlencode(query_params)}"


def get_env(name):
    return os.environ.get(name, "").strip()
