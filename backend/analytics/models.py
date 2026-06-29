from django.db import models

from common.models import UserOwnedModel


class DailyNutritionSummary(UserOwnedModel):
    summary_date = models.DateField()
    calories_kcal = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    protein_g = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    carbohydrates_g = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    fat_g = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    fiber_g = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    sugar_g = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    sodium_mg = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    water_ml = models.PositiveIntegerField(default=0)
    insights = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ("-summary_date",)
        constraints = [
            models.UniqueConstraint(
                fields=("user", "summary_date"),
                name="unique_daily_nutrition_summary_per_user",
            )
        ]
        indexes = [models.Index(fields=("user", "summary_date"))]

    def __str__(self) -> str:
        return f"{self.user} summary for {self.summary_date}"


class CoachInsight(UserOwnedModel):
    class InsightType(models.TextChoices):
        NUTRITION = "nutrition", "Nutrition"
        HABIT = "habit", "Habit"
        WEIGHT = "weight", "Weight"
        RECOVERY = "recovery", "Recovery"
        ADHERENCE = "adherence", "Adherence"
        SAFETY = "safety", "Safety"
        CUSTOM = "custom", "Custom"

    class Severity(models.TextChoices):
        INFO = "info", "Info"
        SUCCESS = "success", "Success"
        WARNING = "warning", "Warning"
        CRITICAL = "critical", "Critical"

    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        DISMISSED = "dismissed", "Dismissed"
        EXPIRED = "expired", "Expired"

    insight_type = models.CharField(
        max_length=32,
        choices=InsightType.choices,
        default=InsightType.NUTRITION,
    )
    title = models.CharField(max_length=180)
    message = models.TextField()
    severity = models.CharField(
        max_length=16,
        choices=Severity.choices,
        default=Severity.INFO,
    )
    status = models.CharField(
        max_length=16,
        choices=Status.choices,
        default=Status.ACTIVE,
    )
    source = models.CharField(
        max_length=64,
        default="rules_engine",
        help_text="rules_engine, ai_estimate, coach_admin, or integration name.",
    )
    confidence_score = models.DecimalField(max_digits=5, decimal_places=4, default=0)
    related_date = models.DateField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    metadata = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ("-created_at",)
        indexes = [
            models.Index(fields=("user", "status", "created_at")),
            models.Index(fields=("user", "insight_type", "related_date")),
        ]

    def __str__(self) -> str:
        return self.title
