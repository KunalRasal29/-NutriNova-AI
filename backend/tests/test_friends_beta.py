from datetime import timedelta

import pytest
from django.contrib.auth import get_user_model
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APIClient

from meals.models import DailyNutritionSummary
from profiles.models import UserProfile

User = get_user_model()


@pytest.fixture
def beta_users():
    users = []
    for index in range(2):
        user = User.objects.create_user(
            username=f"beta{index}@example.com",
            email=f"beta{index}@example.com",
            password="password123",
        )
        UserProfile.objects.update_or_create(
            user=user,
            defaults={
                "display_name": f"Beta {index}",
                "daily_calorie_target_kcal": 2000,
                "daily_protein_target_g": 100,
                "daily_water_target_ml": 2500,
            },
        )
        users.append(user)
    return users


@pytest.mark.django_db
def test_daily_tracking_is_user_scoped_and_aggregated(beta_users):
    user, other = beta_users
    client = APIClient()
    client.force_authenticate(user=user)
    assert client.post(
        reverse("tracking-water-list"),
        {"amount_ml": 500},
        format="json",
    ).status_code == 201
    assert client.post(
        reverse("tracking-activity-list"),
        {
            "activity_type": "steps",
            "steps": 4200,
            "title": "Evening walk",
        },
        format="json",
    ).status_code == 201

    payload = client.get(reverse("tracking-today")).json()
    assert payload["water_ml"] == 500
    assert payload["steps"] == 4200

    client.force_authenticate(user=other)
    other_payload = client.get(reverse("tracking-today")).json()
    assert other_payload["water_ml"] == 0
    assert other_payload["steps"] == 0


@pytest.mark.django_db
def test_friends_group_join_challenge_and_privacy(beta_users):
    owner, friend = beta_users
    client = APIClient()
    client.force_authenticate(user=owner)
    create_response = client.post(
        reverse("friend-groups"),
        {"name": "Weekend Crew"},
        format="json",
    )
    assert create_response.status_code == 201
    group = create_response.json()

    client.force_authenticate(user=friend)
    join_response = client.post(
        reverse("join-friend-group"),
        {"invite_code": group["invite_code"]},
        format="json",
    )
    assert join_response.status_code == 200
    assert len(join_response.json()["members"]) == 2
    assert "Meals, weight" in join_response.json()["privacy_note"]

    client.force_authenticate(user=owner)
    challenge_response = client.post(
        reverse("group-challenge", args=[group["id"]]),
        {
            "title": "Log breakfast 5 times",
            "week_start": timezone.localdate(),
            "target_count": 5,
        },
        format="json",
    )
    assert challenge_response.status_code == 200
    challenge_id = challenge_response.json()["challenge"]["id"]

    client.force_authenticate(user=friend)
    check_response = client.post(
        reverse("group-challenge-check", args=[group["id"], challenge_id]),
        {"completed_count": 2},
        format="json",
    )
    assert check_response.status_code == 200
    assert check_response.json()["challenge"]["my_completed_count"] == 2
    assert not any(
        key in check_response.json()
        for key in ("meals", "weight", "nutrition_totals")
    )


@pytest.mark.django_db
def test_weekly_report_uses_real_user_data(beta_users):
    user, other = beta_users
    today = timezone.localdate()
    DailyNutritionSummary.objects.create(
        user=user,
        date=today,
        calories_kcal=1800,
        protein_g=95,
    )
    DailyNutritionSummary.objects.create(
        user=other,
        date=today - timedelta(days=1),
        calories_kcal=9000,
        protein_g=500,
    )
    client = APIClient()
    client.force_authenticate(user=user)
    response = client.get(reverse("weekly-report"))
    assert response.status_code == 200
    payload = response.json()
    assert payload["summary"]["logged_days"] == 1
    assert payload["summary"]["average_calories_kcal"] == 257.1
    assert "explanation" in payload["score"]
