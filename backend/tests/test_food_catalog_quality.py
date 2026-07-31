from decimal import Decimal
from io import StringIO

import pytest
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.urls import reverse
from rest_framework.test import APIClient

from foods.importers import get_data_source
from foods.models import Food, FoodAlias, FoodDataImportJob, FoodNutrient
from foods.services.data_quality import assess_food_quality
from foods.services.nutrient_normalization import (
    normalize_openfoodfacts_nutrient,
    normalize_usda_nutrient,
)
from nutrition.models import Nutrient, NutritionDataSource

User = get_user_model()


@pytest.fixture
def seeded_core():
    call_command("seed_core_nutrition")


def test_usda_normalization_preserves_original_unit_and_separates_energy():
    sodium = normalize_usda_nutrient(
        nutrient_id="1093",
        name="Sodium",
        unit="g",
        amount="0.42",
    )
    energy = normalize_usda_nutrient(
        nutrient_id="1062",
        name="Energy",
        unit="kJ",
        amount="418.4",
    )

    assert sodium is not None
    assert sodium.code == "sodium_mg"
    assert sodium.amount == Decimal("420.00")
    assert sodium.original_amount == Decimal("0.42")
    assert sodium.original_unit == "g"
    assert energy is not None
    assert energy.code == "energy_kj"
    assert energy.amount == Decimal("418.4")


def test_openfoodfacts_salt_does_not_get_treated_as_sodium_grams():
    normalized = normalize_openfoodfacts_nutrient(key="salt_100g", amount="1.5")

    assert normalized is not None
    assert normalized.code == "sodium_mg"
    assert normalized.amount == Decimal("600.0")
    assert normalized.original_amount == Decimal("1.5")
    assert "salt" in normalized.normalization_notes.lower()


@pytest.mark.django_db
def test_quality_audit_detects_macro_mismatch_and_missing_nutrients(seeded_core):
    source = get_data_source(NutritionDataSource.SourceType.USDA_FDC)
    food = Food.objects.create(
        canonical_name="Suspicious test food",
        source=source,
        external_id="QUALITY-SUSPICIOUS",
        verified=True,
    )
    for code, amount in {
        "calories": "900",
        "protein_g": "1",
        "carbs_g": "1",
        "fat_g": "1",
    }.items():
        FoodNutrient.objects.create(
            food=food,
            nutrient=Nutrient.objects.get(code=code),
            amount_per_100g=Decimal(amount),
            source=source,
            confidence_score=Decimal("0.9"),
            derivation_method=FoodNutrient.DerivationMethod.LAB,
        )

    assessment = assess_food_quality(food)

    assert "macro_calorie_mismatch" in assessment.warnings
    assert not any(
        item.startswith("missing_core_macros") for item in assessment.warnings
    )
    assert assessment.completeness_score == Decimal("0.5714")


@pytest.mark.django_db
def test_search_is_accent_insensitive_and_hides_deprecated_foods(seeded_core):
    user = User.objects.create_user(
        username="catalog-search@example.com",
        email="catalog-search@example.com",
        password="local-test-passphrase",
    )
    source = get_data_source(NutritionDataSource.SourceType.USDA_FDC)
    active = Food.objects.create(
        canonical_name="Crème yogurt",
        source=source,
        external_id="SEARCH-CREME-ACTIVE",
        dataset_type=Food.DatasetType.USDA_FOUNDATION,
        verified=True,
        data_quality_score=Decimal("0.95"),
    )
    FoodAlias.objects.create(food=active, alias="Crème dahi", language_code="fr")
    Food.objects.create(
        canonical_name="Creme yogurt old",
        source=source,
        external_id="SEARCH-CREME-OLD",
        is_deprecated=True,
    )
    client = APIClient()
    client.force_authenticate(user=user)

    response = client.get(reverse("food-search"), {"q": "creme dahi"})

    assert response.status_code == 200
    ids = [item["id"] for item in response.json()["results"]]
    assert str(active.id) in ids
    assert len(ids) == 1


@pytest.mark.django_db
def test_search_ranks_foundation_above_unverified_packaged_match(seeded_core):
    user = User.objects.create_user(
        username="catalog-rank@example.com",
        email="catalog-rank@example.com",
        password="local-test-passphrase",
    )
    usda = get_data_source(NutritionDataSource.SourceType.USDA_FDC)
    off = get_data_source(NutritionDataSource.SourceType.OPEN_FOOD_FACTS)
    trusted = Food.objects.create(
        canonical_name="Plain oats",
        source=usda,
        external_id="RANK-USDA-OATS",
        dataset_type=Food.DatasetType.USDA_FOUNDATION,
        verified=True,
        data_quality_score=Decimal("0.95"),
    )
    Food.objects.create(
        canonical_name="Plain oats",
        source=off,
        external_id="RANK-OFF-OATS",
        dataset_type=Food.DatasetType.OPEN_FOOD_FACTS,
        verified=False,
        data_quality_score=Decimal("0.75"),
    )
    client = APIClient()
    client.force_authenticate(user=user)

    response = client.get(reverse("food-search"), {"q": "plain oats"})

    assert response.status_code == 200
    assert response.json()["results"][0]["id"] == str(trusted.id)


