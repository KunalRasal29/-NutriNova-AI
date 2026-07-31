from decimal import Decimal

import pytest
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.urls import reverse
from rest_framework.test import APIClient

from foods.models import (
    FavoriteFood,
    Food,
    FoodDataImportJob,
    FoodNutrient,
    FoodServing,
)
from meals.services.manual_add import manual_food_preview
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

    assert Nutrient.objects.count() == 21
    assert {
        "calories",
        "protein_g",
        "carbs_g",
        "fat_g",
        "fiber_g",
        "sodium_mg",
        "vitamin_c_mg",
        "trans_fat_g",
        "added_sugar_g",
        "net_carbs_g",
        "energy_kj",
        "folate_mcg",
        "folic_acid_mcg",
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
def test_food_collection_endpoints_return_recent_frequent_favorites_and_my_foods(
    api_client,
    user,
    sample_food,
):
    source = sample_food.source
    rice = Food.objects.create(
        canonical_name="Cooked rice",
        food_type=Food.FoodType.GENERIC,
        source=source,
        external_id="IFCT-RICE-001",
        country_code="IN",
        serving_description="1 cup",
        default_serving_g=Decimal("160.00"),
        data_quality_score=Decimal("0.8500"),
    )
    FoodServing.objects.create(
        food=rice,
        serving_name="1 cup",
        grams=Decimal("160.00"),
        is_default=True,
    )
    custom = Food.objects.create(
        canonical_name="Kunal private oats",
        food_type=Food.FoodType.USER_CUSTOM,
        source=NutritionDataSource.objects.get(
            source_type=NutritionDataSource.SourceType.USER_CUSTOM
        ),
        external_id="",
        country_code="IN",
        serving_description="1 bowl",
        default_serving_g=Decimal("100.00"),
        data_quality_score=Decimal("0.5000"),
        created_by=user,
    )
    FoodServing.objects.create(
        food=custom,
        serving_name="1 bowl",
        grams=Decimal("100.00"),
        is_default=True,
    )
    for food, calories, protein, carbs, fat in (
        (rice, "130.0000", "2.7000", "28.0000", "0.3000"),
        (custom, "70.0000", "2.5000", "12.0000", "1.5000"),
    ):
        FoodNutrient.objects.bulk_create(
            [
                FoodNutrient(
                    food=food,
                    nutrient=Nutrient.objects.get(code=code),
                    amount_per_100g=Decimal(amount),
                    source=food.source,
                    confidence_score=Decimal("0.7000"),
                    derivation_method=FoodNutrient.DerivationMethod.ESTIMATED,
                )
                for code, amount in {
                    "calories": calories,
                    "protein_g": protein,
                    "carbs_g": carbs,
                    "fat_g": fat,
                }.items()
            ]
        )

    api_client.force_authenticate(user=user)
    for food in (sample_food, sample_food, rice):
        response = api_client.post(
            reverse("meal-manual-add"),
            {
                "meal_type": "lunch",
                "food_id": str(food.id),
                "quantity_value": "1",
                "quantity_unit": "serving",
            },
            format="json",
        )
        assert response.status_code == 201

    FavoriteFood.objects.create(user=user, food=sample_food)

    recent = api_client.get(reverse("food-recent"))
    assert recent.status_code == 200
    recent_names = [item["name"] for item in recent.json()["results"]]
    assert recent_names[:2] == ["Cooked rice", "Paneer"]

    frequent = api_client.get(reverse("food-frequent"))
    assert frequent.status_code == 200
    assert frequent.json()["results"][0]["name"] == "Paneer"

    favorites = api_client.get(reverse("food-favorites"))
    assert favorites.status_code == 200
    assert favorites.json()["results"][0]["name"] == "Paneer"
    assert favorites.json()["results"][0]["is_favorite"] is True

    my_foods = api_client.get(reverse("food-my-foods"))
    assert my_foods.status_code == 200
    assert my_foods.json()["results"][0]["name"] == "Kunal private oats"


@pytest.mark.django_db
def test_food_favorite_toggle_updates_favorites_list(api_client, user, sample_food):
    api_client.force_authenticate(user=user)

    response = api_client.post(reverse("food-favorite", args=[sample_food.id]))
    assert response.status_code == 200
    assert response.json()["is_favorite"] is True
    assert FavoriteFood.objects.filter(user=user, food=sample_food).exists()

    favorites = api_client.get(reverse("food-favorites"))
    assert favorites.status_code == 200
    assert [item["id"] for item in favorites.json()["results"]] == [str(sample_food.id)]

    response = api_client.delete(reverse("food-favorite", args=[sample_food.id]))
    assert response.status_code == 200
    assert response.json()["is_favorite"] is False
    assert FavoriteFood.objects.filter(user=user, food=sample_food).exists() is False

    favorites = api_client.get(reverse("food-favorites"))
    assert favorites.status_code == 200
    assert favorites.json()["results"] == []


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
    assert Food.objects.filter(source=source).count() >= 360
    assert Food.objects.filter(source=source, verified=True).count() >= 250
    assert Food.objects.filter(source=source).exclude(barcode="").count() >= 20
    assert (
        Food.objects.filter(source=source, servings__isnull=False).distinct().count()
        >= 360
    )

    chicken_curry = Food.objects.get(source=source, canonical_name="Chicken curry")
    assert chicken_curry.servings.get(is_default=True).grams == Decimal("220.00")
    assert chicken_curry.nutrients.filter(nutrient__code="sodium_mg").exists()

    chapati = Food.objects.get(source=source, canonical_name="Chapati, whole wheat")
    assert chapati.aliases.filter(alias="phulka").exists()
    assert chapati.nutrients.filter(nutrient__code="iron_mg").exists()

    assert Food.objects.filter(source=source, aliases__alias="besan chilla").exists()
    assert Food.objects.filter(source=source, aliases__alias="protein shake").exists()
    assert Food.objects.filter(source=source, aliases__alias="bhindi").exists()
    assert Food.objects.filter(source=source, aliases__alias="amrood").exists()
    assert Food.objects.filter(
        source=source, aliases__alias="muscleblaze whey"
    ).exists()
    assert Food.objects.filter(
        source=source, aliases__alias="nimbu pani no sugar"
    ).exists()
    assert Food.objects.filter(source=source, aliases__alias="maggi").exists()
    assert Food.objects.filter(source=source, aliases__alias="coke").exists()
    assert Food.objects.filter(
        source=source,
        food_type=Food.FoodType.BRANDED,
        brand_name="Nestle",
        canonical_name="Maggi 2-Minute Noodles Masala",
    ).exists()
    assert Food.objects.filter(
        source=source,
        food_type=Food.FoodType.RESTAURANT,
        canonical_name="Margherita pizza",
    ).exists()

    api_client.force_authenticate(user=user)
    response = api_client.get(reverse("food-search"), {"q": "chapati"})
    assert response.status_code == 200
    assert response.json()["results"][0]["name"] == "Chapati, whole wheat"
    assert response.json()["results"][0]["data_classification"] == "trusted_seeded"

    response = api_client.get(reverse("food-search"), {"q": "protein shake"})
    assert response.status_code == 200
    names = {result["name"] for result in response.json()["results"]}
    assert "Protein shake with milk" in names

    response = api_client.get(reverse("food-search"), {"q": "chicken breast"})
    assert response.status_code == 200
    assert response.json()["results"][0]["name"] == "Chicken breast, cooked skinless"

    response = api_client.get(reverse("food-search"), {"q": "bhindi"})
    assert response.status_code == 200
    assert response.json()["results"][0]["name"] == "Okra, cooked"

    response = api_client.get(reverse("food-search"), {"q": "amrood"})
    assert response.status_code == 200
    assert response.json()["results"][0]["name"] == "Guava"

    response = api_client.get(reverse("food-search"), {"q": "maggi"})
    assert response.status_code == 200
    assert response.json()["results"][0]["name"] == "Maggi 2-Minute Noodles Masala"

    response = api_client.get(reverse("food-search"), {"q": "coke"})
    assert response.status_code == 200
    assert response.json()["results"][0]["name"] == "Coca-Cola Original Taste"

    response = api_client.get(reverse("food-search"), {"barcode": "8991200000344"})
    assert response.status_code == 200
    assert response.json()["results"][0]["name"] == "MuscleBlaze Whey Protein Chocolate"


@pytest.mark.django_db
def test_popular_food_seed_supports_common_macro_examples():
    call_command("seed_popular_foods")
    source = NutritionDataSource.objects.get(name="Manual Admin Sample")

    def preview(food_name, quantity, unit):
        food = (
            Food.objects.filter(source=source, canonical_name=food_name)
            .prefetch_related("servings", "nutrients__nutrient", "nutrients__source")
            .get()
        )
        return manual_food_preview(
            food=food,
            quantity_value=Decimal(quantity),
            quantity_unit=unit,
        )

    chicken = preview("Chicken breast, cooked skinless", "500", "gram")
    assert chicken["calories_kcal"] == Decimal("825.000")
    assert Decimal(chicken["protein_g"]) == Decimal("155.000")
    assert Decimal(chicken["carbs_g"]) == Decimal("0.000")
    assert Decimal(chicken["fat_g"]) == Decimal("18.000")

    eggs = preview("Boiled egg, whole", "2", "egg")
    assert eggs["effective_total_grams"] == Decimal("100.000")
    assert eggs["calories_kcal"] == Decimal("155.000")
    assert Decimal(eggs["protein_g"]) == Decimal("12.600")
    assert Decimal(eggs["carbs_g"]) == Decimal("1.100")

    rice = preview("Cooked white rice", "200", "gram")
    assert rice["calories_kcal"] == Decimal("260.000")
    assert Decimal(rice["carbs_g"]) == Decimal("56.400")

    chapati = preview("Chapati, whole wheat", "2", "piece")
    assert chapati["effective_total_grams"] == Decimal("80.000")
    assert chapati["calories_kcal"] == Decimal("208.000")
    assert Decimal(chapati["protein_g"]) == Decimal("6.960")
    assert Decimal(chapati["carbs_g"]) == Decimal("37.120")

    whey = preview("Whey protein powder", "1", "scoop")
    assert whey["effective_total_grams"] == Decimal("30.000")
    assert whey["calories_kcal"] == Decimal("120.000")
    assert Decimal(whey["protein_g"]) == Decimal("24.000")


@pytest.mark.django_db
def test_food_search_exact_match_beats_verified_partial_match(api_client, user):
    call_command("seed_popular_foods")
    source = NutritionDataSource.objects.get(name="Manual Admin Sample")
    Food.objects.create(
        canonical_name="Banana protein snack",
        food_type=Food.FoodType.BRANDED,
        source=source,
        external_id="SEARCH-VERIFIED-BANANA-SNACK",
        country_code="IN",
        serving_description="1 bar",
        default_serving_g=Decimal("50.00"),
        data_quality_score=Decimal("0.9900"),
        verified=True,
        brand_name="Search Test",
    )

    api_client.force_authenticate(user=user)
    response = api_client.get(reverse("food-search"), {"q": "banana"})

    assert response.status_code == 200
    assert response.json()["results"][0]["name"] == "Banana"


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
        "foods.services.openfoodfacts.fetch_json",
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
        license_confirmed=True,
    )

    source = NutritionDataSource.objects.get(
        source_type=NutritionDataSource.SourceType.INDB
    )
    food = Food.objects.get(source=source, external_id="IN-SAMPLE-POHA")
    assert food.region == "Maharashtra"
    assert food.servings.get(is_default=True).grams == Decimal("180.00")
    assert food.aliases.filter(alias="kanda poha").exists()
    assert food.nutrients.filter(nutrient__code="calories").exists()
