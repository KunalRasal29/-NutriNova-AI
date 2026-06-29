from __future__ import annotations

from calendar import monthrange
from datetime import date, datetime, timedelta
from decimal import Decimal

from django.db import transaction
from django.db.models import Q
from django.utils import timezone

from habits.models import DailyChecklistTask, Habit, HabitCheckIn, HabitTemplate

MAX_STREAK_SCAN_DAYS = 3660
DEFAULT_HABIT_TEMPLATES = [
    {
        "title": "Drink 8 glasses water",
        "description": "Hit your daily hydration target.",
        "category": Habit.Category.WATER,
        "default_target_count": 8,
        "unit": Habit.Unit.GLASSES,
        "icon": "droplets",
    },
    {
        "title": "Eat 100g protein",
        "description": "Reach your protein goal for the day.",
        "category": Habit.Category.NUTRITION,
        "default_target_count": 100,
        "unit": Habit.Unit.GRAMS,
        "icon": "drumstick",
    },
    {
        "title": "Walk 8,000 steps",
        "description": "Complete your daily walking goal.",
        "category": Habit.Category.WORKOUT,
        "default_target_count": 8000,
        "unit": Habit.Unit.STEPS,
        "icon": "footprints",
    },
    {
        "title": "Sleep before 11 PM",
        "description": "Wind down early for better recovery.",
        "category": Habit.Category.SLEEP,
        "default_target_count": 1,
        "unit": Habit.Unit.CHECKBOX,
        "icon": "moon",
    },
    {
        "title": "No sugar drinks",
        "description": "Avoid sweetened beverages today.",
        "category": Habit.Category.NUTRITION,
        "default_target_count": 1,
        "unit": Habit.Unit.CHECKBOX,
        "icon": "cup-soda",
    },
    {
        "title": "Take progress photo",
        "description": "Capture a private progress photo.",
        "category": Habit.Category.CUSTOM,
        "default_target_count": 1,
        "unit": Habit.Unit.CHECKBOX,
        "icon": "camera",
    },
    {
        "title": "Log all meals",
        "description": "Record every meal and snack.",
        "category": Habit.Category.NUTRITION,
        "default_target_count": 1,
        "unit": Habit.Unit.CHECKBOX,
        "icon": "notebook-tabs",
    },
    {
        "title": "Eat 3 fruits/vegetables",
        "description": "Eat at least three produce servings.",
        "category": Habit.Category.NUTRITION,
        "default_target_count": 3,
        "unit": Habit.Unit.CUSTOM,
        "icon": "apple",
    },
    {
        "title": "Workout",
        "description": "Complete a workout session.",
        "category": Habit.Category.WORKOUT,
        "default_target_count": 1,
        "unit": Habit.Unit.CHECKBOX,
        "icon": "dumbbell",
    },
    {
        "title": "Meditation",
        "description": "Meditate or breathe mindfully.",
        "category": Habit.Category.MINDFULNESS,
        "default_target_count": 10,
        "unit": Habit.Unit.MINUTES,
        "icon": "brain",
    },
    {
        "title": "Take supplements",
        "description": "Take planned supplements.",
        "category": Habit.Category.MEDICINE,
        "default_target_count": 1,
        "unit": Habit.Unit.CHECKBOX,
        "icon": "pill",
    },
    {
        "title": "No junk food",
        "description": "Avoid junk food today.",
        "category": Habit.Category.NUTRITION,
        "default_target_count": 1,
        "unit": Habit.Unit.CHECKBOX,
        "icon": "ban",
    },
    {
        "title": "Read 10 pages",
        "description": "Read ten pages from a book or notes.",
        "category": Habit.Category.STUDY,
        "default_target_count": 10,
        "unit": Habit.Unit.PAGES,
        "icon": "book-open",
    },
]


