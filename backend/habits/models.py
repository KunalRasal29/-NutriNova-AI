from django.db import models

from common.models import UserOwnedModel


class Habit(UserOwnedModel):
    class Category(models.TextChoices):
        NUTRITION = "nutrition", "Nutrition"
        WORKOUT = "workout", "Workout"
        WATER = "water", "Water"
        SLEEP = "sleep", "Sleep"
        MINDFULNESS = "mindfulness", "Mindfulness"
        MEDICINE = "medicine", "Medicine"
        STUDY = "study", "Study"
        PRODUCTIVITY = "productivity", "Productivity"
        CUSTOM = "custom", "Custom"

    class Recurrence(models.TextChoices):
        DAILY = "daily", "Daily"
        WEEKDAYS = "weekdays", "Weekdays"
        WEEKLY = "weekly", "Weekly"
        CUSTOM = "custom", "Custom"

    class RecurrenceType(models.TextChoices):
        DAILY = "daily", "Daily"
        WEEKLY = "weekly", "Weekly"
        CUSTOM_DAYS = "custom_days", "Custom days"

    class Unit(models.TextChoices):
        CHECKBOX = "checkbox", "Checkbox"
        GLASSES = "glasses", "Glasses"
        MINUTES = "minutes", "Minutes"
        GRAMS = "grams", "Grams"
        STEPS = "steps", "Steps"
        PAGES = "pages", "Pages"
        CUSTOM = "custom", "Custom"

    title = models.CharField(max_length=180)
    description = models.TextField(blank=True)
    category = models.CharField(
        max_length=32,
        choices=Category.choices,
        default=Category.CUSTOM,
    )
    recurrence = models.CharField(
        max_length=32,
        choices=Recurrence.choices,
        default=Recurrence.DAILY,
    )
    recurrence_type = models.CharField(
        max_length=32,
        choices=RecurrenceType.choices,
        default=RecurrenceType.DAILY,
    )
    recurrence_rule = models.JSONField(default=dict, blank=True)
    days_of_week = models.JSONField(default=list, blank=True)
    start_date = models.DateField()
    end_date = models.DateField(null=True, blank=True)
    target_count = models.PositiveIntegerField(default=1)
    unit = models.CharField(max_length=32, choices=Unit.choices, default=Unit.CHECKBOX)
    sort_order = models.PositiveIntegerField(default=0)
    color = models.CharField(max_length=32, default="#22C55E")
    icon = models.CharField(max_length=64, default="check")
    current_streak = models.PositiveIntegerField(default=0)
    longest_streak = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ("sort_order", "title")
        indexes = [
            models.Index(fields=("user", "is_active", "sort_order")),
            models.Index(fields=("user", "category", "is_active")),
        ]

    def __str__(self) -> str:
        return self.title


class HabitCheckIn(UserOwnedModel):
    habit = models.ForeignKey(Habit, on_delete=models.CASCADE, related_name="check_ins")
    checked_on = models.DateField()
    is_completed = models.BooleanField(default=False)
    count = models.PositiveIntegerField(default=0)
    note = models.TextField(blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("-checked_on",)
        constraints = [
            models.UniqueConstraint(
                fields=("user", "habit", "checked_on"),
                name="unique_habit_checkin_per_user_day",
            )
        ]
        indexes = [models.Index(fields=("user", "checked_on", "is_completed"))]

    def __str__(self) -> str:
        return f"{self.habit} on {self.checked_on}"

    @property
    def date(self):
        return self.checked_on

    @property
    def completed_count(self):
        return self.count


class HabitCheck(HabitCheckIn):
    class Meta:
        proxy = True
        verbose_name = "habit check"
        verbose_name_plural = "habit checks"


class HabitTemplate(models.Model):
    title = models.CharField(max_length=180, unique=True)
    description = models.TextField(blank=True)
    category = models.CharField(max_length=32, choices=Habit.Category.choices)
    default_target_count = models.PositiveIntegerField(default=1)
    unit = models.CharField(max_length=32, choices=Habit.Unit.choices)
    icon = models.CharField(max_length=64, default="check")

    class Meta:
        ordering = ("category", "title")

    def __str__(self) -> str:
        return self.title


class DailyChecklistTask(UserOwnedModel):
    title = models.CharField(max_length=180)
    task_date = models.DateField()
    is_completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(null=True, blank=True)
    sort_order = models.PositiveIntegerField(default=0)
    source_habit = models.ForeignKey(
        Habit,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="daily_tasks",
    )

    class Meta:
        ordering = ("task_date", "sort_order", "created_at")
        constraints = [
            models.UniqueConstraint(
                fields=("user", "source_habit", "task_date"),
                condition=models.Q(source_habit__isnull=False),
                name="unique_generated_task_per_user_habit_day",
            )
        ]
        indexes = [models.Index(fields=("user", "task_date", "is_completed"))]

    def __str__(self) -> str:
        return self.title
