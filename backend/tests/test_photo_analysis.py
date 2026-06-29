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
from meals.models import MealLog, MealLogItem
from nutrition.models import Nutrient, NutritionDataSource
from photos.models import PhotoAnalysis, PhotoDetectedFood

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
        username="photos@example.com",
        email="photos@example.com",
        password="strong-local-passphrase",
    )


@pytest.fixture
def other_user():
    return User.objects.create_user(
        username="other-photos@example.com",
        email="other-photos@example.com",
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
        external_id="PHOTO-TEST-PANEER",
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


@pytest.fixture
def egg_food(seeded_core):
    source = NutritionDataSource.objects.get(
        source_type=NutritionDataSource.SourceType.IFCT_2017
    )
    food = Food.objects.create(
        canonical_name="Egg, whole, boiled",
        description="Boiled whole egg",
        food_type=Food.FoodType.GENERIC,
        source=source,
        external_id="PHOTO-TEST-EGG",
        country_code="IN",
        language_code="en",
        serving_description="1 egg",
        default_serving_g=Decimal("50.00"),
        data_quality_score=Decimal("0.9500"),
        verified=True,
    )
    FoodServing.objects.create(
        food=food,
        serving_name="1 egg",
        grams=Decimal("50.00"),
        is_default=True,
    )
    nutrients = {
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
                confidence_score=Decimal("0.9500"),
                derivation_method=FoodNutrient.DerivationMethod.LAB,
            )
            for code, amount in nutrients.items()
        ]
    )
    return food


@pytest.fixture
def curry_food(seeded_core):
    source = NutritionDataSource.objects.get(
        source_type=NutritionDataSource.SourceType.IFCT_2017
    )
    food = Food.objects.create(
        canonical_name="Mixed curry",
        description="Generic curry without a known serving",
        food_type=Food.FoodType.GENERIC,
        source=source,
        external_id="PHOTO-TEST-CURRY",
        country_code="IN",
        language_code="en",
        data_quality_score=Decimal("0.7000"),
        verified=False,
    )
    FoodNutrient.objects.create(
        food=food,
        nutrient=Nutrient.objects.get(code="calories"),
        amount_per_100g=Decimal("120.0000"),
        source=source,
        confidence_score=Decimal("0.7000"),
        derivation_method=FoodNutrient.DerivationMethod.ESTIMATED,
    )
    return food


def uploaded_png(name="meal.png"):
    image = Image.new("RGB", (4, 4), color=(240, 240, 240))
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    return SimpleUploadedFile(
        name,
        buffer.getvalue(),
        content_type="image/png",
    )


def upload_meal_photo(api_client, file_name="meal.png"):
    return api_client.post(
        reverse("photo-analyze-meal"),
        {"image": uploaded_png(file_name)},
        format="multipart",
    )


def upload_label_photo(api_client, file_name="label.png"):
    return api_client.post(
        reverse("photo-analyze-label"),
        {"image": uploaded_png(file_name)},
        format="multipart",
    )


