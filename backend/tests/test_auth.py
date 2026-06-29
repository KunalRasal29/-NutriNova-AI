import pytest
from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APIClient

from profiles.models import UserProfile

User = get_user_model()


@pytest.fixture
def api_client():
    return APIClient()


@pytest.mark.django_db
def test_registration_creates_user_profile_and_tokens(api_client):
    response = api_client.post(
        reverse("auth-register"),
        {
            "email": "anika@example.com",
            "password": "strong-local-passphrase",
            "display_name": "Anika",
            "timezone": "Asia/Kolkata",
            "country": "in",
        },
        format="json",
    )

    assert response.status_code == 201
    payload = response.json()
    assert payload["access"]
    assert payload["refresh"]
    assert payload["user"]["email"] == "anika@example.com"
    assert payload["user"]["display_name"] == "Anika"
    assert payload["user"]["timezone"] == "Asia/Kolkata"
    assert payload["user"]["country"] == "IN"

    user = User.objects.get(email="anika@example.com")
    assert user.profile.display_name == "Anika"
    assert user.profile.has_completed_onboarding is False


@pytest.mark.django_db
def test_login_returns_rotatable_jwt_tokens(api_client):
    User.objects.create_user(
        username="dev@example.com",
        email="dev@example.com",
        password="strong-local-passphrase",
    )

    response = api_client.post(
        reverse("auth-login"),
        {
            "email": "dev@example.com",
            "password": "strong-local-passphrase",
        },
        format="json",
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["access"]
    assert payload["refresh"]
    assert payload["user"]["email"] == "dev@example.com"


@pytest.mark.django_db
def test_profile_retrieval_returns_current_user_profile(api_client):
    user = User.objects.create_user(
        username="me@example.com",
        email="me@example.com",
        password="strong-local-passphrase",
    )
    UserProfile.objects.filter(user=user).update(
        display_name="Current User",
        goal_type=UserProfile.GoalType.IMPROVE_HEALTH,
        dietary_preference=UserProfile.DietaryPreference.HIGH_PROTEIN,
    )
    api_client.force_authenticate(user=user)

    response = api_client.get(reverse("me"))

    assert response.status_code == 200
    payload = response.json()
    assert payload["email"] == "me@example.com"
    assert payload["display_name"] == "Current User"
    assert payload["goal_type"] == "improve_health"
    assert payload["dietary_preference"] == "high_protein"
    assert "created_at" in payload
    assert "updated_at" in payload


@pytest.mark.django_db
def test_users_cannot_access_or_mutate_another_users_profile(api_client):
    first_user = User.objects.create_user(
        username="first@example.com",
        email="first@example.com",
        password="strong-local-passphrase",
    )
    second_user = User.objects.create_user(
        username="second@example.com",
        email="second@example.com",
        password="strong-local-passphrase",
    )
    UserProfile.objects.filter(user=first_user).update(display_name="First")
    UserProfile.objects.filter(user=second_user).update(display_name="Second")

    api_client.force_authenticate(user=first_user)

    get_response = api_client.get(
        reverse("me"),
        {"user_id": str(second_user.id)},
    )
    assert get_response.status_code == 200
    assert get_response.json()["email"] == "first@example.com"
    assert get_response.json()["display_name"] == "First"

    patch_response = api_client.patch(
        reverse("me"),
        {"display_name": "First Updated", "dietary_preference": "Jain"},
        format="json",
    )
    assert patch_response.status_code == 200

    first_user.profile.refresh_from_db()
    second_user.profile.refresh_from_db()
    assert first_user.profile.display_name == "First Updated"
    assert first_user.profile.dietary_preference == "jain"
    assert second_user.profile.display_name == "Second"
