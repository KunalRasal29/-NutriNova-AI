from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models

from common.models import TimeStampedModel, UserOwnedModel


class WaterIntakeEntry(UserOwnedModel):
    entry_date = models.DateField()
    amount_ml = models.PositiveIntegerField(validators=[MinValueValidator(1)])
    note = models.CharField(max_length=180, blank=True)

    class Meta:
        ordering = ("-entry_date", "-created_at")
        indexes = [models.Index(fields=("user", "entry_date"))]


class DailyActivity(UserOwnedModel):
    class ActivityType(models.TextChoices):
        WORKOUT = "workout", "Workout"
        STEPS = "steps", "Steps"

    activity_date = models.DateField()
    activity_type = models.CharField(max_length=16, choices=ActivityType.choices)
    title = models.CharField(max_length=160, blank=True)
    duration_minutes = models.PositiveIntegerField(default=0)
    steps = models.PositiveIntegerField(default=0)
    calories_burned = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)],
    )
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ("-activity_date", "-created_at")
        indexes = [
            models.Index(fields=("user", "activity_date", "activity_type")),
        ]


class ReminderPreference(TimeStampedModel):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="reminder_preference",
    )
    meal_reminders = models.BooleanField(default=False)
    meal_reminder_time = models.TimeField(null=True, blank=True)
    water_reminders = models.BooleanField(default=False)
    water_reminder_interval_minutes = models.PositiveIntegerField(default=120)
    habit_reminders = models.BooleanField(default=False)
    habit_reminder_time = models.TimeField(null=True, blank=True)
    weight_reminders = models.BooleanField(default=False)
    weight_reminder_weekday = models.PositiveSmallIntegerField(default=0)
    weekly_report = models.BooleanField(default=True)

    class Meta:
        indexes = [models.Index(fields=("user", "updated_at"))]
