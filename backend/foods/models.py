from django.conf import settings
from django.contrib.postgres.indexes import GinIndex
from django.contrib.postgres.search import SearchVector, SearchVectorField
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from common.models import TimeStampedModel, UserOwnedModel


class Food(TimeStampedModel):
    class FoodType(models.TextChoices):
        GENERIC = "generic", "Generic"
        BRANDED = "branded", "Branded"
        RESTAURANT = "restaurant", "Restaurant"
        RECIPE = "recipe", "Recipe"
        USER_CUSTOM = "user_custom", "User custom"

    canonical_name = models.CharField(max_length=255)
    brand_name = models.CharField(max_length=255, blank=True)
    description = models.TextField(blank=True)
    ingredients_text = models.TextField(blank=True)
    allergens = models.JSONField(default=list, blank=True)
    region = models.CharField(max_length=120, blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    food_type = models.CharField(
        max_length=32,
        choices=FoodType.choices,
        default=FoodType.GENERIC,
    )
    source = models.ForeignKey(
        "nutrition.NutritionDataSource",
        on_delete=models.PROTECT,
        related_name="foods",
    )
    external_id = models.CharField(max_length=180, blank=True)
    country_code = models.CharField(max_length=2, default="IN")
    language_code = models.CharField(max_length=12, default="en")
    barcode = models.CharField(max_length=64, blank=True, db_index=True)
    serving_description = models.CharField(max_length=160, blank=True)
    default_serving_g = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        null=True,
        blank=True,
    )
    data_quality_score = models.DecimalField(
        max_digits=5,
        decimal_places=4,
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(1)],
    )
    verified = models.BooleanField(default=False)
    search_text = models.TextField(blank=True)
    search_vector = SearchVectorField(null=True, blank=True, editable=False)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name="nutrition_foods",
        help_text="Null means shared catalog food. Non-null foods are scoped by user.",
    )

    class Meta:
        ordering = ("canonical_name",)
        constraints = [
            models.UniqueConstraint(
                fields=("barcode",),
                condition=~models.Q(barcode=""),
                name="unique_food_barcode_when_present",
            ),
            models.UniqueConstraint(
                fields=("source", "external_id"),
                condition=~models.Q(external_id=""),
                name="unique_food_source_external_id",
            ),
        ]
        indexes = [
            models.Index(fields=("canonical_name",)),
            models.Index(fields=("created_by", "canonical_name")),
            models.Index(fields=("source", "external_id")),
            GinIndex(fields=("search_vector",), name="food_search_vector_idx"),
            GinIndex(
                fields=("search_text",),
                name="food_search_text_trgm_idx",
                opclasses=("gin_trgm_ops",),
            ),
        ]

    def save(self, *args, **kwargs):
        self.country_code = self.country_code.upper()
        self.search_text = " ".join(
            value
            for value in (
                self.canonical_name,
                self.brand_name,
                self.description,
                self.ingredients_text,
                self.region,
                self.barcode,
            )
            if value
        ).lower()
        super().save(*args, **kwargs)
        Food.objects.filter(pk=self.pk).update(
            search_vector=(
                SearchVector("canonical_name", weight="A")
                + SearchVector("brand_name", weight="B")
                + SearchVector("description", weight="C")
                + SearchVector("barcode", weight="A")
            )
        )

    def __str__(self) -> str:
        if self.brand_name:
            return f"{self.canonical_name} ({self.brand_name})"
        return self.canonical_name


class FoodAlias(TimeStampedModel):
    food = models.ForeignKey(Food, on_delete=models.CASCADE, related_name="aliases")
    alias = models.CharField(max_length=255)
    language_code = models.CharField(max_length=12, default="en")

    class Meta:
        ordering = ("alias",)
        constraints = [
            models.UniqueConstraint(
                fields=("food", "alias", "language_code"),
                name="unique_food_alias_language",
            )
        ]
        indexes = [
            models.Index(fields=("alias",)),
            GinIndex(
                fields=("alias",),
                name="food_alias_trgm_idx",
                opclasses=("gin_trgm_ops",),
            ),
        ]

    def __str__(self) -> str:
        return self.alias


