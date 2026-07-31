from decimal import Decimal
from io import BytesIO

import pytest
from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.test import override_settings
from django.urls import reverse
from PIL import Image
from rest_framework.test import APIClient

from foods.models import Food, FoodNutrient, FoodServing
from meals.models import DailyNutritionSummary, MealLogItem
from nutrition.models import Nutrient, NutritionDataSource
from photos.models import PhotoAnalysis

User = get_user_model()

LOCAL_FILE_STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {
        "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
    },
}


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def user():
    return User.objects.create_user(
        username="manual@example.com",
        email="manual@example.com",
        password="strong-local-passphrase",
    )


@pytest.fixture
def other_user():
    return User.objects.create_user(
        username="other-manual@example.com",
        email="other-manual@example.com",
        password="strong-local-passphrase",
    )


@pytest.fixture
def seeded_core():
    call_command("seed_core_nutrition")


def create_food(
    *,
    source,
    name,
    external_id,
    serving_name="100 g",
    serving_grams=Decimal("100.00"),
    default_serving_g=None,
    nutrients=None,
):
    food = Food.objects.create(
        canonical_name=name,
        description=name,
        food_type=Food.FoodType.GENERIC,
        source=source,
        external_id=external_id,
        country_code="IN",
        language_code="en",
        serving_description=serving_name,
        default_serving_g=default_serving_g or serving_grams,
        data_quality_score=Decimal("0.9000"),
        verified=True,
    )
    FoodServing.objects.create(
        food=food,
        serving_name=serving_name,
        grams=serving_grams,
        is_default=True,
    )
    values = nutrients or {
        "calories": Decimal("155.0000"),
        "protein_g": Decimal("12.6000"),
        "carbs_g": Decimal("1.1000"),
        "fat_g": Decimal("10.6000"),
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
            for code, amount in values.items()
        ]
    )
    return food


@pytest.fixture
def egg_food(seeded_core):
    source = NutritionDataSource.objects.get(
        source_type=NutritionDataSource.SourceType.IFCT_2017
    )
    return create_food(
        source=source,
        name="Egg, whole, boiled",
        external_id="MANUAL-EGG",
        serving_name="1 egg",
        serving_grams=Decimal("50.00"),
        default_serving_g=Decimal("50.00"),
    )


@pytest.fixture
def dal_food(seeded_core):
    source = NutritionDataSource.objects.get(
        source_type=NutritionDataSource.SourceType.IFCT_2017
    )
    return create_food(
        source=source,
        name="Dal",
        external_id="MANUAL-DAL",
        serving_name="1 bowl",
        serving_grams=Decimal("180.00"),
        nutrients={
            "calories": Decimal("116.0000"),
            "protein_g": Decimal("7.2000"),
            "carbs_g": Decimal("18.0000"),
            "fat_g": Decimal("2.0000"),
        },
    )


def uploaded_png(name="meal.png"):
    image = Image.new("RGB", (4, 4), color=(240, 240, 240))
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    return SimpleUploadedFile(
        name,
        buffer.getvalue(),
        content_type="image/png",
    )


def as_decimal(value):
    return Decimal(str(value)).quantize(Decimal("0.001"))


@pytest.mark.django_db
def test_manual_food_add_to_meal(api_client, user, egg_food):
    api_client.force_authenticate(user=user)

    response = api_client.post(
        reverse("meal-manual-add"),
        {
            "date": "2026-06-29",
            "meal_type": "breakfast",
            "food_id": str(egg_food.id),
            "quantity_value": "2.000",
            "quantity_unit": "egg",
        },
        format="json",
    )

    assert response.status_code == 201, response.json()
    payload = response.json()
    assert payload["meal"]["meal_type"] == "breakfast"
    assert as_decimal(payload["item"]["grams_calculated"]) == Decimal("100.000")
    assert as_decimal(payload["item"]["calories_kcal"]) == Decimal("155.000")
    assert MealLogItem.objects.get(user=user).food == egg_food


@pytest.mark.django_db
def test_meal_item_patch_recalculates_and_refreshes_summary(api_client, user, egg_food):
    api_client.force_authenticate(user=user)
    created = api_client.post(
        reverse("meal-manual-add"),
        {
            "date": "2026-06-29",
            "meal_type": "breakfast",
            "food_id": str(egg_food.id),
            "quantity_value": "2.000",
            "quantity_unit": "egg",
        },
        format="json",
    )
    item_id = created.json()["item"]["id"]

    response = api_client.patch(
        reverse("meal-item-detail", args=[item_id]),
        {
            "food": str(egg_food.id),
            "quantity": "3.000",
            "unit": "serving",
        },
        format="json",
    )

    assert response.status_code == 200, response.json()
    payload = response.json()
    assert as_decimal(payload["quantity"]) == Decimal("3.000")
    assert as_decimal(payload["grams_calculated"]) == Decimal("150.000")
    assert as_decimal(payload["calories_kcal"]) == Decimal("232.500")

    summary = DailyNutritionSummary.objects.get(user=user, date="2026-06-29")
    assert summary.calories_kcal == Decimal("232.500")