def upload_egg_photo(api_client):
    return upload_meal_photo(api_client, "eggs.png")


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_upload_creates_photo_analysis(api_client, user, paneer_food, tmp_path):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)

        response = upload_meal_photo(api_client)

    assert response.status_code == 201
    payload = response.json()
    assert payload["analysis_type"] == "meal_photo"
    assert payload["status"] == "needs_review"
    assert payload["disclaimer"].startswith("Photo nutrition is an estimate")
    assert PhotoAnalysis.objects.filter(id=payload["id"], user=user).exists()


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
    IMAGE_UPLOAD_MAX_BYTES=10,
)
def test_photo_upload_rejects_oversized_image(api_client, user, paneer_food, tmp_path):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)

        response = upload_meal_photo(api_client)

    assert response.status_code == 400
    assert PhotoAnalysis.objects.count() == 0


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
    IMAGE_UPLOAD_ALLOWED_TYPES=["image/jpeg"],
)
def test_photo_upload_rejects_disallowed_content_type(
    api_client,
    user,
    paneer_food,
    tmp_path,
):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)

        response = upload_meal_photo(api_client)

    assert response.status_code == 400
    assert PhotoAnalysis.objects.count() == 0


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_mock_provider_produces_detected_foods(api_client, user, paneer_food, tmp_path):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)

        response = upload_meal_photo(api_client)

    assert response.status_code == 201
    payload = response.json()
    assert payload["ai_provider"] == "local_model"
    assert payload["detected_foods"][0]["detected_name"] == "Paneer"
    assert payload["detected_foods"][0]["matched_food"] == str(paneer_food.id)
    assert Decimal(payload["confidence_score"]) == Decimal("0.8600")


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_match_foods_endpoint_matches_catalog_food(
    api_client,
    user,
    paneer_food,
    tmp_path,
):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)
        upload_response = upload_meal_photo(api_client)

    analysis = PhotoAnalysis.objects.get(id=upload_response.json()["id"])
    PhotoDetectedFood.objects.filter(photo_analysis=analysis).update(matched_food=None)

    response = api_client.post(
        reverse("photo-match-foods", args=[analysis.id]),
        {},
        format="json",
    )

    assert response.status_code == 200
    detected = response.json()["analysis"]["detected_foods"][0]
    assert detected["matched_food"] == str(paneer_food.id)


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_confirm_creates_meal(api_client, user, paneer_food, tmp_path):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)
        upload_response = upload_meal_photo(api_client)

    analysis_id = upload_response.json()["id"]
    detected_id = upload_response.json()["detected_foods"][0]["id"]

    response = api_client.post(
        reverse("photo-confirm-as-meal", args=[analysis_id]),
        {
            "date": "2026-06-29",
            "meal_type": "lunch",
            "name": "Photo lunch",
            "items": [
                {
                    "detected_food": detected_id,
                    "matched_food": str(paneer_food.id),
                    "user_confirmed": True,
                    "user_corrected_grams": "120.000",
                }
            ],
        },
        format="json",
    )

    assert response.status_code == 201, response.json()
    assert MealLog.objects.filter(user=user, name="Photo lunch").exists()
    item = MealLogItem.objects.get(user=user)
    assert item.food == paneer_food
    assert item.grams_calculated == Decimal("120.000")
    assert item.calories_kcal == Decimal("318.000")
    assert PhotoAnalysis.objects.get(id=analysis_id).status == "confirmed"


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_low_confidence_requires_review(api_client, user, paneer_food, tmp_path):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)

        response = upload_meal_photo(api_client, "low-confidence-meal.png")

    assert response.status_code == 201
    payload = response.json()
    assert payload["status"] == "needs_review"
    assert Decimal(payload["confidence_score"]) == Decimal("0.5200")
    assert "low_overall_confidence" in payload["review_reasons"]


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_one_user_cannot_access_another_users_photo_analyses(
    api_client,
    user,
    other_user,
    paneer_food,
    tmp_path,
):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)
        upload_response = upload_meal_photo(api_client)

    api_client.force_authenticate(user=other_user)

    response = api_client.get(
        reverse("photo-analysis-detail", args=[upload_response.json()["id"]])
    )

    assert response.status_code == 404


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_label_scan_creates_pending_review_payload(
    api_client,
    user,
    seeded_core,
    tmp_path,
):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)

        response = upload_label_photo(api_client)

    assert response.status_code == 201
    payload = response.json()
    assert payload["analysis_type"] == "nutrition_label"
    assert payload["status"] == "needs_review"
    assert payload["nutrition_label_scan"]["product_name"] == "Mock Protein Bar"
    assert payload["nutrition_label_scan"]["parsed_nutrients"]["protein_g"] == "20.0000"
    assert payload["detected_foods"] == []
    assert payload["disclaimer"].startswith("Photo nutrition is an estimate")


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_confirm_label_scan_creates_food_with_nutrients(
    api_client,
    user,
    seeded_core,
    tmp_path,
):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)
        upload_response = upload_label_photo(api_client)

    analysis_id = upload_response.json()["id"]
    response = api_client.post(
        reverse("photo-confirm-label-as-food", args=[analysis_id]),
        {},
        format="json",
    )

    assert response.status_code == 201, response.json()
    payload = response.json()
    assert payload["food"]["canonical_name"] == "Mock Protein Bar"
    assert payload["food"]["barcode"] == "8900000000999"
    assert payload["food"]["food_type"] == "branded"
    assert payload["food"]["source"]["source_type"] == "OPEN_FOOD_FACTS"

    food = Food.objects.get(id=payload["food"]["id"])
    assert food.created_by == user
    assert food.servings.get(is_default=True).grams == Decimal("50.00")
    assert food.nutrients.get(nutrient__code="protein_g").amount_per_100g == Decimal(
        "40.0000"
    )
    assert PhotoAnalysis.objects.get(id=analysis_id).status == "confirmed"


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_egg_quantity_increment_updates_grams_and_preview(
    api_client,
    user,
    egg_food,
    tmp_path,
):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)
        upload_response = upload_egg_photo(api_client)

    detected = upload_response.json()["detected_foods"][0]
    assert detected["quantity_value"] == "5.000"
    assert detected["quantity_unit"] == "egg"

    response = api_client.post(
        reverse("photo-detected-food-increment", args=[detected["id"]]),
        {},
        format="json",
    )

    assert response.status_code == 200, response.json()
    payload = response.json()
    assert Decimal(str(payload["effective_quantity_value"])) == Decimal("6.000")
    assert Decimal(str(payload["effective_total_grams"])) == Decimal("300.000")
    assert Decimal(str(payload["calories_kcal"])) == Decimal("465.000")
    assert Decimal(str(payload["protein_g"])) == Decimal("37.800")


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_decrement_quantity_updates_preview(api_client, user, egg_food, tmp_path):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)
        upload_response = upload_egg_photo(api_client)

    detected_id = upload_response.json()["detected_foods"][0]["id"]
    response = api_client.post(
        reverse("photo-detected-food-decrement", args=[detected_id]),
        {},
        format="json",
    )

    assert response.status_code == 200, response.json()
    payload = response.json()
    assert Decimal(str(payload["effective_quantity_value"])) == Decimal("4.000")
    assert Decimal(str(payload["effective_total_grams"])) == Decimal("200.000")
    assert Decimal(str(payload["calories_kcal"])) == Decimal("310.000")


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_user_removes_detected_food_without_deleting_it(
    api_client,
    user,
    egg_food,
    tmp_path,
):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)
        upload_response = upload_egg_photo(api_client)

    detected_id = upload_response.json()["detected_foods"][0]["id"]
    response = api_client.patch(
        reverse("photo-detected-food-detail", args=[detected_id]),
        {"is_removed": True, "correction_note": "Not actually food."},
        format="json",
    )

    assert response.status_code == 200, response.json()
    assert response.json()["is_removed"] is True
    detected = PhotoDetectedFood.objects.get(id=detected_id)
    assert detected.is_removed is True
    assert detected.correction_note == "Not actually food."


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_user_adds_missing_manual_food(
    api_client,
    user,
    paneer_food,
    egg_food,
    tmp_path,
):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)
        upload_response = upload_egg_photo(api_client)

    response = api_client.post(
        reverse("photo-add-manual-food", args=[upload_response.json()["id"]]),
        {
            "food_id": str(paneer_food.id),
            "quantity_value": "120.000",
            "quantity_unit": "gram",
            "total_grams": "120.000",
        },
        format="json",
    )

    assert response.status_code == 201, response.json()
    manual_items = [
        item for item in response.json()["items"] if item["added_manually"] is True
    ]
    assert len(manual_items) == 1
    assert manual_items[0]["matched_food_name"] == "Paneer"
    assert Decimal(str(manual_items[0]["effective_total_grams"])) == Decimal("120.000")


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_recalculate_preview_after_quantity_correction(
    api_client,
    user,
    egg_food,
    tmp_path,
):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)
        upload_response = upload_egg_photo(api_client)

    detected_id = upload_response.json()["detected_foods"][0]["id"]
    api_client.patch(
        reverse("photo-detected-food-detail", args=[detected_id]),
        {"user_quantity_value": "6.000", "user_quantity_unit": "egg"},
        format="json",
    )
    response = api_client.post(
        reverse("photo-recalculate-preview", args=[upload_response.json()["id"]]),
        {},
        format="json",
    )

    assert response.status_code == 200, response.json()
    total = response.json()["total_preview"]
    assert Decimal(str(total["calories_kcal"])) == Decimal("465.000")
    assert Decimal(str(total["protein_g"])) == Decimal("37.800")


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_confirm_as_meal_uses_corrected_quantity(api_client, user, egg_food, tmp_path):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)
        upload_response = upload_egg_photo(api_client)

    detected_id = upload_response.json()["detected_foods"][0]["id"]
    api_client.post(
        reverse("photo-detected-food-increment", args=[detected_id]),
        {},
        format="json",
    )
    response = api_client.post(
        reverse("photo-confirm-as-meal", args=[upload_response.json()["id"]]),
        {
            "date": "2026-06-29",
            "meal_type": "breakfast",
            "name": "Egg breakfast",
        },
        format="json",
    )

    assert response.status_code == 201, response.json()
    item = MealLogItem.objects.get(user=user)
    assert item.food == egg_food
    assert item.quantity == Decimal("6.000")
    assert item.grams_calculated == Decimal("300.000")
    assert item.calories_kcal == Decimal("465.000")