def sync_legacy_recurrence_fields(habit: Habit) -> Habit:
    if habit.recurrence == Habit.Recurrence.WEEKDAYS:
        habit.recurrence_type = Habit.RecurrenceType.CUSTOM_DAYS
        habit.days_of_week = [0, 1, 2, 3, 4]
    elif habit.recurrence == Habit.Recurrence.WEEKLY:
        habit.recurrence_type = Habit.RecurrenceType.WEEKLY
        if not habit.days_of_week:
            habit.days_of_week = [habit.start_date.weekday()]
    elif habit.recurrence == Habit.Recurrence.CUSTOM:
        habit.recurrence_type = Habit.RecurrenceType.CUSTOM_DAYS
        weekdays = habit.recurrence_rule.get("weekdays")
        if weekdays is not None:
            habit.days_of_week = [int(day) for day in weekdays]
    return habit


def is_habit_due_on(habit: Habit, target_date: date) -> bool:
    if target_date < habit.start_date:
        return False
    if habit.end_date and target_date > habit.end_date:
        return False
    if not habit.is_active:
        return False

    habit = sync_legacy_recurrence_fields(habit)
    weekday = target_date.weekday()

    if habit.recurrence_type == Habit.RecurrenceType.DAILY:
        return True

    if habit.recurrence_type == Habit.RecurrenceType.WEEKLY:
        days = {int(day) for day in (habit.days_of_week or [])}
        if days:
            return weekday in days
        return weekday == habit.start_date.weekday()

    if habit.recurrence_type == Habit.RecurrenceType.CUSTOM_DAYS:
        days = {int(day) for day in (habit.days_of_week or [])}
        if days and weekday not in days:
            return False
        if not days:
            return True
        interval_days = int(habit.recurrence_rule.get("interval_days", 1) or 1)
        days_since_start = (target_date - habit.start_date).days
        return days_since_start % max(interval_days, 1) == 0
    return False


def iter_due_dates(habit: Habit, start: date, end: date):
    current = max(start, habit.start_date)
    if habit.end_date:
        end = min(end, habit.end_date)
    while current <= end:
        if is_habit_due_on(habit, current):
            yield current
        current += timedelta(days=1)


@transaction.atomic
def materialize_daily_checklist(user, target_date: date) -> list[DailyChecklistTask]:
    due_habits = Habit.objects.filter(
        user=user,
        is_active=True,
        start_date__lte=target_date,
    ).filter(end_date__isnull=True) | Habit.objects.filter(
        user=user,
        is_active=True,
        start_date__lte=target_date,
        end_date__gte=target_date,
    )
    due_habits = due_habits.order_by("title").distinct()
    existing_count = DailyChecklistTask.objects.filter(
        user=user,
        task_date=target_date,
    ).count()
    for offset, habit in enumerate(due_habits):
        if not is_habit_due_on(habit, target_date):
            continue
        check_in = HabitCheckIn.objects.filter(
            user=user,
            habit=habit,
            checked_on=target_date,
        ).first()
        DailyChecklistTask.objects.update_or_create(
            user=user,
            source_habit=habit,
            task_date=target_date,
            defaults={
                "title": habit.title,
                "is_completed": bool(check_in and check_in.is_completed),
                "completed_at": (
                    check_in.completed_at
                    if check_in and check_in.is_completed
                    else None
                ),
                "sort_order": existing_count + offset,
            },
        )
    return list(
        DailyChecklistTask.objects.filter(user=user, task_date=target_date)
        .select_related("source_habit")
        .order_by("sort_order", "created_at")
    )


@transaction.atomic
def upsert_habit_check_in(
    *,
    habit: Habit,
    checked_on: date,
    is_completed: bool,
    count: int | None = None,
    note: str = "",
) -> HabitCheckIn:
    if not is_habit_due_on(habit, checked_on):
        raise ValueError("Habit is not scheduled for this date.")
    completed_count = count if count is not None else habit.target_count
    is_completed = bool(is_completed or completed_count >= habit.target_count)
    check_in, _ = HabitCheckIn.objects.update_or_create(
        user=habit.user,
        habit=habit,
        checked_on=checked_on,
        defaults={
            "is_completed": is_completed,
            "count": completed_count,
            "note": note,
            "completed_at": timezone.now() if is_completed else None,
        },
    )
    if not is_completed and count is None:
        check_in.count = 0
        check_in.completed_at = None
        check_in.save(update_fields=["count", "completed_at", "updated_at"])
    sync_task_from_check_in(check_in)
    recompute_habit_streaks(habit, as_of=checked_on)
    return check_in