@pytest.mark.django_db
def test_meal_item_delete_removes_item_and_refreshes_summary(
    api_client, user, egg_food
):
    api_client.force_authenticate(user=user)
    created = api_client.post(
        reverse("meal-manual-add"),
        {
            "date": "2026-06-29",
            "meal_type": "breakfast",
            "food_id": str(egg_food.id),
            "quantity_value": "2.000",
            "quantity_unit": "egg",
        },
        format="json",
    )
    item_id = created.json()["item"]["id"]

    response = api_client.delete(reverse("meal-item-detail", args=[item_id]))

    assert response.status_code == 204
    assert not MealLogItem.objects.filter(id=item_id).exists()
    summary = DailyNutritionSummary.objects.get(user=user, date="2026-06-29")
    assert summary.calories_kcal == Decimal("0.000")


@pytest.mark.django_db
@override_settings(STORAGES=LOCAL_FILE_STORAGES)
def test_manual_food_add_from_photo_review(api_client, user, egg_food, tmp_path):
    with override_settings(MEDIA_ROOT=tmp_path):
        analysis = PhotoAnalysis.objects.create(
            user=user,
            image=uploaded_png("manual-photo.png"),
            status=PhotoAnalysis.Status.NEEDS_REVIEW,
            analysis_type=PhotoAnalysis.AnalysisType.MEAL_PHOTO,
        )
    api_client.force_authenticate(user=user)

    response = api_client.post(
        reverse("photo-add-manual-food", args=[analysis.id]),
        {
            "food_id": str(egg_food.id),
            "quantity_value": "2.000",
            "quantity_unit": "egg",
        },
        format="json",
    )

    assert response.status_code == 201, response.json()
    manual_item = [
        item for item in response.json()["items"] if item["added_manually"] is True
    ][0]
    assert as_decimal(manual_item["effective_total_grams"]) == Decimal("100.000")
    assert as_decimal(manual_item["calories_kcal"]) == Decimal("155.000")


@pytest.mark.django_db
def test_flat_custom_food_creation_and_search_badge(api_client, user, seeded_core):
    api_client.force_authenticate(user=user)

    response = api_client.post(
        reverse("food-custom-create"),
        {
            "name": "My protein laddoo",
            "brand": "Home",
            "serving_name": "1 piece",
            "serving_grams": "50.00",
            "calories_kcal": "200.0000",
            "protein_g": "10.0000",
            "carbs_g": "20.0000",
            "fat_g": "8.0000",
            "fiber_g": "2.0000",
            "sugar_g": "6.0000",
            "sodium_mg": "80.0000",
            "notes": "Family recipe.",
        },
        format="json",
    )

    assert response.status_code == 201, response.json()
    payload = response.json()
    assert payload["canonical_name"] == "My protein laddoo"
    assert payload["brand_name"] == "Home"
    assert payload["source"]["source_type"] == "USER_CUSTOM"
    assert payload["created_by"] == str(user.id)
    calories = next(
        nutrient
        for nutrient in payload["nutrients"]
        if nutrient["nutrient_code"] == "calories"
    )
    assert as_decimal(calories["amount_per_100g"]) == Decimal("400.000")

    search = api_client.get(reverse("food-search"), {"q": "laddoo"})
    assert search.status_code == 200
    result = search.json()["results"][0]
    assert result["source_type"] == "USER_CUSTOM"
    assert result["source_badge"] == "USER_CUSTOM"


@pytest.mark.django_db
def test_custom_food_privacy(api_client, user, other_user, seeded_core):
    api_client.force_authenticate(user=user)
    create_response = api_client.post(
        reverse("food-custom-create"),
        {
            "name": "Private oats mix",
            "serving_name": "1 bowl",
            "serving_grams": "100.00",
            "calories_kcal": "150.0000",
            "protein_g": "8.0000",
            "carbs_g": "20.0000",
            "fat_g": "4.0000",
        },
        format="json",
    )
    assert create_response.status_code == 201
    food_id = create_response.json()["id"]

    api_client.force_authenticate(user=other_user)

    assert api_client.get(reverse("food-detail", args=[food_id])).status_code == 404
    search = api_client.get(reverse("food-search"), {"q": "private oats"})
    assert search.status_code == 200
    assert search.json()["results"] == []
    manual_add = api_client.post(
        reverse("meal-manual-add"),
        {
            "date": "2026-06-29",
            "meal_type": "snack",
            "food_id": food_id,
            "quantity_value": "1.000",
            "quantity_unit": "serving",
        },
        format="json",
    )
    assert manual_add.status_code == 400


@pytest.mark.django_db
def test_quick_text_add_parse(api_client, user, egg_food):
    api_client.force_authenticate(user=user)

    response = api_client.post(
        reverse("meal-quick-add-text"),
        {
            "text": "2 eggs",
            "date": "2026-06-29",
            "meal_type": "breakfast",
        },
        format="json",
    )

    assert response.status_code == 200, response.json()
    payload = response.json()
    assert payload["requires_review"] is False
    item = payload["parsed_items"][0]
    assert item["food_id"] == str(egg_food.id)
    assert item["quantity_unit"] == "egg"
    assert as_decimal(item["effective_total_grams"]) == Decimal("100.000")
    assert as_decimal(payload["preview"]["calories_kcal"]) == Decimal("155.000")