@pytest.mark.django_db
def test_usda_stream_import_records_release_portion_and_normalization(
    tmp_path,
    seeded_core,
):
    (tmp_path / "food.csv").write_text(
        "fdc_id,data_type,description,publication_date\n"
        "991001,foundation_food,Test lentil cooked,2026-04-01\n",
        encoding="utf-8",
    )
    (tmp_path / "nutrient.csv").write_text(
        "id,name,unit_name\n1008,Energy,KCAL\n1093,Sodium,MG\n",
        encoding="utf-8",
    )
    (tmp_path / "food_nutrient.csv").write_text(
        "fdc_id,nutrient_id,amount\n991001,1008,116\n991001,1093,22\n",
        encoding="utf-8",
    )
    (tmp_path / "food_portion.csv").write_text(
        "fdc_id,gram_weight,portion_description\n991001,180,1 bowl\n",
        encoding="utf-8",
    )

    call_command(
        "import_usda_fdc",
        path=str(tmp_path),
        dataset="foundation",
        release_version="2026-04",
    )

    food = Food.objects.get(external_id="991001")
    calories = food.nutrients.get(nutrient__code="calories")
    assert food.dataset_type == Food.DatasetType.USDA_FOUNDATION
    assert food.dataset_release == "2026-04"
    assert food.preparation_state == Food.PreparationState.COOKED
    assert food.servings.get().grams == Decimal("180")
    assert calories.amount_per_100g == Decimal("116")
    assert calories.original_amount == Decimal("116")
    assert calories.original_unit == "KCAL"


@pytest.mark.django_db
def test_usda_import_resume_skips_completed_food_rows(tmp_path, seeded_core):
    (tmp_path / "food.csv").write_text(
        "fdc_id,data_type,description,publication_date\n"
        "992001,foundation_food,First resume food,2026-04-01\n"
        "992002,foundation_food,Second resume food,2026-04-01\n",
        encoding="utf-8",
    )
    source = get_data_source(NutritionDataSource.SourceType.USDA_FDC)
    FoodDataImportJob.objects.create(
        source=source,
        status=FoodDataImportJob.Status.FAILED,
        file_name=str(tmp_path),
        dataset_type="foundation",
        resume_offset=1,
    )

    call_command(
        "import_usda_fdc",
        path=str(tmp_path),
        dataset="foundation",
        resume=True,
    )

    assert not Food.objects.filter(external_id="992001").exists()
    assert Food.objects.filter(external_id="992002").exists()
    job = FoodDataImportJob.objects.latest("created_at")
    assert job.rows_skipped == 1
    assert job.resume_offset == 2


@pytest.mark.django_db
def test_usda_import_deduplicates_two_source_rows_for_one_canonical_nutrient(
    tmp_path,
    seeded_core,
):
    (tmp_path / "food.csv").write_text(
        "fdc_id,data_type,description,publication_date\n"
        "993001,foundation_food,Duplicate energy source test,2026-04-01\n",
        encoding="utf-8",
    )
    (tmp_path / "nutrient.csv").write_text(
        "id,name,unit_name\n1008,Energy,KCAL\n9998,Energy kcal,KCAL\n",
        encoding="utf-8",
    )
    (tmp_path / "food_nutrient.csv").write_text(
        "fdc_id,nutrient_id,amount\n993001,1008,100\n993001,9998,101\n",
        encoding="utf-8",
    )

    call_command(
        "import_usda_fdc",
        path=str(tmp_path),
        dataset="foundation",
    )

    food = Food.objects.get(external_id="993001")
    assert food.nutrients.filter(nutrient__code="calories").count() == 1
    assert food.nutrients.get(nutrient__code="calories").amount_per_100g == Decimal(
        "100"
    )


@pytest.mark.django_db
def test_duplicate_and_stats_commands_are_read_only(seeded_core):
    source = get_data_source(NutritionDataSource.SourceType.USDA_FDC)
    for external_id in ("DUPLICATE-1", "DUPLICATE-2"):
        Food.objects.create(
            canonical_name="Duplicate oats",
            source=source,
            external_id=external_id,
            dataset_type=Food.DatasetType.USDA_FOUNDATION,
        )
    output = StringIO()

    call_command("find_food_duplicates", stdout=output)
    call_command("food_database_stats", stdout=output)

    assert "duplicate_candidate_groups: 1" in output.getvalue()
    assert Food.objects.filter(canonical_name="Duplicate oats").count() == 2


@pytest.mark.django_db
def test_deprecated_replacement_keeps_old_food_record(seeded_core):
    source = get_data_source(NutritionDataSource.SourceType.USDA_FDC)
    canonical = Food.objects.create(
        canonical_name="Canonical oats",
        source=source,
        external_id="CANONICAL-OATS",
    )
    old = Food.objects.create(
        canonical_name="Old oats",
        source=source,
        external_id="OLD-OATS",
        is_deprecated=True,
        replacement_food=canonical,
    )

    old.refresh_from_db()
    assert old.replacement_food == canonical
    assert Food.objects.filter(pk=old.pk).exists()
