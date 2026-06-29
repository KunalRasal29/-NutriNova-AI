import pytest
from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APIClient

from profiles.models import BodyMetric, UserProfile

User = get_user_model()


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def user():
    user = User.objects.create_user(
        username="metrics@example.com",
        email="metrics@example.com",
        password="password123",
    )
    UserProfile.objects.update_or_create(
        user=user,
        defaults={"display_name": "Metrics", "weight_kg": "75.00"},
    )
    return user


@pytest.fixture
def other_user():
    return User.objects.create_user(
        username="other-metrics@example.com",
        email="other-metrics@example.com",
        password="password123",
    )


@pytest.mark.django_db
def test_create_and_list_body_metric(api_client, user):
    api_client.force_authenticate(user=user)
    response = api_client.post(
        reverse("body-metric-list"),
        {
            "recorded_on": "2026-06-29",
            "weight_kg": "72.50",
            "waist_cm": "84.00",
        },
        format="json",
    )

    assert response.status_code == 201
    assert response.json()["weight_kg"] == "72.50"

    list_response = api_client.get(reverse("body-metric-list"))
    assert list_response.status_code == 200
    assert list_response.json()["results"][0]["recorded_on"] == "2026-06-29"


@pytest.mark.django_db
def test_create_body_metric_upserts_same_day(api_client, user):
    api_client.force_authenticate(user=user)
    url = reverse("body-metric-list")
    api_client.post(
        url,
        {"recorded_on": "2026-06-29", "weight_kg": "72.50"},
        format="json",
    )
    response = api_client.post(
        url,
        {"recorded_on": "2026-06-29", "weight_kg": "72.10"},
        format="json",
    )

    assert response.status_code == 201
    assert BodyMetric.objects.filter(user=user, recorded_on="2026-06-29").count() == 1
    assert response.json()["weight_kg"] == "72.10"


@pytest.mark.django_db
def test_body_metric_trend_returns_ordered_weight_change(api_client, user):
    api_client.force_authenticate(user=user)
    BodyMetric.objects.create(
        user=user,
        recorded_on="2026-06-28",
        weight_kg="73.00",
    )
    BodyMetric.objects.create(
        user=user,
        recorded_on="2026-06-29",
        weight_kg="72.50",
    )

    response = api_client.get(reverse("body-metric-trend"), {"days": 365})

    assert response.status_code == 200
    payload = response.json()
    assert [item["weight_kg"] for item in payload["items"]] == ["73.00", "72.50"]
    assert payload["latest"]["weight_kg"] == "72.50"
    assert payload["change_kg"] == "-0.500"


@pytest.mark.django_db
def test_body_metric_user_isolation(api_client, user, other_user):
    metric = BodyMetric.objects.create(
        user=user,
        recorded_on="2026-06-29",
        weight_kg="72.50",
    )

    api_client.force_authenticate(user=other_user)
    assert api_client.get(reverse("body-metric-detail", args=[metric.id])).status_code == 404
    assert api_client.get(reverse("body-metric-list")).json()["results"] == []


@pytest.mark.django_db
def test_body_metric_requires_a_metric_value(api_client, user):
    api_client.force_authenticate(user=user)
    response = api_client.post(
        reverse("body-metric-list"),
        {"recorded_on": "2026-06-29", "notes": "No measurement"},
        format="json",
    )

    assert response.status_code == 400
