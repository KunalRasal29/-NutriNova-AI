from decimal import Decimal

import pytest
from django.core.management import call_command
from rest_framework.test import APIClient


@pytest.mark.django_db
def test_registered_user_can_log_correct_and_reopen_their_data():
    call_command("import_usda_fdc_sample")
    call_command("import_openfoodfacts_sample")
    client = APIClient()
    today = "2026-10-06"
    credentials = {"email": "journey@example.com", "password": "journey-test-password"}

    def request(method, path, data=None, status=200):
        response = getattr(client, method)(path, data or {}, format="json")
        assert response.status_code == status, (path, response.content)
        return response.json() if status != 204 else None

    request(
        "post",
        "/api/auth/register/",
        {
            **credentials,
            "display_name": "Journey",
            "timezone": "Asia/Kolkata",
        },
        status=201,
    )
    tokens = request("post", "/api/auth/login/", credentials)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    profile = request(
        "patch",
        "/api/me/",
        {
            "has_completed_onboarding": True,
            "height_cm": 175,
            "weight_kg": 75,
            "activity_level": "moderate",
            "goal_type": "improve_health",
            "daily_calorie_target_kcal": 2000,
        },
    )
    assert profile["has_completed_onboarding"] is True

    food = request("get", "/api/foods/search/", {"q": "boiled egg"})["results"][0]
    favorite_url = f"/api/foods/{food['id']}/favorite/"
    assert request("post", favorite_url)["is_favorite"] is True
    assert request("delete", favorite_url)["is_favorite"] is False
    assert (
        request(
            "get",
            "/api/foods/barcode-lookup/",
            {
                "barcode": "8900000000011",
            },
        )[
            "results"
        ][0]["name"]
        == "Packaged rolled oats"
    )

    added = request(
        "post",
        "/api/meals/manual-add/",
        {
            "date": today,
            "meal_type": "breakfast",
            "food_id": food["id"],
            "quantity_value": 2,
            "quantity_unit": "egg",
        },
        status=201,
    )
    item_url = f"/api/meals/items/{added['item']['id']}/"
    assert Decimal(added["item"]["grams_calculated"]) == 100
    edited = request(
        "patch",
        item_url,
        {
            "food": food["id"],
            "quantity": 3,
            "unit": "serving",
        },
    )
    assert Decimal(edited["grams_calculated"]) == 150
    summary = request("get", "/api/nutrition/daily-summary/", {"date": today})
    assert Decimal(summary["calories_kcal"]) == Decimal("232.5")
    request("delete", item_url, status=204)
    assert (
        Decimal(
            request(
                "get",
                "/api/nutrition/daily-summary/",
                {
                    "date": today,
                },
            )["calories_kcal"]
        )
        == 0
    )

    parsed = request(
        "post",
        "/api/meals/quick-add-text/",
        {
            "text": "2 eggs",
            "date": today,
            "meal_type": "dinner",
        },
    )
    assert parsed["parsed_items"][0]["food_id"] == food["id"]
    quick = request(
        "post",
        "/api/meals/quick-add-text/confirm/",
        {
            "text": "2 eggs",
            "date": today,
            "meal_type": "dinner",
            "items": parsed["parsed_items"],
        },
        status=201,
    )
    assert quick["meal"]["meal_type"] == "dinner"
    assert Decimal(quick["items"][0]["calories_kcal"]) == 155

    custom = request(
        "post",
        "/api/foods/custom/",
        {
            "name": "Journey snack",
            "serving_name": "1 piece",
            "serving_grams": 50,
            "calories_kcal": 200,
            "protein_g": 10,
            "carbs_g": 20,
            "fat_g": 8,
        },
        status=201,
    )
    assert request("get", "/api/foods/my-foods/")["results"][0]["id"] == custom["id"]
    request(
        "post",
        "/api/meals/manual-add/",
        {
            "date": today,
            "meal_type": "snack",
            "food_id": custom["id"],
            "quantity_value": 1,
            "quantity_unit": "serving",
        },
        status=201,
    )
    assert (
        Decimal(
            request(
                "get",
                "/api/nutrition/daily-summary/",
                {
                    "date": today,
                },
            )["calories_kcal"]
        )
        == 355
    )

    habit = request(
        "post",
        "/api/habits/",
        {
            "title": "Read before bed",
            "start_date": today,
            "recurrence": "daily",
            "target_count": 1,
            "unit": "checkbox",
        },
        status=201,
    )
    check_url = f"/api/habits/{habit['id']}/check/"
    request(
        "post", check_url, {"date": today, "completed_count": 1, "is_completed": True}
    )
    assert (
        request("get", "/api/habits/today/", {"date": today})["items"][0][
            "is_completed"
        ]
        is True
    )
    request("delete", f"{check_url}?date={today}", status=204)
    assert (
        request("get", "/api/habits/today/", {"date": today})["items"][0][
            "is_completed"
        ]
        is False
    )

    request(
        "post",
        "/api/tracking/water/",
        {"amount_ml": 500, "entry_date": today},
        status=201,
    )
    request(
        "post",
        "/api/tracking/activities/",
        {
            "activity_type": "workout",
            "activity_date": today,
            "duration_minutes": 30,
            "calories_burned": 250,
            "title": "Training",
        },
        status=201,
    )
    tracking = request("get", "/api/tracking/today/", {"date": today})
    assert tracking["water_ml"] == 500
    assert Decimal(str(tracking["calories_burned"])) == 250
    request(
        "post",
        "/api/body-metrics/",
        {"recorded_on": today, "weight_kg": 75},
        status=201,
    )
    request("get", "/api/nutrition/range-summary/", {"start": today, "end": today})

    request("post", "/api/auth/logout/", {"refresh": tokens["refresh"]}, status=204)
    client.credentials()
    tokens = request("post", "/api/auth/login/", credentials)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    assert request("get", "/api/me/")["has_completed_onboarding"] is True
    assert (
        Decimal(
            request(
                "get",
                "/api/nutrition/daily-summary/",
                {
                    "date": today,
                },
            )["calories_kcal"]
        )
        == 355
    )
