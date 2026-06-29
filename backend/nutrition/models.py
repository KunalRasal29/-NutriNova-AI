from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from common.models import TimeStampedModel


class NutritionDataSource(TimeStampedModel):
    class SourceType(models.TextChoices):
        USDA_FDC = "USDA_FDC", "USDA FoodData Central"
        OPEN_FOOD_FACTS = "OPEN_FOOD_FACTS", "Open Food Facts"
        IFCT_2017 = "IFCT_2017", "Indian Food Composition Tables 2017"
        INDB = "INDB", "Indian Nutrient Databank"
        USER_CUSTOM = "USER_CUSTOM", "User custom"
        AI_ESTIMATE = "AI_ESTIMATE", "AI estimate"
        MANUAL_ADMIN = "MANUAL_ADMIN", "Manual admin"
        MANUAL_ADMIN_SAMPLE = "MANUAL_ADMIN_SAMPLE", "Manual admin sample"

    name = models.CharField(max_length=180, unique=True)
    source_type = models.CharField(max_length=32, choices=SourceType.choices)
    license_name = models.CharField(max_length=180, blank=True)
    license_url = models.URLField(blank=True)
    citation = models.TextField(blank=True)
    source_url = models.URLField(blank=True)
    update_frequency = models.CharField(max_length=120, blank=True)
    reliability_score = models.DecimalField(
        max_digits=5,
        decimal_places=4,
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(1)],
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ("name",)
        indexes = [
            models.Index(fields=("source_type", "is_active")),
            models.Index(fields=("name",)),
        ]

    def __str__(self) -> str:
        return self.name


class Nutrient(TimeStampedModel):
    class NutrientGroup(models.TextChoices):
        MACRO = "macro", "Macro"
        VITAMIN = "vitamin", "Vitamin"
        MINERAL = "mineral", "Mineral"
        FATTY_ACID = "fatty_acid", "Fatty acid"
        AMINO_ACID = "amino_acid", "Amino acid"
        OTHER = "other", "Other"

    code = models.CharField(max_length=64, unique=True)
    name = models.CharField(max_length=160)
    unit = models.CharField(max_length=24)
    nutrient_group = models.CharField(
        max_length=32,
        choices=NutrientGroup.choices,
        default=NutrientGroup.OTHER,
    )
    recommended_daily_unit = models.CharField(max_length=24, blank=True)
    aliases = models.JSONField(default=list, blank=True)

    class Meta:
        ordering = ("nutrient_group", "name")
        indexes = [
            models.Index(fields=("code",)),
            models.Index(fields=("nutrient_group", "name")),
        ]

    def __str__(self) -> str:
        return f"{self.name} ({self.unit})"


class NutrientDefinition(TimeStampedModel):
    class Category(models.TextChoices):
        ENERGY = "energy", "Energy"
        MACRO = "macro", "Macronutrient"
        MICRO = "micro", "Micronutrient"
        OTHER = "other", "Other"

    code = models.CharField(max_length=64, unique=True)
    name = models.CharField(max_length=160)
    unit = models.CharField(max_length=24)
    category = models.CharField(
        max_length=32,
        choices=Category.choices,
        default=Category.OTHER,
    )

    class Meta:
        ordering = ("category", "name")

    def __str__(self) -> str:
        return f"{self.name} ({self.unit})"


class FoodNutrientValue(TimeStampedModel):
    class SourceType(models.TextChoices):
        LAB = "lab", "Lab analysis"
        VERIFIED_DATABASE = "verified_database", "Verified database"
        IMPORT = "import", "Imported database"
        BARCODE = "barcode", "Barcode provider"
        USER = "user", "User entered"
        AI_ESTIMATE = "ai_estimate", "AI estimate"
        RECIPE_CALCULATED = "recipe_calculated", "Recipe calculated"

    food = models.ForeignKey(
        "foods.FoodItem",
        on_delete=models.CASCADE,
        related_name="nutrient_values",
    )
    nutrient = models.ForeignKey(
        NutrientDefinition,
        on_delete=models.CASCADE,
        related_name="food_values",
    )
    amount_per_100g = models.DecimalField(max_digits=12, decimal_places=4)
    amount_per_serving = models.DecimalField(
        max_digits=12,
        decimal_places=4,
        null=True,
        blank=True,
    )
    serving_size_g = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        null=True,
        blank=True,
    )
    serving_label = models.CharField(max_length=120, blank=True)
    source_type = models.CharField(max_length=32, choices=SourceType.choices)
    source_name = models.CharField(max_length=255)
    source_reference = models.CharField(max_length=512, blank=True)
    confidence_score = models.DecimalField(
        max_digits=5,
        decimal_places=4,
        null=True,
        blank=True,
    )
    captured_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("food", "nutrient")
        constraints = [
            models.UniqueConstraint(
                fields=("food", "nutrient", "source_type", "source_name"),
                name="unique_nutrition_value_source",
            )
        ]
        indexes = [
            models.Index(fields=("food", "nutrient")),
            models.Index(fields=("source_type", "source_name")),
        ]

    def __str__(self) -> str:
        return f"{self.food} - {self.nutrient}"
