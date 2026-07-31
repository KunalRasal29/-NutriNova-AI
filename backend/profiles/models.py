from django.conf import settings
from django.db import models

from common.models import TimeStampedModel, UserOwnedModel


class UserProfile(TimeStampedModel):
    class DietaryPreference(models.TextChoices):
        VEGETARIAN = "vegetarian", "Vegetarian"
        VEGAN = "vegan", "Vegan"
        EGGETARIAN = "eggetarian", "Eggetarian"
        NON_VEGETARIAN = "non_vegetarian", "Non vegetarian"
        JAIN = "jain", "Jain"
        KETO = "keto", "Keto"
        HIGH_PROTEIN = "high_protein", "High protein"
        CUSTOM = "custom", "Custom"

    class GenderOptional(models.TextChoices):
        FEMALE = "female", "Female"
        MALE = "male", "Male"
        NON_BINARY = "non_binary", "Non-binary"
        OTHER = "other", "Other"
        PREFER_NOT_TO_SAY = "prefer_not_to_say", "Prefer not to say"

    class GoalType(models.TextChoices):
        LOSE_WEIGHT = "lose_weight", "Lose weight"
        MAINTAIN = "maintain", "Maintain"
        GAIN_MUSCLE = "gain_muscle", "Gain muscle"
        IMPROVE_HEALTH = "improve_health", "Improve health"

    class BiologicalSex(models.TextChoices):
        FEMALE = "female", "Female"
        MALE = "male", "Male"
        OTHER = "other", "Other"
        PREFER_NOT_TO_SAY = "prefer_not_to_say", "Prefer not to say"

    class ActivityLevel(models.TextChoices):
        SEDENTARY = "sedentary", "Sedentary"
        LIGHT = "light", "Light"
        MODERATE = "moderate", "Moderate"
        ACTIVE = "active", "Active"
        ATHLETE = "athlete", "Athlete"

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="profile",
    )
    display_name = models.CharField(max_length=160, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    gender_optional = models.CharField(
        max_length=32,
        choices=GenderOptional.choices,
        blank=True,
    )
    biological_sex = models.CharField(
        max_length=32,
        choices=BiologicalSex.choices,
        blank=True,
    )
    height_cm = models.DecimalField(
        max_digits=5, decimal_places=2, null=True, blank=True
    )
    weight_kg = models.DecimalField(
        max_digits=6, decimal_places=2, null=True, blank=True
    )
    activity_level = models.CharField(
        max_length=32,
        choices=ActivityLevel.choices,
        default=ActivityLevel.MODERATE,
    )
    goal_type = models.CharField(
        max_length=32,
        choices=GoalType.choices,
        default=GoalType.IMPROVE_HEALTH,
    )
    dietary_preference = models.CharField(
        max_length=32,
        choices=DietaryPreference.choices,
        default=DietaryPreference.CUSTOM,
    )
    allergies = models.JSONField(default=list, blank=True)
    disliked_foods = models.JSONField(default=list, blank=True)
    target_weight_kg = models.DecimalField(
        max_digits=6, decimal_places=2, null=True, blank=True
    )
    daily_calorie_target_kcal = models.DecimalField(
        max_digits=7,
        decimal_places=1,
        null=True,
        blank=True,
    )
    daily_protein_target_g = models.DecimalField(
        max_digits=6,
        decimal_places=1,
        null=True,
        blank=True,
    )
    daily_carbs_target_g = models.DecimalField(
        max_digits=6,
        decimal_places=1,
        null=True,
        blank=True,
    )
    daily_fat_target_g = models.DecimalField(
        max_digits=6,
        decimal_places=1,
        null=True,
        blank=True,
    )
    daily_fiber_target_g = models.DecimalField(
        max_digits=5,
        decimal_places=1,
        null=True,
        blank=True,
    )
    daily_water_target_ml = models.DecimalField(
        max_digits=7,
        decimal_places=1,
        null=True,
        blank=True,
    )
    nutrition_targets_customized = models.BooleanField(default=False)
    nutrition_target_method = models.CharField(max_length=64, blank=True)
    nutrition_targets_calculated_at = models.DateTimeField(null=True, blank=True)
    timezone = models.CharField(max_length=64, default="UTC")
    country = models.CharField(max_length=2, default="IN")
    has_completed_onboarding = models.BooleanField(default=False)
    onboarding_step = models.PositiveSmallIntegerField(default=0)
    locale = models.CharField(max_length=16, default="en-IN")

    class Meta:
        indexes = [
            models.Index(fields=("user", "has_completed_onboarding")),
            models.Index(fields=("country", "dietary_preference")),
        ]

    def __str__(self) -> str:
        return f"Profile for {self.user}"


class BodyMetric(UserOwnedModel):
    recorded_on = models.DateField()
    weight_kg = models.DecimalField(
        max_digits=6, decimal_places=2, null=True, blank=True
    )
    waist_cm = models.DecimalField(
        max_digits=6, decimal_places=2, null=True, blank=True
    )
    hip_cm = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True)
    chest_cm = models.DecimalField(
        max_digits=6, decimal_places=2, null=True, blank=True
    )
    body_fat_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
    )
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ("-recorded_on",)
        constraints = [
            models.UniqueConstraint(
                fields=("user", "recorded_on"),
                name="unique_body_metric_per_user_day",
            )
        ]
        indexes = [models.Index(fields=("user", "recorded_on"))]

    def __str__(self) -> str:
        return f"{self.user} metrics on {self.recorded_on}"
