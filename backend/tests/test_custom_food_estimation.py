from decimal import Decimal

import pytest
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.urls import reverse
from rest_framework.test import APIClient

from foods.models import CustomFoodProfile, Food, FoodNutrient, FoodServing
from meals.models import MealLogItem
from nutrition.models import Nutrient, NutritionDataSource

User = get_user_model()


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def user():
    return User.objects.create_user(
        username="custom-estimate@example.com",
        email="custom-estimate@example.com",
        password="strong-local-passphrase",
    )


@pytest.fixture
def other_user():
    return User.objects.create_user(
        username="custom-estimate-other@example.com",
        email="custom-estimate-other@example.com",
        password="strong-local-passphrase",
    )


@pytest.fixture
def seeded_core():
    call_command("seed_core_nutrition")


def create_reference_food(
    *,
    name,
    source,
    external_id,
    calories,
    protein,
    carbs,
    fat,
    preparation_state=Food.PreparationState.COOKED,
):
    food = Food.objects.create(
        canonical_name=name,
        preparation_state=preparation_state,
        food_type=Food.FoodType.GENERIC,
        source=source,
        external_id=external_id,
        dataset_type=Food.DatasetType.USDA_FOUNDATION,
        default_serving_g=Decimal("100"),
        serving_description="100 g",
        data_quality_score=Decimal("0.9000"),
        completeness_score=Decimal("1.0000"),
        verified=True,
    )
    FoodServing.objects.create(
        food=food,
        serving_name="100 g",
        grams=Decimal("100"),
        is_default=True,
    )
    nutrient_values = {
        "calories": calories,
        "protein_g": protein,
        "carbs_g": carbs,
        "fat_g": fat,
        "fiber_g": Decimal("1"),
        "sugar_g": Decimal("1"),
        "sodium_mg": Decimal("10"),
    }
    FoodNutrient.objects.bulk_create(
        [
            FoodNutrient(
                food=food,
                nutrient=Nutrient.objects.get(code=code),
                amount_per_100g=value,
                source=source,
                confidence_score=Decimal("0.9000"),
                derivation_method=FoodNutrient.DerivationMethod.LAB,
            )
            for code, value in nutrient_values.items()
        ]
    )
    return food


@pytest.fixture
def reference_foods(seeded_core):
    source = NutritionDataSource.objects.get(
        source_type=NutritionDataSource.SourceType.USDA_FDC
    )
    egg = create_reference_food(
        name="Egg, whole, boiled",
        source=source,
        external_id="ESTIMATE-EGG",
        calories=Decimal("155"),
        protein=Decimal("12.6"),
        carbs=Decimal("1.1"),
        fat=Decimal("10.6"),
        preparation_state=Food.PreparationState.BOILED,
    )
    rice = create_reference_food(
        name="Rice, white, cooked",
        source=source,
        external_id="ESTIMATE-RICE",
        calories=Decimal("130"),
        protein=Decimal("2.7"),
        carbs=Decimal("28.2"),
        fat=Decimal("0.3"),
    )
    chicken = create_reference_food(
        name="Chicken breast, cooked",
        source=source,
        external_id="ESTIMATE-CHICKEN",
        calories=Decimal("165"),
        protein=Decimal("31"),
        carbs=Decimal("0"),
        fat=Decimal("3.6"),
    )
    return {"egg": egg, "rice": rice, "chicken": chicken}


def authenticate(api_client, user):
    api_client.force_authenticate(user=user)


@pytest.mark.django_db
def test_custom_food_list_returns_only_current_users_foods(
    api_client, user, other_user, seeded_core
):
    authenticate(api_client, user)
    own = api_client.post(
        reverse("food-custom-create"),
        {
            "name": "My private breakfast",
            "serving_name": "1 bowl",
            "serving_weight_g": "180",
            "calories_kcal": "240",
            "protein_g": "12",
            "carbs_g": "30",
            "fat_g": "8",
        },
        format="json",
    )
    assert own.status_code == 201, own.json()

    authenticate(api_client, other_user)
    other = api_client.post(
        reverse("food-custom-create"),
        {
            "name": "Another user's private food",
            "serving_name": "1 serving",
            "serving_weight_g": "100",
            "calories_kcal": "100",
        },
        format="json",
    )
    assert other.status_code == 201, other.json()

    authenticate(api_client, user)
    response = api_client.get(reverse("food-custom-create"))

    assert response.status_code == 200, response.json()
    results = response.json()["results"]
    assert [item["canonical_name"] for item in results] == [
        "My private breakfast"
    ]


