from decimal import Decimal

import pytest
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import override_settings
from django.urls import reverse
from rest_framework.test import APIClient

from foods.importers import get_data_source, upsert_food_record
from foods.models import Food, FoodAlias, FoodNutrient, UserPortionPreference
from meals.models import MealLogItem
from nutrition.models import Nutrient, NutritionDataSource

User = get_user_model()


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def user():
    return User.objects.create_user(
        username="accuracy@example.com",
        email="accuracy@example.com",
        password="strong-local-passphrase",
    )


@pytest.fixture
def seeded_core():
    call_command("seed_core_nutrition")


def create_food(*, source, name, external_id, calories="100.0000"):
    food = Food.objects.create(
        canonical_name=name,
        source=source,
        external_id=external_id,
        country_code="IN",
        data_quality_score=Decimal("0.9000"),
        verified=True,
        default_serving_g=Decimal("40.00"),
    )
    FoodNutrient.objects.create(
        food=food,
        nutrient=Nutrient.objects.get(code="calories"),
        amount_per_100g=Decimal(calories),
        source=source,
        confidence_score=Decimal("0.9000"),
        derivation_method=FoodNutrient.DerivationMethod.LAB,
    )
    return food


@pytest.mark.django_db
def test_alias_and_typo_search_ranks_chapati_first(
    api_client,
    user,
    seeded_core,
):
    source = get_data_source(NutritionDataSource.SourceType.IFCT_2017)
    chapati = create_food(
        source=source,
        name="Chapati",
        external_id="ACCURACY-CHAPATI",
    )
    FoodAlias.objects.create(food=chapati, alias="roti", language_code="en")
    create_food(
        source=source,
        name="Sweet corn chaat",
        external_id="ACCURACY-CHAAT",
    )
    api_client.force_authenticate(user=user)

    response = api_client.get(reverse("food-search"), {"q": "chappati"})

    assert response.status_code == 200
    assert response.json()["results"][0]["id"] == str(chapati.id)


@pytest.mark.django_db
def test_raw_and_cooked_foods_have_distinct_preparation_states(
    api_client,
    user,
    seeded_core,
):
    source = get_data_source(NutritionDataSource.SourceType.USDA_FDC)
    raw, _ = upsert_food_record(
        source=source,
        canonical_name="Rice, raw",
        external_id="ACCURACY-RICE-RAW",
    )
    cooked, _ = upsert_food_record(
        source=source,
        canonical_name="Rice, cooked",
        external_id="ACCURACY-RICE-COOKED",
    )
    api_client.force_authenticate(user=user)

    response = api_client.get(reverse("food-search"), {"q": "rice"})

    assert response.status_code == 200
    states = {
        item["id"]: item["preparation_state"] for item in response.json()["results"]
    }
    assert states[str(raw.id)] == Food.PreparationState.RAW
    assert states[str(cooked.id)] == Food.PreparationState.COOKED


@pytest.mark.django_db
def test_personalized_targets_preview_edit_and_confirm(
    api_client,
    user,
):
    profile = user.profile
    profile.height_cm = Decimal("175.00")
    profile.weight_kg = Decimal("73.00")
    profile.target_weight_kg = Decimal("70.00")
    profile.activity_level = profile.ActivityLevel.MODERATE
    profile.goal_type = profile.GoalType.IMPROVE_HEALTH
    profile.save()
    api_client.force_authenticate(user=user)

    preview = api_client.get(reverse("nutrition-target-estimate"))

    assert preview.status_code == 200
    assert Decimal(preview.json()["targets"]["calories_kcal"]) != Decimal("2000")
    assert preview.json()["requires_confirmation"] is True
    profile.refresh_from_db()
    assert profile.daily_calorie_target_kcal is None

    applied = api_client.post(
        reverse("nutrition-target-estimate"),
        {"confirm": True},
        format="json",
    )
    assert applied.status_code == 200
    profile.refresh_from_db()
    assert profile.daily_calorie_target_kcal is not None

    edited = api_client.patch(
        reverse("nutrition-targets"),
        {
            "calories_kcal": "2300.0",
            "protein_g": "125.0",
            "carbs_g": "280.0",
            "fat_g": "75.0",
            "fiber_g": "32.0",
            "water_ml": "2700.0",
        },
        format="json",
    )
    assert edited.status_code == 200
    assert edited.json()["customized"] is True
    assert edited.json()["targets"]["protein_g"] == "125.0"


@pytest.mark.django_db
def test_personal_portion_preference_is_reused_only_for_owner(
    api_client,
    user,
    seeded_core,
):
    source = get_data_source(NutritionDataSource.SourceType.IFCT_2017)
    chapati = create_food(
        source=source,
        name="Chapati",
        external_id="ACCURACY-PORTION-CHAPATI",
        calories="250.0000",
    )
    api_client.force_authenticate(user=user)

    learned = api_client.post(
        reverse("meal-manual-add"),
        {
            "date": "2026-07-29",
            "meal_type": "lunch",
            "food_id": str(chapati.id),
            "quantity_value": "2",
            "quantity_unit": "piece",
            "total_grams": "90",
        },
        format="json",
    )
    assert learned.status_code == 201
    preference = UserPortionPreference.objects.get(user=user, food=chapati)
    assert preference.grams_per_unit == Decimal("45.000")

    reused = api_client.post(
        reverse("meal-manual-add"),
        {
            "date": "2026-07-30",
            "meal_type": "lunch",
            "food_id": str(chapati.id),
            "quantity_value": "1",
            "quantity_unit": "piece",
        },
        format="json",
    )
    assert reused.status_code == 201
    item = MealLogItem.objects.filter(user=user, food=chapati).latest("created_at")
    assert item.grams_calculated == Decimal("45.000")

    other_user = User.objects.create_user(
        username="other-accuracy@example.com",
        email="other-accuracy@example.com",
        password="strong-local-passphrase",
    )
    api_client.force_authenticate(user=other_user)
    other_response = api_client.post(
        reverse("meal-manual-add"),
        {
            "date": "2026-07-30",
            "meal_type": "lunch",
            "food_id": str(chapati.id),
            "quantity_value": "1",
            "quantity_unit": "piece",
        },
        format="json",
    )
    assert other_response.status_code == 201
    other_item = MealLogItem.objects.get(user=other_user, food=chapati)
    assert other_item.grams_calculated == Decimal("40.000")


@pytest.mark.django_db
@override_settings(
    OPENFOODFACTS_LIVE_LOOKUP=True,
    OPENFOODFACTS_USER_AGENT="NutriNovaAI/0.1 test@example.com",
)
def test_barcode_live_lookup_handles_missing_product_fields(
    api_client,
    user,
    seeded_core,
    monkeypatch,
):
    monkeypatch.setattr(
        "foods.services.openfoodfacts.fetch_json",
        lambda *args, **kwargs: {
            "product": {
                "code": "8909999999991",
                "product_name": "Minimal test product",
            }
        },
    )
    api_client.force_authenticate(user=user)

    response = api_client.get(
        reverse("food-barcode-lookup"),
        {"barcode": "8909999999991"},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["live_lookup_attempted"] is True
    assert payload["results"][0]["name"] == "Minimal test product"
    assert payload["results"][0]["ingredients_text"] == ""
    assert payload["results"][0]["allergens"] == []
    assert Decimal(str(payload["results"][0]["confidence_score"])) == Decimal("0.45")