@pytest.mark.django_db
@override_settings(STORAGES=LOCAL_FILE_STORAGES)
def test_uncountable_food_requires_grams_if_serving_unknown(
    api_client,
    user,
    curry_food,
    tmp_path,
):
    with override_settings(MEDIA_ROOT=tmp_path):
        analysis = PhotoAnalysis.objects.create(
            user=user,
            image=uploaded_png("curry.png"),
            status=PhotoAnalysis.Status.NEEDS_REVIEW,
            analysis_type=PhotoAnalysis.AnalysisType.MEAL_PHOTO,
        )
    PhotoDetectedFood.objects.create(
        photo_analysis=analysis,
        detected_name="curry",
        normalized_name="curry",
        matched_food=curry_food,
        quantity_value=Decimal("1.000"),
        quantity_unit="bowl",
        confidence_score=Decimal("0.8000"),
        portion_confidence=Decimal("0.6000"),
    )
    api_client.force_authenticate(user=user)

    response = api_client.post(
        reverse("photo-confirm-as-meal", args=[analysis.id]),
        {
            "date": "2026-06-29",
            "meal_type": "lunch",
        },
        format="json",
    )

    assert response.status_code == 400
    assert "Enter grams for curry" in str(response.json())


@pytest.mark.django_db
@override_settings(
    CELERY_TASK_ALWAYS_EAGER=True,
    PHOTO_ANALYSIS_PROVIDER="mock",
    STORAGES=LOCAL_FILE_STORAGES,
)
def test_another_user_cannot_edit_detected_food(
    api_client,
    user,
    other_user,
    egg_food,
    tmp_path,
):
    with override_settings(MEDIA_ROOT=tmp_path):
        api_client.force_authenticate(user=user)
        upload_response = upload_egg_photo(api_client)

    detected_id = upload_response.json()["detected_foods"][0]["id"]
    api_client.force_authenticate(user=other_user)
    response = api_client.patch(
        reverse("photo-detected-food-detail", args=[detected_id]),
        {"is_removed": True},
        format="json",
    )

    assert response.status_code == 404