def create_estimated_custom(api_client, estimate):
    response = api_client.post(
        reverse("food-custom-create"),
        {
            "name": "My boiled egg snack",
            "preparation_method": "boiled",
            "serving_name": "1 snack",
            "serving_quantity": "1",
            "serving_unit": "serving",
            "serving_weight_g": "50",
            "estimated_nutrients": estimate["suggested_nutrients"],
            "estimated_range": estimate["estimated_range"],
            "reference_matches": estimate["reference_matches"],
            "confidence": estimate["confidence"],
            "estimation_method": estimate["estimation_method"],
            "warnings": estimate["warnings"],
        },
        format="json",
    )
    assert response.status_code == 201, response.json()
    return response


@pytest.mark.django_db
def test_estimate_exact_match_and_serving_conversion(
    api_client, user, reference_foods
):
    authenticate(api_client, user)
    response = api_client.post(
        reverse("food-custom-estimate"),
        {
            "food_name": "Egg, whole, boiled",
            "preparation_method": "boiled",
            "serving_name": "1 egg",
            "serving_weight_g": "50",
        },
        format="json",
    )

    assert response.status_code == 200, response.json()
    payload = response.json()
    assert payload["requires_review"] is True
    assert payload["can_estimate"] is True
    assert Decimal(payload["suggested_nutrients"]["calories_kcal"]) == Decimal(
        "77.500"
    )
    assert payload["reference_matches"][0]["source_badge"] == "USDA_FDC"
    assert Decimal(payload["confidence"]) >= Decimal("0.85")


@pytest.mark.django_db
def test_estimate_from_fuzzy_match(api_client, user, reference_foods):
    authenticate(api_client, user)
    response = api_client.post(
        reverse("food-custom-estimate"),
        {
            "food_name": "cooked chicken breast portion",
            "preparation_method": "cooked",
            "serving_weight_g": "120",
        },
        format="json",
    )

    assert response.status_code == 200, response.json()
    assert response.json()["can_estimate"] is True
    assert response.json()["reference_matches"][0]["name"] == (
        "Chicken breast, cooked"
    )


@pytest.mark.django_db
def test_recipe_ingredient_estimation(api_client, user, reference_foods):
    authenticate(api_client, user)
    response = api_client.post(
        reverse("food-custom-estimate"),
        {
            "food_name": "Egg rice bowl",
            "serving_name": "1 bowl",
            "serving_weight_g": "150",
            "ingredients": [
                {"food_id": str(reference_foods["egg"].id), "grams": "50"},
                {"food_id": str(reference_foods["rice"].id), "grams": "100"},
            ],
        },
        format="json",
    )

    assert response.status_code == 200, response.json()
    payload = response.json()
    assert payload["estimation_method"] == "ingredient_sum"
    assert Decimal(payload["suggested_nutrients"]["calories_kcal"]) == Decimal(
        "207.500"
    )
    assert len(payload["reference_matches"]) == 2


