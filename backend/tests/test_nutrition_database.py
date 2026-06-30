from decimal import Decimal

import pytest
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.urls import reverse
from rest_framework.test import APIClient

from foods.models import Food, FoodDataImportJob, FoodNutrient, FoodServing
from nutrition.models import Nutrient, NutritionDataSource

User = get_user_model()


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def user():
    return User.objects.create_user(
        username="nutrition@example.com",
        email="nutrition@example.com",
        password="strong-local-passphrase",
    )


@pytest.fixture
def seeded_core():
    call_command("seed_core_nutrition")


@pytest.fixture
def sample_food(seeded_core):
    source = NutritionDataSource.objects.get(
        source_type=NutritionDataSource.SourceType.IFCT_2017
    )
    food = Food.objects.create(
        canonical_name="Paneer",
        brand_name="",
        description="Indian cottage cheese",
        food_type=Food.FoodType.GENERIC,
        source=source,
        external_id="IFCT-PANEER-001",
        country_code="IN",
        language_code="en",
        barcode="8901234567890",
        serving_description="100 g",
        default_serving_g=Decimal("100.00"),
        data_quality_score=Decimal("0.9000"),
        verified=True,
    )
    FoodServing.objects.create(
        food=food,
        serving_name="100 g",
        grams=Decimal("100.00"),
        is_default=True,
    )
    nutrient_values = {
        "calories": Decimal("265.0000"),
        "protein_g": Decimal("18.3000"),
        "carbs_g": Decimal("1.2000"),
        "fat_g": Decimal("20.8000"),
        "fiber_g": Decimal("0.0000"),
        "sodium_mg": Decimal("22.0000"),
        "calcium_mg": Decimal("208.0000"),
        "saturated_fat_g": Decimal("13.1000"),
    }
    FoodNutrient.objects.bulk_create(
        [
            FoodNutrient(
                food=food,
                nutrient=Nutrient.objects.get(code=code),
                amount_per_100g=amount,
                source=source,
                confidence_score=Decimal("0.9000"),
                derivation_method=FoodNutrient.DerivationMethod.LAB,
            )
            for code, amount in nutrient_values.items()
        ]
    )
    return food


@pytest.mark.django_db
def test_seed_core_nutrition_creates_sources(seeded_core):
    source_types = set(
        NutritionDataSource.objects.values_list("source_type", flat=True)
    )

    assert NutritionDataSource.objects.count() == 6
    assert NutritionDataSource.SourceType.USDA_FDC in source_types
    assert NutritionDataSource.SourceType.OPEN_FOOD_FACTS in source_types
    assert NutritionDataSource.SourceType.IFCT_2017 in source_types
    assert NutritionDataSource.SourceType.INDB in source_types
    assert NutritionDataSource.SourceType.USER_CUSTOM in source_types
    assert NutritionDataSource.SourceType.AI_ESTIMATE in source_types


@pytest.mark.django_db
def test_seed_core_nutrition_creates_common_nutrients(seeded_core):
    nutrient_codes = set(Nutrient.objects.values_list("code", flat=True))

    assert Nutrient.objects.count() == 16
    assert {
        "calories",
        "protein_g",
        "carbs_g",
        "fat_g",
        "fiber_g",
        "sodium_mg",
        "vitamin_c_mg",
        "trans_fat_g",
    }.issubset(nutrient_codes)


@pytest.mark.django_db
def test_create_custom_food_with_nutrients(api_client, user, seeded_core):
    api_client.force_authenticate(user=user)

    response = api_client.post(
        reverse("food-custom-create"),
        {
            "canonical_name": "Homemade dal",
            "country_code": "in",
            "serving_description": "1 bowl",
            "default_serving_g": "180.00",
            "nutrients": [
                {
                    "nutrient_code": "calories",
                    "amount_per_100g": "116.0000",
                    "confidence_score": "0.7000",
                    "derivation_method": "user_entered",
                },
                {
                    "nutrient_code": "protein_g",
                    "amount_per_100g": "7.2000",
                    "confidence_score": "0.7000",
                    "derivation_method": "user_entered",
                },
            ],
        },
        format="json",
    )

    assert response.status_code == 201
    payload = response.json()
    assert payload["canonical_name"] == "Homemade dal"
    assert payload["food_type"] == "user_custom"
    assert payload["country_code"] == "IN"
    assert payload["source"]["source_type"] == "USER_CUSTOM"
    assert len(payload["nutrients"]) == 2

    food = Food.objects.get(id=payload["id"])
    assert food.created_by == user
    assert food.nutrients.count() == 2
    assert food.servings.get(is_default=True).grams == Decimal("180.00")


@pytest.mark.django_db
def test_food_search_endpoint_returns_macro_summary(api_client, user, sample_food):
    api_client.force_authenticate(user=user)

    response = api_client.get(reverse("food-search"), {"q": "paneer"})

    assert response.status_code == 200
    result = response.json()["results"][0]
    assert result["id"] == str(sample_food.id)
    assert result["name"] == "Paneer"
    assert result["data_source"] == "IFCT 2017"
    assert result["verified"] is True
    assert result["nutrition_per_100g"]["calories"] == 265.0
    assert result["nutrition_per_100g"]["protein_g"] == 18.3
    assert result["nutrition_per_100g"]["sodium_mg"] == 22.0
    assert result["nutrition_per_100g"]["calcium_mg"] == 208.0
    assert result["nutrition_per_100g"]["saturated_fat_g"] == 13.1