class FoodNutrient(TimeStampedModel):
    class DerivationMethod(models.TextChoices):
        LAB = "lab", "Lab"
        LABEL = "label", "Label"
        CALCULATED = "calculated", "Calculated"
        ESTIMATED = "estimated", "Estimated"
        USER_ENTERED = "user_entered", "User entered"
        AI_ESTIMATED = "ai_estimated", "AI estimated"

    food = models.ForeignKey(Food, on_delete=models.CASCADE, related_name="nutrients")
    nutrient = models.ForeignKey(
        "nutrition.Nutrient",
        on_delete=models.PROTECT,
        related_name="food_values",
    )
    amount_per_100g = models.DecimalField(max_digits=12, decimal_places=4)
    min_value = models.DecimalField(
        max_digits=12,
        decimal_places=4,
        null=True,
        blank=True,
    )
    max_value = models.DecimalField(
        max_digits=12,
        decimal_places=4,
        null=True,
        blank=True,
    )
    source = models.ForeignKey(
        "nutrition.NutritionDataSource",
        on_delete=models.PROTECT,
        related_name="food_nutrient_values",
    )
    confidence_score = models.DecimalField(
        max_digits=5,
        decimal_places=4,
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(1)],
    )
    derivation_method = models.CharField(
        max_length=32,
        choices=DerivationMethod.choices,
        default=DerivationMethod.ESTIMATED,
    )

    class Meta:
        ordering = ("food", "nutrient")
        constraints = [
            models.UniqueConstraint(
                fields=("food", "nutrient", "source", "derivation_method"),
                name="unique_food_nutrient_source_derivation",
            )
        ]
        indexes = [
            models.Index(fields=("food", "nutrient")),
            models.Index(fields=("source", "derivation_method")),
        ]

    def __str__(self) -> str:
        return f"{self.food} - {self.nutrient}"


class FoodServing(TimeStampedModel):
    food = models.ForeignKey(Food, on_delete=models.CASCADE, related_name="servings")
    serving_name = models.CharField(max_length=160)
    grams = models.DecimalField(max_digits=8, decimal_places=2)
    household_quantity = models.CharField(max_length=120, blank=True)
    is_default = models.BooleanField(default=False)

    class Meta:
        ordering = ("-is_default", "serving_name")
        constraints = [
            models.UniqueConstraint(
                fields=("food", "serving_name"),
                name="unique_food_serving_name",
            )
        ]
        indexes = [models.Index(fields=("food", "is_default"))]

    def __str__(self) -> str:
        return f"{self.serving_name} ({self.grams}g)"


class FoodDataImportJob(TimeStampedModel):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        RUNNING = "running", "Running"
        COMPLETED = "completed", "Completed"
        FAILED = "failed", "Failed"
        PARTIAL = "partial", "Partial"

    source = models.ForeignKey(
        "nutrition.NutritionDataSource",
        on_delete=models.PROTECT,
        related_name="import_jobs",
    )
    status = models.CharField(
        max_length=32,
        choices=Status.choices,
        default=Status.PENDING,
    )
    started_at = models.DateTimeField(null=True, blank=True)
    finished_at = models.DateTimeField(null=True, blank=True)
    rows_processed = models.PositiveIntegerField(default=0)
    rows_created = models.PositiveIntegerField(default=0)
    rows_updated = models.PositiveIntegerField(default=0)
    errors = models.JSONField(default=list, blank=True)
    file_name = models.CharField(max_length=255, blank=True)
    checksum = models.CharField(max_length=128, blank=True)

    class Meta:
        ordering = ("-created_at",)
        indexes = [
            models.Index(fields=("source", "status")),
            models.Index(fields=("checksum",)),
        ]

    def __str__(self) -> str:
        return f"{self.source} import {self.status}"


class FavoriteFood(UserOwnedModel):
    food = models.ForeignKey(
        Food,
        on_delete=models.CASCADE,
        related_name="favorited_by",
    )

    class Meta:
        ordering = ("-created_at",)
        constraints = [
            models.UniqueConstraint(
                fields=("user", "food"),
                name="unique_favorite_food_per_user",
            )
        ]
        indexes = [models.Index(fields=("user", "food"))]

    def __str__(self) -> str:
        return f"{self.user} favorited {self.food}"