@pytest.mark.django_db
def test_estimate_review_confirm_and_history(api_client, user, reference_foods):
    authenticate(api_client, user)
    estimate = api_client.post(
        reverse("food-custom-estimate"),
        {
            "food_name": "Egg, whole, boiled",
            "preparation_method": "boiled",
            "serving_weight_g": "50",
        },
        format="json",
    ).json()
    created = create_estimated_custom(api_client, estimate)
    food_id = created.json()["id"]
    assert created.json()["custom_food"]["status"] == "estimate_ready"
    assert created.json()["nutrients"] == []
    premature_log = api_client.post(
        reverse("meal-manual-add"),
        {
            "date": "2026-07-31",
            "meal_type": "snack",
            "food_id": food_id,
            "quantity_value": "1",
            "quantity_unit": "serving",
        },
        format="json",
    )
    assert premature_log.status_code == 400

    edited = api_client.patch(
        reverse("food-custom-detail", args=[food_id]),
        {
            "final_nutrients": {
                "calories_kcal": "82",
                "protein_g": "6.8",
                "carbs_g": "0.6",
                "fat_g": "5.5",
            }
        },
        format="json",
    )
    assert edited.status_code == 200, edited.json()
    assert edited.json()["custom_food"]["status"] == "needs_review"
    assert edited.json()["custom_food"]["estimated_nutrients"] == (
        estimate["suggested_nutrients"]
    )

    confirmed = api_client.post(
        reverse("food-custom-confirm", args=[food_id]), {}, format="json"
    )
    assert confirmed.status_code == 200, confirmed.json()
    assert confirmed.json()["custom_food"]["status"] == "confirmed"
    assert confirmed.json()["custom_food"]["confirmed_nutrients"][
        "calories_kcal"
    ] == "82.000"

    history = api_client.get(reverse("food-custom-history", args=[food_id]))
    assert history.status_code == 200
    assert [entry["event"] for entry in history.json()] == [
        "confirmed",
        "updated",
        "created",
    ]


@pytest.mark.django_db
def test_reestimate_preserves_original_suggestion(api_client, user, reference_foods):
    authenticate(api_client, user)
    estimate = api_client.post(
        reverse("food-custom-estimate"),
        {
            "food_name": "Egg, whole, boiled",
            "preparation_method": "boiled",
            "serving_weight_g": "50",
        },
        format="json",
    ).json()
    food_id = create_estimated_custom(api_client, estimate).json()["id"]

    reestimated = api_client.post(
        reverse("food-custom-re-estimate", args=[food_id]),
        {"reference_food_id": str(reference_foods["rice"].id)},
        format="json",
    )
    assert reestimated.status_code == 200, reestimated.json()
    detail = api_client.get(reverse("food-custom-detail", args=[food_id])).json()
    profile = detail["custom_food"]
    assert profile["original_estimated_nutrients"] == estimate[
        "suggested_nutrients"
    ]
    assert Decimal(profile["estimated_nutrients"]["calories_kcal"]) == Decimal(
        "65.000"
    )


@pytest.mark.django_db
def test_user_can_accept_estimate_explicitly(api_client, user, reference_foods):
    authenticate(api_client, user)
    estimate = api_client.post(
        reverse("food-custom-estimate"),
        {
            "food_name": "Egg, whole, boiled",
            "preparation_method": "boiled",
            "serving_weight_g": "50",
        },
        format="json",
    ).json()
    food_id = create_estimated_custom(api_client, estimate).json()["id"]

    confirmed = api_client.post(
        reverse("food-custom-confirm", args=[food_id]),
        {"use_estimate": True},
        format="json",
    )

    assert confirmed.status_code == 200, confirmed.json()
    assert confirmed.json()["custom_food"]["status"] == "confirmed"
    assert confirmed.json()["nutrients"]


@pytest.mark.django_db
def test_user_can_reset_corrections_to_original_estimate(
    api_client, user, reference_foods
):
    authenticate(api_client, user)
    estimate = api_client.post(
        reverse("food-custom-estimate"),
        {
            "food_name": "Egg, whole, boiled",
            "preparation_method": "boiled",
            "serving_weight_g": "50",
        },
        format="json",
    ).json()
    food_id = create_estimated_custom(api_client, estimate).json()["id"]
    api_client.patch(
        reverse("food-custom-detail", args=[food_id]),
        {"final_nutrients": {"calories_kcal": "99"}},
        format="json",
    )

    reset = api_client.patch(
        reverse("food-custom-detail", args=[food_id]),
        {"reset_to_estimate": True},
        format="json",
    )

    assert reset.status_code == 200, reset.json()
    profile = reset.json()["custom_food"]
    assert profile["status"] == "estimate_ready"
    assert profile["user_corrections"] == {}
    assert profile["effective_review_nutrients"] == estimate["suggested_nutrients"]