def sync_task_from_check_in(check_in: HabitCheckIn) -> None:
    task = DailyChecklistTask.objects.filter(
        user=check_in.user,
        source_habit=check_in.habit,
        task_date=check_in.checked_on,
    ).first()
    if not task:
        return
    task.is_completed = check_in.is_completed
    task.completed_at = check_in.completed_at if check_in.is_completed else None
    task.save(update_fields=["is_completed", "completed_at", "updated_at"])


@transaction.atomic
def toggle_checklist_task(task: DailyChecklistTask, is_completed: bool):
    task.is_completed = is_completed
    task.completed_at = timezone.now() if is_completed else None
    task.save(update_fields=["is_completed", "completed_at", "updated_at"])
    if task.source_habit:
        upsert_habit_check_in(
            habit=task.source_habit,
            checked_on=task.task_date,
            is_completed=is_completed,
            count=task.source_habit.target_count if is_completed else 0,
        )
    return task


def recompute_habit_streaks(habit: Habit, *, as_of: date | None = None) -> Habit:
    as_of = as_of or timezone.localdate()
    start = max(habit.start_date, as_of - timedelta(days=MAX_STREAK_SCAN_DAYS))
    due_dates = list(iter_due_dates(habit, start, as_of))
    completed_dates = set(
        HabitCheckIn.objects.filter(
            user=habit.user,
            habit=habit,
            checked_on__in=due_dates,
            is_completed=True,
        ).values_list("checked_on", flat=True)
    )

    current_streak = 0
    for due_date in reversed(due_dates):
        if due_date in completed_dates:
            current_streak += 1
        else:
            break

    longest_streak = 0
    running = 0
    for due_date in due_dates:
        if due_date in completed_dates:
            running += 1
            longest_streak = max(longest_streak, running)
        else:
            running = 0

    habit.current_streak = current_streak
    habit.longest_streak = max(habit.longest_streak, longest_streak)
    habit.save(update_fields=["current_streak", "longest_streak", "updated_at"])
    return habit


@transaction.atomic
def delete_habit_check_in(*, habit: Habit, checked_on: date) -> None:
    HabitCheckIn.objects.filter(
        user=habit.user,
        habit=habit,
        checked_on=checked_on,
    ).delete()
    DailyChecklistTask.objects.filter(
        user=habit.user,
        source_habit=habit,
        task_date=checked_on,
    ).update(is_completed=False, completed_at=None)
    recompute_habit_streaks(habit, as_of=checked_on)


def habit_check_for_date(habit: Habit, target_date: date) -> HabitCheckIn | None:
    return HabitCheckIn.objects.filter(
        user=habit.user,
        habit=habit,
        checked_on=target_date,
    ).first()


def habit_grid_row(
    habit: Habit,
    target_date: date,
    check: HabitCheckIn | None = None,
) -> dict:
    check = check if check is not None else habit_check_for_date(habit, target_date)
    completed_count = check.count if check else 0
    is_completed = bool(check and check.is_completed)
    target = Decimal(habit.target_count or 1)
    percent = Decimal("0")
    if target > 0:
        percent = min(
            Decimal(completed_count) / target * Decimal("100"),
            Decimal("100"),
        )
    return {
        "habit_id": habit.id,
        "title": habit.title,
        "description": habit.description,
        "category": habit.category,
        "unit": habit.unit,
        "target_count": habit.target_count,
        "completed_count": completed_count,
        "is_completed": is_completed,
        "date": target_date,
        "note": check.note if check else "",
        "completed_at": check.completed_at if check else None,
        "completion_percentage": float(percent.quantize(Decimal("0.1"))),
        "current_streak": habit.current_streak,
        "longest_streak": habit.longest_streak,
        "sort_order": habit.sort_order,
        "color": habit.color,
        "icon": habit.icon,
    }


def active_habits_for_date(user, target_date: date):
    return [
        habit
        for habit in Habit.objects.filter(
            user=user,
            is_active=True,
            start_date__lte=target_date,
        )
        .filter(models_end_date_filter(target_date))
        .order_by("sort_order", "title")
        if is_habit_due_on(habit, target_date)
    ]


def models_end_date_filter(target_date: date):
    return Q(end_date__isnull=True) | Q(end_date__gte=target_date)