class PantryItem(UserOwnedModel):
    class StockStatus(models.TextChoices):
        IN_STOCK = "in_stock", "In stock"
        LOW = "low", "Low"
        OUT = "out", "Out"
        EXPIRED = "expired", "Expired"

    food = models.ForeignKey(
        Food,
        on_delete=models.CASCADE,
        related_name="pantry_items",
    )
    quantity = models.DecimalField(max_digits=10, decimal_places=3, default=0)
    unit = models.CharField(max_length=32, default="serving")
    expiry_date = models.DateField(null=True, blank=True)
    stock_status = models.CharField(
        max_length=16,
        choices=StockStatus.choices,
        default=StockStatus.IN_STOCK,
    )
    location = models.CharField(max_length=80, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ("expiry_date", "food__canonical_name")
        constraints = [
            models.UniqueConstraint(
                fields=("user", "food", "location"),
                name="unique_pantry_food_location_per_user",
            )
        ]
        indexes = [
            models.Index(fields=("user", "stock_status")),
            models.Index(fields=("user", "expiry_date")),
        ]

    def __str__(self) -> str:
        return f"{self.food} in pantry for {self.user}"


class GroceryList(UserOwnedModel):
    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        COMPLETED = "completed", "Completed"
        ARCHIVED = "archived", "Archived"

    name = models.CharField(max_length=160, default="Grocery list")
    status = models.CharField(
        max_length=16,
        choices=Status.choices,
        default=Status.ACTIVE,
    )
    planned_for = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ("-created_at",)
        indexes = [
            models.Index(fields=("user", "status", "planned_for")),
        ]

    def __str__(self) -> str:
        return self.name


class GroceryListItem(TimeStampedModel):
    grocery_list = models.ForeignKey(
        GroceryList,
        on_delete=models.CASCADE,
        related_name="items",
    )
    food = models.ForeignKey(
        Food,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="grocery_list_items",
    )
    name = models.CharField(max_length=180)
    quantity = models.DecimalField(max_digits=10, decimal_places=3, default=1)
    unit = models.CharField(max_length=32, default="serving")
    is_checked = models.BooleanField(default=False)
    source = models.CharField(
        max_length=32,
        default="manual",
        help_text="manual, recipe, low_pantry, or coach_suggestion.",
    )
    sort_order = models.PositiveIntegerField(default=0)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ("is_checked", "sort_order", "name")
        indexes = [
            models.Index(fields=("grocery_list", "is_checked")),
            models.Index(fields=("food",)),
        ]

    def __str__(self) -> str:
        return self.name


class FoodCategory(TimeStampedModel):
    name = models.CharField(max_length=120, unique=True)
    slug = models.SlugField(max_length=140, unique=True)

    class Meta:
        ordering = ("name",)
        verbose_name_plural = "food categories"

    def __str__(self) -> str:
        return self.name


class FoodItem(TimeStampedModel):
    class SourceType(models.TextChoices):
        SYSTEM = "system", "System curated"
        USER = "user", "User entered"
        IMPORT = "import", "Imported database"
        BARCODE = "barcode", "Barcode provider"
        AI_ASSISTED = "ai_assisted", "AI assisted"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name="food_items",
        help_text=(
            "Null means shared public food. Non-null foods are isolated to user_id."
        ),
    )
    category = models.ForeignKey(
        FoodCategory,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="foods",
    )
    name = models.CharField(max_length=255)
    normalized_name = models.CharField(max_length=255, db_index=True)
    brand = models.CharField(max_length=255, blank=True)
    barcode = models.CharField(max_length=64, blank=True, db_index=True)
    description = models.TextField(blank=True)
    cuisine = models.CharField(max_length=80, blank=True)
    region = models.CharField(max_length=80, blank=True)
    is_indian_food = models.BooleanField(default=False)
    is_public = models.BooleanField(default=False)
    default_serving_size_g = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        null=True,
        blank=True,
    )
    default_serving_label = models.CharField(max_length=120, blank=True)
    source_type = models.CharField(
        max_length=32,
        choices=SourceType.choices,
        default=SourceType.USER,
    )
    source_name = models.CharField(max_length=255, blank=True)
    source_reference = models.CharField(max_length=512, blank=True)

    class Meta:
        ordering = ("name",)
        constraints = [
            models.UniqueConstraint(
                fields=("user", "barcode"),
                condition=~models.Q(barcode=""),
                name="unique_food_barcode_per_user",
            )
        ]
        indexes = [
            models.Index(fields=("user", "name")),
            models.Index(fields=("is_public", "name")),
            GinIndex(
                fields=("normalized_name",),
                name="food_name_trgm_idx",
                opclasses=("gin_trgm_ops",),
            ),
        ]

    def __str__(self) -> str:
        return self.name
