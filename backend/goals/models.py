from django.db import models

from common.models import UserOwnedModel


class Goal(UserOwnedModel):
    class GoalType(models.TextChoices):
        CALORIES = "calories", "Calories"
        PROTEIN = "protein", "Protein"
        WATER = "water", "Water"
        WEIGHT = "weight", "Weight"
        BODY_METRIC = "body_metric", "Body metric"
        HABIT = "habit", "Habit"
        CUSTOM = "custom", "Custom"

    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        PAUSED = "paused", "Paused"
        COMPLETED = "completed", "Completed"
        ARCHIVED = "archived", "Archived"

    title = models.CharField(max_length=180)
    goal_type = models.CharField(max_length=32, choices=GoalType.choices)
    target_value = models.DecimalField(max_digits=12, decimal_places=3)
    unit = models.CharField(max_length=32)
    start_date = models.DateField()
    end_date = models.DateField(null=True, blank=True)
    status = models.CharField(
        max_length=32,
        choices=Status.choices,
        default=Status.ACTIVE,
    )
    metadata = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ("status", "end_date", "title")
        indexes = [models.Index(fields=("user", "goal_type", "status"))]

    def __str__(self) -> str:
        return self.title
