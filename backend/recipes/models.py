from django.db import models

from common.models import UserOwnedModel


class Recipe(UserOwnedModel):
    class Visibility(models.TextChoices):
        PRIVATE = "private", "Private"
        SHARED_FAMILY = "shared_family", "Shared family"
        PUBLIC = "public", "Public"

    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    servings = models.DecimalField(max_digits=8, decimal_places=2, default=1)
    total_weight_g = models.DecimalField(max_digits=10, decimal_places=3, default=0)
    visibility = models.CharField(
        max_length=32,
        choices=Visibility.choices,
        default=Visibility.PRIVATE,
    )
    instructions = models.TextField(blank=True)
    cuisine = models.CharField(max_length=120, blank=True)
    tags = models.JSONField(default=list, blank=True)

    class Meta:
        ordering = ("name",)
        indexes = [
            models.Index(fields=("user", "name")),
            models.Index(fields=("user", "visibility")),
        ]

    def __str__(self) -> str:
        return self.name


class RecipeIngredient(UserOwnedModel):
    class Unit(models.TextChoices):
        GRAMS = "grams", "Grams"
        SERVING = "serving", "Serving"
        PIECE = "piece", "Piece"
        ML = "ml", "Milliliter"
        CUP = "cup", "Cup"
        TBSP = "tbsp", "Tablespoon"
        TSP = "tsp", "Teaspoon"
        CUSTOM = "custom", "Custom"

    recipe = models.ForeignKey(
        Recipe,
        on_delete=models.CASCADE,
        related_name="ingredients",
    )
    food = models.ForeignKey(
        "foods.Food",
        on_delete=models.PROTECT,
        related_name="recipe_ingredients",
    )
    quantity = models.DecimalField(max_digits=10, decimal_places=3, default=0)
    unit = models.CharField(max_length=32, choices=Unit.choices, default=Unit.GRAMS)
    grams_calculated = models.DecimalField(max_digits=10, decimal_places=3, default=0)
    serving = models.ForeignKey(
        "foods.FoodServing",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="recipe_ingredients",
    )

    class Meta:
        ordering = ("created_at",)
        indexes = [models.Index(fields=("user", "recipe"))]

    def __str__(self) -> str:
        return f"{self.grams_calculated}g {self.food}"
