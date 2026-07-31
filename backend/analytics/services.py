from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.db import models
from django.db.models import Count, Sum
from django.utils import timezone

from habits.models import HabitCheckIn
from meals.models import DailyNutritionSummary, MealLog, MealLogItem
from profiles.models import BodyMetric
from tracking.models import DailyActivity, WaterIntakeEntry


def weekly_report_for_user(user, *, days: int = 7) -> dict:
    end_date = timezone.localdate()
    start_date = end_date - timedelta(days=days - 1)
    summaries = {
        item.date: item
        for item in DailyNutritionSummary.objects.filter(
            user=user,
            date__range=(start_date, end_date),
        )
    }
    water_by_day = {
        row["entry_date"]: row["total"] or 0
        for row in WaterIntakeEntry.objects.filter(
            user=user,
            entry_date__range=(start_date, end_date),
        )
        .values("entry_date")
        .annotate(total=Sum("amount_ml"))
    }
    activity_by_day = {
        row["activity_date"]: row
        for row in DailyActivity.objects.filter(
            user=user,
            activity_date__range=(start_date, end_date),
        )
        .values("activity_date")
        .annotate(
            steps=Sum("steps"),
            duration_minutes=Sum("duration_minutes"),
            calories_burned=Sum("calories_burned"),
        )
    }
    habit_rows = {
        row["checked_on"]: row
        for row in HabitCheckIn.objects.filter(
            user=user,
            checked_on__range=(start_date, end_date),
        )
        .values("checked_on")
        .annotate(
            total=Count("id"),
            completed=Count("id", filter=models.Q(is_completed=True)),
        )
    }
    meal_counts = {
        row["date"]: row["count"]
        for row in MealLog.objects.filter(
            user=user,
            date__range=(start_date, end_date),
        )
        .values("date")
        .annotate(count=Count("id"))
    }

    daily = []
    total_calories = Decimal("0")
    total_protein = Decimal("0")
    total_water = 0
    logged_days = 0
    completed_habits = 0
    total_habits = 0
    for offset in range(days):
        current = start_date + timedelta(days=offset)
        nutrition = summaries.get(current)
        activity = activity_by_day.get(current, {})
        habit = habit_rows.get(current, {})
        calories = nutrition.calories_kcal if nutrition else Decimal("0")
        protein = nutrition.protein_g if nutrition else Decimal("0")
        if nutrition and calories > 0:
            logged_days += 1
        total_calories += calories
        total_protein += protein
        total_water += int(water_by_day.get(current, 0))
        completed_habits += int(habit.get("completed", 0))
        total_habits += int(habit.get("total", 0))
        daily.append(
            {
                "date": current,
                "calories_kcal": calories,
                "protein_g": protein,
                "carbs_g": nutrition.carbs_g if nutrition else 0,
                "fat_g": nutrition.fat_g if nutrition else 0,
                "water_ml": water_by_day.get(current, 0),
                "steps": activity.get("steps") or 0,
                "workout_minutes": activity.get("duration_minutes") or 0,
                "exercise_calories": activity.get("calories_burned") or 0,
                "meals_logged": meal_counts.get(current, 0),
                "habits_completed": habit.get("completed", 0),
                "habits_total": habit.get("total", 0),
            }
        )

    profile = getattr(user, "profile", None)
    calorie_target = Decimal(
        profile.daily_calorie_target_kcal
        if profile and profile.daily_calorie_target_kcal
        else 2000
    )
    protein_target = Decimal(
        profile.daily_protein_target_g
        if profile and profile.daily_protein_target_g
        else 100
    )
    water_target = Decimal(
        profile.daily_water_target_ml
        if profile and profile.daily_water_target_ml
        else 2500
    )
    average_calories = total_calories / days
    average_protein = total_protein / days
    average_water = Decimal(total_water) / days
    logging_score = round(logged_days / days * 100)
    protein_score = _bounded_score(average_protein, protein_target)
    water_score = _bounded_score(average_water, water_target)
    calorie_score = _target_range_score(average_calories, calorie_target)
    habit_score = round(completed_habits / total_habits * 100) if total_habits else 0
    overall = round(
        logging_score * 0.25
        + protein_score * 0.25
        + calorie_score * 0.2
        + water_score * 0.15
        + habit_score * 0.15
    )

    weights = list(
        BodyMetric.objects.filter(
            user=user,
            recorded_on__range=(start_date, end_date),
            weight_kg__isnull=False,
        )
        .order_by("recorded_on")
        .values("recorded_on", "weight_kg")
    )
    frequent_foods = list(
        MealLogItem.objects.filter(
            user=user,
            meal_log__date__range=(start_date, end_date),
        )
        .values("food__canonical_name")
        .annotate(times_logged=Count("id"))
        .order_by("-times_logged", "food__canonical_name")[:5]
    )
    suggestions = _suggestions(
        logged_days=logged_days,
        days=days,
        protein_score=protein_score,
        water_score=water_score,
        habit_score=habit_score,
        total_habits=total_habits,
    )
    return {
        "start_date": start_date,
        "end_date": end_date,
        "days": daily,
        "summary": {
            "average_calories_kcal": average_calories.quantize(Decimal("0.1")),
            "average_protein_g": average_protein.quantize(Decimal("0.1")),
            "average_water_ml": average_water.quantize(Decimal("1")),
            "logged_days": logged_days,
            "meal_consistency_percent": logging_score,
            "habit_completion_percent": habit_score,
        },
        "score": {
            "overall": overall,
            "logging": logging_score,
            "calorie_consistency": calorie_score,
            "protein": protein_score,
            "water": water_score,
            "habits": habit_score,
            "explanation": (
                "This wellness score combines meal logging, calorie consistency, "
                "protein, water, and completed habits. It is not medical advice."
            ),
        },
        "weight_trend": weights,
        "frequent_foods": [
            {
                "name": row["food__canonical_name"],
                "times_logged": row["times_logged"],
            }
            for row in frequent_foods
        ],
        "suggestions": suggestions,
    }


def _bounded_score(value: Decimal, target: Decimal) -> int:
    if target <= 0:
        return 0
    return min(100, max(0, round(value / target * 100)))


def _target_range_score(value: Decimal, target: Decimal) -> int:
    if value <= 0 or target <= 0:
        return 0
    difference = abs(value - target) / target
    return max(0, min(100, round(100 - difference * 100)))


def _suggestions(**values) -> list[dict]:
    suggestions = []
    if values["logged_days"] < values["days"]:
        suggestions.append(
            {
                "title": "Keep logging",
                "message": (
                    "Log at least one meal each day to make your weekly trends "
                    "more useful."
                ),
            }
        )
    if values["protein_score"] < 80:
        suggestions.append(
            {
                "title": "Protein opportunity",
                "message": (
                    "Try adding a protein source to one meal tomorrow."
                ),
            }
        )
    if values["water_score"] < 80:
        suggestions.append(
            {
                "title": "Hydration",
                "message": (
                    "Add water through the day instead of trying to catch up "
                    "at night."
                ),
            }
        )
    if values["total_habits"] and values["habit_score"] < 70:
        suggestions.append(
            {
                "title": "Make habits smaller",
                "message": (
                    "Reduce one difficult habit target for a more repeatable week."
                ),
            }
        )
    return suggestions[:3]