@pytest.mark.django_db
def test_food_search_endpoint_supports_barcode_lookup(api_client, user, sample_food):
    api_client.force_authenticate(user=user)

    response = api_client.get(
        reverse("food-search"),
        {"barcode": "8901234567890"},
    )

    assert response.status_code == 200
    results = response.json()["results"]
    assert len(results) == 1
    assert results[0]["id"] == str(sample_food.id)
    assert results[0]["name"] == "Paneer"


@pytest.mark.django_db
def test_usda_sample_importer_creates_import_job_and_foods():
    call_command("import_usda_fdc_sample")

    source = NutritionDataSource.objects.get(name="Manual Admin Sample")
    job = FoodDataImportJob.objects.get(source=source)
    assert job.status == FoodDataImportJob.Status.COMPLETED
    assert job.rows_processed == 20
    assert job.rows_created == 20
    assert Food.objects.filter(source=source).count() == 20
    assert Food.objects.get(canonical_name="Paneer").nutrients.count() >= 4


@pytest.mark.django_db
def test_sample_importer_upserts_instead_of_creating_duplicates():
    call_command("import_usda_fdc_sample")
    call_command("import_usda_fdc_sample")

    source = NutritionDataSource.objects.get(name="Manual Admin Sample")
    assert Food.objects.filter(source=source).count() == 20
    assert FoodDataImportJob.objects.filter(source=source).count() == 2
    latest_job = FoodDataImportJob.objects.filter(source=source).latest("created_at")
    assert latest_job.rows_created == 0
    assert latest_job.rows_updated == 20


@pytest.mark.django_db
def test_popular_food_seed_adds_broader_daily_catalog(api_client, user):
    call_command("seed_popular_foods")

    source = NutritionDataSource.objects.get(name="Manual Admin Sample")
    assert Food.objects.filter(source=source).count() >= 110

    chicken_curry = Food.objects.get(source=source, canonical_name="Chicken curry")
    assert chicken_curry.servings.get(is_default=True).grams == Decimal("220.00")
    assert chicken_curry.nutrients.filter(nutrient__code="sodium_mg").exists()

    chapati = Food.objects.get(source=source, canonical_name="Chapati, whole wheat")
    assert chapati.aliases.filter(alias="phulka").exists()
    assert chapati.nutrients.filter(nutrient__code="iron_mg").exists()

    assert Food.objects.filter(source=source, aliases__alias="besan chilla").exists()
    assert Food.objects.filter(source=source, aliases__alias="protein shake").exists()

    api_client.force_authenticate(user=user)
    response = api_client.get(reverse("food-search"), {"q": "chapati"})
    assert response.status_code == 200
    assert response.json()["results"][0]["name"] == "Chapati, whole wheat"

    response = api_client.get(reverse("food-search"), {"q": "protein shake"})
    assert response.status_code == 200
    names = {result["name"] for result in response.json()["results"]}
    assert "Protein shake with milk" in names


@pytest.mark.django_db
def test_openfoodfacts_sample_importer_works():
    call_command("import_openfoodfacts_sample")

    source = NutritionDataSource.objects.get(
        source_type=NutritionDataSource.SourceType.OPEN_FOOD_FACTS
    )
    assert (
        Food.objects.filter(source=source, food_type=Food.FoodType.BRANDED).count()
        == 10
    )
    assert Food.objects.get(barcode="8900000000042").allergens == ["peanuts"]


@pytest.mark.django_db
def test_openfoodfacts_barcode_missing_product_is_graceful(monkeypatch):
    monkeypatch.setenv("OPENFOODFACTS_USER_AGENT", "NutriNovaAI/0.1 test@example.com")

    def fake_fetch_json(url, *, headers=None, timeout=20):
        return {"status": "failure", "result": {"id": "product_not_found"}}

    monkeypatch.setattr(
        "foods.management.commands.sync_openfoodfacts_barcode.fetch_json",
        fake_fetch_json,
    )

    call_command("sync_openfoodfacts_barcode", barcode="0000000000000")

    source = NutritionDataSource.objects.get(
        source_type=NutritionDataSource.SourceType.OPEN_FOOD_FACTS
    )
    job = FoodDataImportJob.objects.get(source=source)
    assert job.status == FoodDataImportJob.Status.PARTIAL
    assert job.errors[0]["message"] == "Product not found."
    assert Food.objects.filter(barcode="0000000000000").exists() is False


@pytest.mark.django_db
def test_indian_foods_csv_importer(tmp_path):
    csv_path = tmp_path / "indian_foods.csv"
    csv_path.write_text(
        "name,serving_g,calories_kcal,protein_g,carbs_g,fat_g,fiber_g,"
        "sugar_g,sodium_mg,source_external_id,region,language_aliases\n"
        "Poha,180,130,2.6,23.0,3.5,2.1,1.5,220,IN-SAMPLE-POHA,"
        "Maharashtra,kanda poha|pohe\n",
        encoding="utf-8",
    )

    call_command(
        "import_indian_foods_csv",
        path=str(csv_path),
        source=NutritionDataSource.SourceType.INDB,
    )

    source = NutritionDataSource.objects.get(
        source_type=NutritionDataSource.SourceType.INDB
    )
    food = Food.objects.get(source=source, external_id="IN-SAMPLE-POHA")
    assert food.region == "Maharashtra"
    assert food.servings.get(is_default=True).grams == Decimal("180.00")
    assert food.aliases.filter(alias="kanda poha").exists()
    assert food.nutrients.filter(nutrient__code="calories").exists()
