from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils import timezone

from common.models import UserOwnedModel


class MealLog(UserOwnedModel):
    class MealType(models.TextChoices):
        BREAKFAST = "breakfast", "Breakfast"
        LUNCH = "lunch", "Lunch"
        DINNER = "dinner", "Dinner"
        SNACK = "snack", "Snack"
        PRE_WORKOUT = "pre_workout", "Pre-workout"
        POST_WORKOUT = "post_workout", "Post-workout"
        CUSTOM = "custom", "Custom"

    date = models.DateField()
    meal_type = models.CharField(
        max_length=32,
        choices=MealType.choices,
        default=MealType.CUSTOM,
    )
    name = models.CharField(max_length=160, blank=True)
    notes = models.TextField(blank=True)
    timezone = models.CharField(max_length=64, default="UTC")
    is_favorite = models.BooleanField(default=False)

    class Meta:
        ordering = ("-date", "meal_type", "created_at")
        indexes = [
            models.Index(fields=("user", "date", "meal_type")),
            models.Index(fields=("user", "is_favorite")),
        ]

    def __str__(self) -> str:
        return self.name or f"{self.meal_type} on {self.date}"


class MealLogItem(UserOwnedModel):
    class Unit(models.TextChoices):
        GRAMS = "grams", "Grams"
        SERVING = "serving", "Serving"
        PIECE = "piece", "Piece"
        ML = "ml", "Milliliter"
        CUP = "cup", "Cup"
        TBSP = "tbsp", "Tablespoon"
        TSP = "tsp", "Teaspoon"
        CUSTOM = "custom", "Custom"

    meal_log = models.ForeignKey(
        MealLog,
        on_delete=models.CASCADE,
        related_name="items",
    )
    food = models.ForeignKey(
        "foods.Food",
        on_delete=models.PROTECT,
        related_name="meal_log_items",
    )
    quantity = models.DecimalField(max_digits=10, decimal_places=3)
    unit = models.CharField(max_length=32, choices=Unit.choices, default=Unit.GRAMS)
    grams_calculated = models.DecimalField(max_digits=10, decimal_places=3)
    serving = models.ForeignKey(
        "foods.FoodServing",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="meal_log_items",
    )
    calories_kcal = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    macros_snapshot = models.JSONField(default=dict, blank=True)
    nutrients_snapshot = models.JSONField(default=dict, blank=True)
    source_confidence = models.DecimalField(
        max_digits=5,
        decimal_places=4,
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(1)],
    )
    user_confirmed = models.BooleanField(default=True)

    class Meta:
        ordering = ("created_at",)
        indexes = [
            models.Index(fields=("user", "meal_log")),
            models.Index(fields=("user", "food")),
        ]

    def __str__(self) -> str:
        return f"{self.grams_calculated}g {self.food} for {self.meal_log_id}"


class DailyNutritionSummary(UserOwnedModel):
    date = models.DateField()
    calories_kcal = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    protein_g = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    carbs_g = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    fat_g = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    fiber_g = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    sugar_g = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    sodium_mg = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    micronutrients = models.JSONField(default=dict, blank=True)
    generated_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ("-date",)
        constraints = [
            models.UniqueConstraint(
                fields=("user", "date"),
                name="unique_daily_nutrition_summary_per_user_date",
            )
        ]
        indexes = [models.Index(fields=("user", "date"))]

    def __str__(self) -> str:
        return f"{self.user} nutrition summary for {self.date}"
