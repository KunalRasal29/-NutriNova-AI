from decimal import Decimal

import pytest
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.urls import reverse
from rest_framework.test import APIClient

from foods.models import Food, FoodNutrient, FoodServing
from nutrition.models import Nutrient, NutritionDataSource

User = get_user_model()


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def user():
    return User.objects.create_user(
        username="meals@example.com",
        email="meals@example.com",
        password="strong-local-passphrase",
    )


@pytest.fixture
def other_user():
    return User.objects.create_user(
        username="other-meals@example.com",
        email="other-meals@example.com",
        password="strong-local-passphrase",
    )


@pytest.fixture
def seeded_core():
    call_command("seed_core_nutrition")


@pytest.fixture
def paneer_food(seeded_core):
    source = NutritionDataSource.objects.get(
        source_type=NutritionDataSource.SourceType.IFCT_2017
    )
    food = Food.objects.create(
        canonical_name="Paneer",
        description="Indian cottage cheese",
        food_type=Food.FoodType.GENERIC,
        source=source,
        external_id="MEAL-TEST-PANEER",
        country_code="IN",
        language_code="en",
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
    nutrients = {
        "calories": Decimal("265.0000"),
        "protein_g": Decimal("18.3000"),
        "carbs_g": Decimal("1.2000"),
        "fat_g": Decimal("20.8000"),
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
            for code, amount in nutrients.items()
        ]
    )
    return food


def as_decimal(value):
    return Decimal(str(value)).quantize(Decimal("0.001"))


def create_meal(api_client, date="2026-06-29"):
    response = api_client.post(
        reverse("meal-list"),
        {
            "date": date,
            "meal_type": "lunch",
            "name": "Lunch",
            "timezone": "Asia/Kolkata",
        },
        format="json",
    )
    assert response.status_code == 201
    return response.json()


@pytest.mark.django_db
def test_log_meal_item_calculates_snapshot(api_client, user, paneer_food):
    api_client.force_authenticate(user=user)
    meal = create_meal(api_client)

    response = api_client.post(
        reverse("meal-add-item", args=[meal["id"]]),
        {
            "food": str(paneer_food.id),
            "quantity": "1.000",
            "unit": "serving",
            "serving": str(paneer_food.servings.get(is_default=True).id),
            "user_confirmed": True,
        },
        format="json",
    )

    assert response.status_code == 201
    payload = response.json()
    assert as_decimal(payload["grams_calculated"]) == Decimal("100.000")
    assert as_decimal(payload["calories_kcal"]) == Decimal("265.000")
    assert as_decimal(payload["macros_snapshot"]["protein_g"]) == Decimal("18.300")
    assert payload["user_confirmed"] is True


@pytest.mark.django_db
def test_update_quantity_recalculates_nutrition(api_client, user, paneer_food):
    api_client.force_authenticate(user=user)
    meal = create_meal(api_client)
    item_response = api_client.post(
        reverse("meal-add-item", args=[meal["id"]]),
        {
            "food": str(paneer_food.id),
            "quantity": "100.000",
            "unit": "grams",
        },
        format="json",
    )
    assert item_response.status_code == 201

    response = api_client.patch(
        reverse("meal-item-detail", args=[item_response.json()["id"]]),
        {"quantity": "200.000"},
        format="json",
    )

    assert response.status_code == 200
    payload = response.json()
    assert as_decimal(payload["grams_calculated"]) == Decimal("200.000")
    assert as_decimal(payload["calories_kcal"]) == Decimal("530.000")
    assert as_decimal(payload["macros_snapshot"]["fat_g"]) == Decimal("41.600")


@pytest.mark.django_db
def test_daily_summary_is_recomputed_from_meal_items(api_client, user, paneer_food):
    api_client.force_authenticate(user=user)
    meal = create_meal(api_client)
    response = api_client.post(
        reverse("meal-add-item", args=[meal["id"]]),
        {
            "food": str(paneer_food.id),
            "quantity": "150.000",
            "unit": "grams",
        },
        format="json",
    )
    assert response.status_code == 201

    summary = api_client.get(
        reverse("daily-nutrition-summary"),
        {"date": "2026-06-29"},
    )

    assert summary.status_code == 200
    payload = summary.json()
    assert as_decimal(payload["calories_kcal"]) == Decimal("397.500")
    assert as_decimal(payload["protein_g"]) == Decimal("27.450")
    assert "macro_percentage_split" in payload
    assert "daily_target_progress" in payload


@pytest.mark.django_db
def test_recipe_calculation_is_correct(api_client, user, paneer_food):
    api_client.force_authenticate(user=user)
    recipe_response = api_client.post(
        reverse("recipe-list"),
        {
            "name": "Paneer bowl",
            "servings": "2.00",
            "visibility": "private",
            "ingredients": [
                {
                    "food": str(paneer_food.id),
                    "quantity": "200.000",
                    "unit": "grams",
                }
            ],
        },
        format="json",
    )
    assert recipe_response.status_code == 201

    response = api_client.post(
        reverse("recipe-calculate", args=[recipe_response.json()["id"]]),
        {},
        format="json",
    )

    assert response.status_code == 200
    payload = response.json()
    assert as_decimal(payload["total_weight_g"]) == Decimal("200.000")
    assert as_decimal(payload["totals"]["calories"]) == Decimal("530.000")
    assert as_decimal(payload["per_serving"]["protein_g"]) == Decimal("18.300")


@pytest.mark.django_db
def test_users_cannot_see_another_users_meals_or_recipes(
    api_client,
    user,
    other_user,
    paneer_food,
):
    api_client.force_authenticate(user=user)
    meal = create_meal(api_client)
    recipe = api_client.post(
        reverse("recipe-list"),
        {
            "name": "Private paneer",
            "servings": "1.00",
            "ingredients": [
                {
                    "food": str(paneer_food.id),
                    "quantity": "100.000",
                    "unit": "grams",
                }
            ],
        },
        format="json",
    )
    assert recipe.status_code == 201

    api_client.force_authenticate(user=other_user)

    assert api_client.get(reverse("meal-detail", args=[meal["id"]])).status_code == 404
    assert (
        api_client.get(reverse("recipe-detail", args=[recipe.json()["id"]])).status_code
        == 404
    )
    assert (
        api_client.get(reverse("meal-list"), {"date": "2026-06-29"}).json()["results"]
        == []
    )
    assert api_client.get(reverse("recipe-list")).json()["results"] == []