@pytest.mark.django_db
def test_quick_text_add_confirmation(api_client, user, egg_food):
    api_client.force_authenticate(user=user)

    response = api_client.post(
        reverse("meal-quick-add-text-confirm"),
        {
            "text": "2 eggs",
            "date": "2026-06-29",
            "meal_type": "breakfast",
        },
        format="json",
    )

    assert response.status_code == 201, response.json()
    payload = response.json()
    assert payload["meal"]["meal_type"] == "breakfast"
    assert as_decimal(payload["items"][0]["grams_calculated"]) == Decimal("100.000")
    assert as_decimal(payload["items"][0]["calories_kcal"]) == Decimal("155.000")


@pytest.mark.django_db
def test_quick_text_add_reviewed_item_confirmation(api_client, user, egg_food):
    api_client.force_authenticate(user=user)

    response = api_client.post(
        reverse("meal-quick-add-text-confirm"),
        {
            "text": "2 eggs",
            "date": "2026-06-29",
            "meal_type": "breakfast",
            "items": [
                {
                    "raw_text": "2 eggs",
                    "food_id": str(egg_food.id),
                    "quantity_value": "2.000",
                    "quantity_unit": "egg",
                    "effective_total_grams": "100.000",
                }
            ],
        },
        format="json",
    )

    assert response.status_code == 201, response.json()
    item = response.json()["items"][0]
    assert item["food_name"] == "Egg, whole, boiled"
    assert as_decimal(item["grams_calculated"]) == Decimal("100.000")


@pytest.mark.django_db
def test_quick_text_add_supports_whey_scoop_example(api_client, user):
    call_command("seed_popular_foods")
    api_client.force_authenticate(user=user)

    parse_response = api_client.post(
        reverse("meal-quick-add-text"),
        {
            "text": "1 scoop whey protein",
            "date": "2026-06-29",
            "meal_type": "snack",
        },
        format="json",
    )

    assert parse_response.status_code == 200, parse_response.json()
    parsed_item = parse_response.json()["parsed_items"][0]
    assert parsed_item["food_name"] == "Whey protein powder"
    assert parsed_item["quantity_unit"] == "scoop"
    assert as_decimal(parsed_item["effective_total_grams"]) == Decimal("30.000")

    confirm_response = api_client.post(
        reverse("meal-quick-add-text-confirm"),
        {
            "text": "1 scoop whey protein",
            "date": "2026-06-29",
            "meal_type": "snack",
            "items": [parsed_item],
        },
        format="json",
    )

    assert confirm_response.status_code == 201, confirm_response.json()
    payload = confirm_response.json()
    assert payload["meal"]["meal_type"] == "snack"
    assert payload["items"][0]["food_name"] == "Whey protein powder"
    assert as_decimal(payload["items"][0]["grams_calculated"]) == Decimal("30.000")
    assert as_decimal(payload["items"][0]["calories_kcal"]) == Decimal("120.000")


@pytest.mark.django_db
def test_quick_text_add_uncertain_input_requires_review(api_client, user, dal_food):
    api_client.force_authenticate(user=user)

    response = api_client.post(
        reverse("meal-quick-add-text"),
        {
            "text": "1 mystery bowl",
            "date": "2026-06-29",
            "meal_type": "lunch",
        },
        format="json",
    )

    assert response.status_code == 200, response.json()
    assert response.json()["requires_review"] is True
    assert "food match needs review" in response.json()["parsed_items"][0]["warnings"]


@pytest.mark.django_db
def test_nutrition_snapshot_is_saved_for_custom_food(api_client, user, seeded_core):
    api_client.force_authenticate(user=user)
    create_response = api_client.post(
        reverse("food-custom-create"),
        {
            "name": "Snapshot shake",
            "serving_name": "1 scoop",
            "serving_grams": "50.00",
            "calories_kcal": "200.0000",
            "protein_g": "25.0000",
            "carbs_g": "10.0000",
            "fat_g": "4.0000",
        },
        format="json",
    )
    food = Food.objects.get(id=create_response.json()["id"])

    log_response = api_client.post(
        reverse("meal-manual-add"),
        {
            "date": "2026-06-29",
            "meal_type": "snack",
            "food_id": str(food.id),
            "quantity_value": "1.000",
            "quantity_unit": "serving",
        },
        format="json",
    )
    assert log_response.status_code == 201, log_response.json()
    item = MealLogItem.objects.get(user=user, food=food)
    assert item.calories_kcal == Decimal("200.000")

    nutrient = food.nutrients.get(nutrient__code="calories")
    nutrient.amount_per_100g = Decimal("1000.0000")
    nutrient.save(update_fields=["amount_per_100g", "updated_at"])

    item.refresh_from_db()
    assert item.calories_kcal == Decimal("200.000")
    assert item.nutrients_snapshot["calories"] == "200.000"