@pytest.mark.django_db
def test_custom_food_privacy_and_duplicate_handling(
    api_client, user, other_user, seeded_core
):
    authenticate(api_client, user)
    payload = {
        "name": "Private macro meal",
        "brand": "Home",
        "barcode": "CUSTOM-PRIVATE-001",
        "serving_name": "1 bowl",
        "serving_grams": "100",
        "calories_kcal": "250",
        "protein_g": "20",
        "carbs_g": "25",
        "fat_g": "8",
    }
    created = api_client.post(reverse("food-custom-create"), payload, format="json")
    assert created.status_code == 201, created.json()

    duplicate = api_client.post(reverse("food-custom-create"), payload, format="json")
    assert duplicate.status_code == 400
    duplicate_barcode = api_client.post(
        reverse("food-custom-create"),
        {**payload, "name": "A different private meal"},
        format="json",
    )
    assert duplicate_barcode.status_code == 400

    authenticate(api_client, other_user)
    private_get = api_client.get(
        reverse("food-custom-detail", args=[created.json()["id"]])
    )
    assert private_get.status_code == 404
    other_created = api_client.post(
        reverse("food-custom-create"),
        {**payload, "barcode": "CUSTOM-PRIVATE-OTHER"},
        format="json",
    )
    assert other_created.status_code == 201


@pytest.mark.django_db
def test_large_calorie_difference_warns_but_keeps_user_value(
    api_client, user, seeded_core
):
    authenticate(api_client, user)
    response = api_client.post(
        reverse("food-custom-create"),
        {
            "name": "Unusual label product",
            "serving_name": "1 packet",
            "serving_grams": "100",
            "calories_kcal": "500",
            "protein_g": "2",
            "carbs_g": "5",
            "fat_g": "1",
        },
        format="json",
    )

    assert response.status_code == 201, response.json()
    assert response.json()["custom_food"]["status"] == "confirmed"
    assert response.json()["custom_food"]["warnings"]
    calorie_value = next(
        value
        for value in response.json()["nutrients"]
        if value["nutrient_code"] == "calories"
    )
    assert Decimal(calorie_value["amount_per_100g"]) == Decimal("500")


@pytest.mark.django_db
def test_insufficient_confidence_requires_manual_entry(api_client, user, seeded_core):
    authenticate(api_client, user)
    response = api_client.post(
        reverse("food-custom-estimate"),
        {
            "food_name": "unknown lunar berry foam",
            "serving_weight_g": "100",
        },
        format="json",
    )

    assert response.status_code == 200, response.json()
    assert response.json()["can_estimate"] is False
    assert response.json()["requires_review"] is True
    assert response.json()["suggested_nutrients"] == {}
    assert "Unable to estimate reliably" in response.json()["message"]


@pytest.mark.django_db
def test_historical_meal_snapshot_survives_custom_food_edit(
    api_client, user, seeded_core
):
    authenticate(api_client, user)
    created = api_client.post(
        reverse("food-custom-create"),
        {
            "name": "Versioned snack",
            "serving_name": "1 packet",
            "serving_grams": "100",
            "calories_kcal": "100",
            "protein_g": "10",
            "carbs_g": "10",
            "fat_g": "2",
        },
        format="json",
    )
    food_id = created.json()["id"]
    logged = api_client.post(
        reverse("food-custom-log", args=[food_id]),
        {
            "date": "2026-07-31",
            "meal_type": "snack",
            "quantity_value": "1",
            "quantity_unit": "serving",
        },
        format="json",
    )
    assert logged.status_code == 201, logged.json()
    meal_item_id = logged.json()["item"]["id"]

    api_client.patch(
        reverse("food-custom-detail", args=[food_id]),
        {
            "final_nutrients": {
                "calories_kcal": "220",
                "protein_g": "22",
                "carbs_g": "20",
                "fat_g": "6",
            }
        },
        format="json",
    )
    confirmed = api_client.post(
        reverse("food-custom-confirm", args=[food_id]), {}, format="json"
    )
    assert confirmed.status_code == 200, confirmed.json()

    meal_item = MealLogItem.objects.get(id=meal_item_id)
    assert meal_item.calories_kcal == Decimal("100.000")
    assert meal_item.macros_snapshot["protein_g"] == "10.000"
    assert FoodNutrient.objects.get(
        food_id=food_id, nutrient__code="calories"
    ).amount_per_100g == Decimal("220.0000")
    assert CustomFoodProfile.objects.get(food_id=food_id).version_number == 3
