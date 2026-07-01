from datetime import timedelta

import pytest
from django.contrib.auth import get_user_model
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APIClient

from habits.models import DailyChecklistTask, Habit, HabitCheckIn

User = get_user_model()


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def user():
    return User.objects.create_user(
        username="habits@example.com",
        email="habits@example.com",
        password="strong-local-passphrase",
    )


@pytest.fixture
def other_user():
    return User.objects.create_user(
        username="other-habits@example.com",
        email="other-habits@example.com",
        password="strong-local-passphrase",
    )


def create_daily_habit(api_client, title="Drink water"):
    response = api_client.post(
        reverse("habit-list"),
        {
            "title": title,
            "description": "Daily wellness task",
            "recurrence": "daily",
            "start_date": "2026-06-29",
            "target_count": 1,
        },
        format="json",
    )
    assert response.status_code == 201, response.json()
    return response.json()


def create_habit_with_payload(api_client, payload):
    response = api_client.post(reverse("habit-list"), payload, format="json")
    assert response.status_code == 201, response.json()
    return response.json()


@pytest.mark.django_db
def test_create_habit_and_generate_daily_checklist(api_client, user):
    api_client.force_authenticate(user=user)
    habit = create_daily_habit(api_client)

    response = api_client.get(
        reverse("habit-dashboard"),
        {"date": "2026-06-29"},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["stats"] == {
        "total": 1,
        "completed": 0,
        "remaining": 1,
        "percent_complete": 0,
    }
    assert payload["tasks"][0]["title"] == "Drink water"
    assert payload["tasks"][0]["source_habit"] == habit["id"]
    assert payload["habits"][0]["is_due"] is True
    assert (
        DailyChecklistTask.objects.filter(
            user=user,
            source_habit_id=habit["id"],
        ).count()
        == 1
    )


@pytest.mark.django_db
def test_habit_check_in_updates_streak(api_client, user):
    api_client.force_authenticate(user=user)
    habit = create_daily_habit(api_client)

    first = api_client.post(
        reverse("habit-check-in", args=[habit["id"]]),
        {"checked_on": "2026-06-29", "is_completed": True},
        format="json",
    )
    second = api_client.post(
        reverse("habit-check-in", args=[habit["id"]]),
        {"checked_on": "2026-06-30", "is_completed": True},
        format="json",
    )

    assert first.status_code == 200
    assert second.status_code == 200
    habit_obj = Habit.objects.get(id=habit["id"])
    assert habit_obj.current_streak == 2
    assert habit_obj.longest_streak == 2


@pytest.mark.django_db
def test_check_habit_for_today(api_client, user):
    api_client.force_authenticate(user=user)
    habit = create_habit_with_payload(
        api_client,
        {
            "title": "Drink 8 glasses water",
            "category": "water",
            "recurrence_type": "daily",
            "start_date": "2026-06-29",
            "target_count": 8,
            "unit": "glasses",
            "color": "#0EA5E9",
            "icon": "droplets",
        },
    )

    response = api_client.post(
        reverse("habit-check", args=[habit["id"]]),
        {
            "date": "2026-06-29",
            "completed_count": 8,
            "note": "Done by evening.",
        },
        format="json",
    )

    assert response.status_code == 200, response.json()
    payload = response.json()
    assert payload["date"] == "2026-06-29"
    assert payload["completed_count"] == 8
    assert payload["is_completed"] is True
    today = api_client.get(reverse("habit-today"), {"date": "2026-06-29"})
    assert today.status_code == 200
    assert today.json()["stats"]["completed"] == 1
    assert today.json()["items"][0]["completion_percentage"] == 100.0


@pytest.mark.django_db
def test_uncheck_habit(api_client, user):
    api_client.force_authenticate(user=user)
    habit = create_daily_habit(api_client)
    check = api_client.post(
        reverse("habit-check", args=[habit["id"]]),
        {"date": "2026-06-29", "completed_count": 1},
        format="json",
    )
    assert check.status_code == 200

    response = api_client.delete(
        f"{reverse('habit-check', args=[habit['id']])}?date=2026-06-29"
    )

    assert response.status_code == 204
    assert (
        HabitCheckIn.objects.filter(user=user, habit_id=habit["id"]).exists() is False
    )
    today = api_client.get(reverse("habit-today"), {"date": "2026-06-29"})
    assert today.json()["items"][0]["is_completed"] is False


@pytest.mark.django_db
def test_streak_calculation_endpoint(api_client, user):
    api_client.force_authenticate(user=user)
    today = timezone.localdate()
    yesterday = today - timedelta(days=1)
    habit = create_habit_with_payload(
        api_client,
        {
            "title": "Drink water",
            "recurrence": "daily",
            "start_date": yesterday.isoformat(),
            "target_count": 1,
        },
    )
    for day in (yesterday, today):
        response = api_client.post(
            reverse("habit-check", args=[habit["id"]]),
            {"date": day.isoformat(), "completed_count": 1},
            format="json",
        )
        assert response.status_code == 200

    response = api_client.get(reverse("habit-streaks"))

    assert response.status_code == 200
    row = response.json()["habits"][0]
    assert row["habit_id"] == habit["id"]
    assert row["current_streak"] == 2
    assert row["longest_streak"] == 2


@pytest.mark.django_db
def test_monthly_grid(api_client, user):
    api_client.force_authenticate(user=user)
    habit = create_daily_habit(api_client)
    api_client.post(
        reverse("habit-check", args=[habit["id"]]),
        {"date": "2026-06-29", "completed_count": 1},
        format="json",
    )

    response = api_client.get(reverse("habit-month-grid"), {"month": "2026-06"})

    assert response.status_code == 200, response.json()
    payload = response.json()
    assert payload["month"] == "2026-06"
    assert len(payload["days"]) == 30
    assert payload["stats"]["total"] == 2
    assert payload["stats"]["completed"] == 1
    june_29 = payload["days"][28]
    assert june_29["date"] == "2026-06-29"
    assert june_29["items"][0]["title"] == "Drink water"
    assert june_29["items"][0]["is_completed"] is True


@pytest.mark.django_db
def test_inactive_habits_do_not_show_in_today_list(api_client, user):
    api_client.force_authenticate(user=user)
    create_habit_with_payload(
        api_client,
        {
            "title": "Archived habit",
            "start_date": "2026-06-29",
            "is_active": False,
        },
    )

    response = api_client.get(reverse("habit-today"), {"date": "2026-06-29"})

    assert response.status_code == 200
    assert response.json()["items"] == []


@pytest.mark.django_db
def test_create_from_template(api_client, user):
    api_client.force_authenticate(user=user)

    response = api_client.post(
        reverse("habit-create-from-template"),
        {
            "title": "Read 10 pages",
            "start_date": "2026-06-29",
        },
        format="json",
    )

    assert response.status_code == 201, response.json()
    payload = response.json()
    assert payload["title"] == "Read 10 pages"
    assert payload["category"] == "study"
    assert payload["unit"] == "pages"
    assert payload["target_count"] == 10


@pytest.mark.django_db
def test_toggling_generated_task_writes_check_in(api_client, user):
    api_client.force_authenticate(user=user)
    habit = create_daily_habit(api_client)
    dashboard = api_client.get(reverse("habit-dashboard"), {"date": "2026-06-29"})
    task_id = dashboard.json()["tasks"][0]["id"]

    response = api_client.patch(
        reverse("checklist-task-detail", args=[task_id]),
        {"is_completed": True},
        format="json",
    )

    assert response.status_code == 200
    check_in = HabitCheckIn.objects.get(user=user, habit_id=habit["id"])
    assert check_in.checked_on.isoformat() == "2026-06-29"
    assert check_in.is_completed is True
    assert Habit.objects.get(id=habit["id"]).current_streak == 1


@pytest.mark.django_db
def test_create_manual_checklist_task(api_client, user):
    api_client.force_authenticate(user=user)

    response = api_client.post(
        reverse("checklist-task-list"),
        {
            "title": "Buy spinach",
            "task_date": "2026-06-29",
            "sort_order": 5,
        },
        format="json",
    )

    assert response.status_code == 201, response.json()
    payload = response.json()
    assert payload["title"] == "Buy spinach"
    assert payload["source_habit"] is None
    assert DailyChecklistTask.objects.filter(user=user, title="Buy spinach").exists()


@pytest.mark.django_db
def test_weekday_habit_not_generated_on_weekend(api_client, user):
    api_client.force_authenticate(user=user)
    response = api_client.post(
        reverse("habit-list"),
        {
            "title": "Morning walk",
            "recurrence": "weekdays",
            "start_date": "2026-06-29",
        },
        format="json",
    )
    assert response.status_code == 201, response.json()

    saturday = api_client.get(reverse("habit-dashboard"), {"date": "2026-07-04"})

    assert saturday.status_code == 200
    assert saturday.json()["tasks"] == []


@pytest.mark.django_db
def test_users_cannot_access_another_users_habits_or_tasks(
    api_client,
    user,
    other_user,
):
    api_client.force_authenticate(user=user)
    habit = create_daily_habit(api_client)
    dashboard = api_client.get(reverse("habit-dashboard"), {"date": "2026-06-29"})
    task_id = dashboard.json()["tasks"][0]["id"]

    api_client.force_authenticate(user=other_user)

    assert (
        api_client.get(reverse("habit-detail", args=[habit["id"]])).status_code == 404
    )
    assert (
        api_client.get(reverse("checklist-task-detail", args=[task_id])).status_code
        == 404
    )
    assert api_client.get(reverse("habit-list")).json()["results"] == []
    assert (
        api_client.get(reverse("checklist-task-list"), {"date": "2026-06-29"}).json()[
            "results"
        ]
        == []
    )


@pytest.mark.django_db
def test_users_cannot_check_another_users_habit(api_client, user, other_user):
    api_client.force_authenticate(user=user)
    habit = create_daily_habit(api_client)

    api_client.force_authenticate(user=other_user)
    response = api_client.post(
        reverse("habit-check", args=[habit["id"]]),
        {"date": "2026-06-29", "completed_count": 1},
        format="json",
    )

    assert response.status_code == 404