def checklist_stats_from_rows(rows: list[dict]) -> dict:
    total = len(rows)
    completed = sum(1 for row in rows if row["is_completed"])
    percent = 0 if total == 0 else round(completed / total * 100, 1)
    return {
        "total": total,
        "completed": completed,
        "remaining": total - completed,
        "percent_complete": percent,
    }


def today_habit_grid(user, target_date: date) -> dict:
    habits = active_habits_for_date(user, target_date)
    checks = {
        check.habit_id: check
        for check in HabitCheckIn.objects.filter(
            user=user,
            checked_on=target_date,
            habit__in=habits,
        )
    }
    rows = [
        habit_grid_row(habit, target_date, checks.get(habit.id)) for habit in habits
    ]
    return {
        "date": target_date,
        "stats": checklist_stats_from_rows(rows),
        "items": rows,
    }


def completion_percentage_for_habit(habit: Habit, *, end_date: date) -> float:
    due_dates = list(iter_due_dates(habit, habit.start_date, end_date))
    if not due_dates:
        return 0
    completed = HabitCheckIn.objects.filter(
        user=habit.user,
        habit=habit,
        checked_on__in=due_dates,
        is_completed=True,
    ).count()
    return round(completed / len(due_dates) * 100, 1)


def streaks_payload(user, *, as_of: date | None = None) -> dict:
    as_of = as_of or timezone.localdate()
    habits = Habit.objects.filter(user=user).order_by("sort_order", "title")
    rows = []
    for habit in habits:
        recompute_habit_streaks(habit, as_of=as_of)
        rows.append(
            {
                "habit_id": habit.id,
                "title": habit.title,
                "category": habit.category,
                "current_streak": habit.current_streak,
                "longest_streak": habit.longest_streak,
                "completion_percentage": completion_percentage_for_habit(
                    habit,
                    end_date=as_of,
                ),
                "is_active": habit.is_active,
            }
        )
    return {"as_of": as_of, "habits": rows}


def parse_month(month_value: str) -> date:
    try:
        return datetime.strptime(month_value, "%Y-%m").date().replace(day=1)
    except ValueError as exc:
        raise ValueError("month must use YYYY-MM format.") from exc


def month_grid_payload(user, month_value: str) -> dict:
    first_day = parse_month(month_value)
    _, day_count = monthrange(first_day.year, first_day.month)
    days = []
    totals = {"total": 0, "completed": 0}
    for day in range(1, day_count + 1):
        target_date = first_day.replace(day=day)
        payload = today_habit_grid(user, target_date)
        totals["total"] += payload["stats"]["total"]
        totals["completed"] += payload["stats"]["completed"]
        days.append(
            {
                "date": target_date,
                "weekday": target_date.weekday(),
                "stats": payload["stats"],
                "items": payload["items"],
            }
        )
    percent = (
        0
        if totals["total"] == 0
        else round(totals["completed"] / totals["total"] * 100, 1)
    )
    return {
        "month": month_value,
        "days": days,
        "stats": {
            "total": totals["total"],
            "completed": totals["completed"],
            "remaining": totals["total"] - totals["completed"],
            "percent_complete": percent,
        },
    }


def ensure_default_habit_templates() -> None:
    for template in DEFAULT_HABIT_TEMPLATES:
        HabitTemplate.objects.update_or_create(
            title=template["title"],
            defaults=template,
        )


@transaction.atomic
def create_habit_from_template(user, template: HabitTemplate, *, start_date: date):
    return Habit.objects.create(
        user=user,
        title=template.title,
        description=template.description,
        category=template.category,
        recurrence_type=Habit.RecurrenceType.DAILY,
        recurrence=Habit.Recurrence.DAILY,
        days_of_week=[],
        target_count=template.default_target_count,
        unit=template.unit,
        icon=template.icon,
        start_date=start_date,
    )


def checklist_stats(tasks: list[DailyChecklistTask]) -> dict:
    total = len(tasks)
    completed = sum(1 for task in tasks if task.is_completed)
    percent = 0 if total == 0 else round(completed / total * 100, 1)
    return {
        "total": total,
        "completed": completed,
        "remaining": total - completed,
        "percent_complete": percent,
    }
