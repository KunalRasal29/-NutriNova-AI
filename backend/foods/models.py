from decimal import Decimal

from django.conf import settings
from django.contrib.postgres.indexes import GinIndex
from django.contrib.postgres.search import SearchVector, SearchVectorField
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils import timezone

from common.models import TimeStampedModel, UserOwnedModel
from foods.text import normalize_catalog_text


class Food(TimeStampedModel):
    class FoodType(models.TextChoices):
        GENERIC = "generic", "Generic"
        BRANDED = "branded", "Branded"
        RESTAURANT = "restaurant", "Restaurant"
        RECIPE = "recipe", "Recipe"
        USER_CUSTOM = "user_custom", "User custom"

    class PreparationState(models.TextChoices):
        UNSPECIFIED = "unspecified", "Not specified"
        RAW = "raw", "Raw"
        COOKED = "cooked", "Cooked"
        BOILED = "boiled", "Boiled"
        FRIED = "fried", "Fried"
        BAKED = "baked", "Baked"
        GRILLED = "grilled", "Grilled"
        ROASTED = "roasted", "Roasted"
        STEAMED = "steamed", "Steamed"
        PREPARED = "prepared", "Prepared dish"
        AS_SOLD = "as_sold", "As sold / packaged"

    class DatasetType(models.TextChoices):
        UNKNOWN = "unknown", "Unknown / not supplied"
        USDA_FOUNDATION = "usda_foundation", "USDA Foundation Foods"
        USDA_FNDDS = "usda_fndds", "USDA FNDDS"
        USDA_SR_LEGACY = "usda_sr_legacy", "USDA SR Legacy"
        USDA_BRANDED = "usda_branded", "USDA Branded Foods"
        USDA_EXPERIMENTAL = "usda_experimental", "USDA Experimental Foods"
        OPEN_FOOD_FACTS = "open_food_facts", "Open Food Facts"
        INDIAN_LICENSED = "indian_licensed", "Licensed Indian food data"
        USER_CUSTOM = "user_custom", "User custom"
        AI_ESTIMATE = "ai_estimate", "AI estimate"

    canonical_name = models.CharField(max_length=255)
    normalized_name = models.CharField(max_length=255, blank=True, db_index=True)
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
    preparation_state = models.CharField(
        max_length=20,
        choices=PreparationState.choices,
        default=PreparationState.UNSPECIFIED,
        help_text="Distinguishes raw, cooked, prepared, and packaged nutrition.",
    )
    source = models.ForeignKey(
        "nutrition.NutritionDataSource",
        on_delete=models.PROTECT,
        related_name="foods",
    )
    external_id = models.CharField(max_length=180, blank=True)
    dataset_type = models.CharField(
        max_length=32,
        choices=DatasetType.choices,
        default=DatasetType.UNKNOWN,
        db_index=True,
    )
    dataset_release = models.CharField(max_length=80, blank=True)
    imported_at = models.DateTimeField(null=True, blank=True)
    source_updated_at = models.DateTimeField(null=True, blank=True)
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
    completeness_score = models.DecimalField(
        max_digits=5,
        decimal_places=4,
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(1)],
    )
    edible_portion_percent = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        null=True,
        blank=True,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
    )
    quality_warnings = models.JSONField(default=list, blank=True)
    verified = models.BooleanField(default=False)
    is_deprecated = models.BooleanField(default=False, db_index=True)
    replacement_food = models.ForeignKey(
        "self",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="deprecated_variants",
    )
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
            models.Index(fields=("dataset_type", "dataset_release")),
            models.Index(fields=("is_deprecated", "verified", "data_quality_score")),
            models.Index(fields=("created_by", "canonical_name")),
            models.Index(fields=("source", "external_id")),
            GinIndex(fields=("search_vector",), name="food_search_vector_idx"),
            GinIndex(
                fields=("search_text",),
                name="food_search_text_trgm_idx",
                opclasses=("gin_trgm_ops",),
            ),
            GinIndex(
                fields=("normalized_name",),
                name="food_normalized_name_trgm_idx",
                opclasses=("gin_trgm_ops",),
            ),
        ]

    def save(self, *args, **kwargs):
        self.country_code = self.country_code.upper()
        self.normalized_name = normalize_catalog_text(self.canonical_name)
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
    normalized_alias = models.CharField(max_length=255, blank=True, db_index=True)
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
            GinIndex(
                fields=("normalized_alias",),
                name="food_alias_normalized_trgm_idx",
                opclasses=("gin_trgm_ops",),
            ),
        ]

    def save(self, *args, **kwargs):
        self.normalized_alias = normalize_catalog_text(self.alias)
        super().save(*args, **kwargs)

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
    original_amount = models.DecimalField(
        max_digits=16,
        decimal_places=6,
        null=True,
        blank=True,
    )
    original_unit = models.CharField(max_length=24, blank=True)
    source_nutrient_id = models.CharField(max_length=80, blank=True)
    normalization_notes = models.CharField(max_length=255, blank=True)
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


class CustomFoodProfile(UserOwnedModel):
    class Status(models.TextChoices):
        DRAFT = "draft", "Draft"
        ESTIMATE_READY = "estimate_ready", "Estimate ready"
        NEEDS_REVIEW = "needs_review", "Needs review"
        CONFIRMED = "confirmed", "Confirmed"
        ARCHIVED = "archived", "Archived"

    class EstimationMethod(models.TextChoices):
        NONE = "none", "Not estimated"
        DATABASE_MATCHES = "database_matches", "Trusted database matches"
        INGREDIENT_SUM = "ingredient_sum", "Ingredient nutrition sum"
        MANUAL_ENTRY = "manual_entry", "Manual user entry"

    food = models.OneToOneField(
        Food,
        on_delete=models.CASCADE,
        related_name="custom_profile",
    )
    status = models.CharField(
        max_length=24,
        choices=Status.choices,
        default=Status.DRAFT,
        db_index=True,
    )
    serving_quantity = models.DecimalField(
        max_digits=10,
        decimal_places=3,
        default=1,
        validators=[MinValueValidator(Decimal("0.001"))],
    )
    serving_unit = models.CharField(max_length=32, default="serving")
    serving_weight_g = models.DecimalField(
        max_digits=10,
        decimal_places=3,
        validators=[MinValueValidator(Decimal("0.001"))],
    )
    estimation_method = models.CharField(
        max_length=32,
        choices=EstimationMethod.choices,
        default=EstimationMethod.NONE,
    )
    original_estimated_nutrients = models.JSONField(default=dict, blank=True)
    estimated_nutrients = models.JSONField(default=dict, blank=True)
    estimated_range = models.JSONField(default=dict, blank=True)
    confirmed_nutrients = models.JSONField(default=dict, blank=True)
    reference_foods = models.JSONField(default=list, blank=True)
    ingredients = models.JSONField(default=list, blank=True)
    confidence_score = models.DecimalField(
        max_digits=5,
        decimal_places=4,
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(1)],
    )
    user_corrections = models.JSONField(default=dict, blank=True)
    warnings = models.JSONField(default=list, blank=True)
    calculated_calories_kcal = models.DecimalField(
        max_digits=12,
        decimal_places=4,
        null=True,
        blank=True,
    )
    confirmed_at = models.DateTimeField(null=True, blank=True)
    version_number = models.PositiveIntegerField(default=1)

    class Meta:
        ordering = ("-updated_at",)
        indexes = [
            models.Index(fields=("user", "status")),
            models.Index(fields=("user", "updated_at")),
        ]

    def __str__(self) -> str:
        return f"{self.food} ({self.status})"


class CustomFoodVersion(UserOwnedModel):
    food = models.ForeignKey(
        Food,
        on_delete=models.CASCADE,
        related_name="custom_versions",
    )
    version = models.PositiveIntegerField()
    event = models.CharField(max_length=32)
    status = models.CharField(max_length=24, choices=CustomFoodProfile.Status.choices)
    snapshot = models.JSONField(default=dict)

    class Meta:
        ordering = ("-version",)
        constraints = [
            models.UniqueConstraint(
                fields=("food", "version"),
                name="unique_custom_food_version",
            )
        ]
        indexes = [
            models.Index(fields=("user", "food", "version")),
        ]

    def __str__(self) -> str:
        return f"{self.food} v{self.version} ({self.event})"


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
    rows_skipped = models.PositiveIntegerField(default=0)
    errors = models.JSONField(default=list, blank=True)
    file_name = models.CharField(max_length=255, blank=True)
    checksum = models.CharField(max_length=128, blank=True)
    dataset_type = models.CharField(max_length=32, blank=True, db_index=True)
    release_version = models.CharField(max_length=80, blank=True)
    resume_offset = models.PositiveBigIntegerField(default=0)
    metadata = models.JSONField(default=dict, blank=True)

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


class UserPortionPreference(UserOwnedModel):
    food = models.ForeignKey(
        Food,
        on_delete=models.CASCADE,
        related_name="user_portion_preferences",
    )
    unit = models.CharField(max_length=32)
    grams_per_unit = models.DecimalField(max_digits=10, decimal_places=3)
    times_used = models.PositiveIntegerField(default=1)
    last_used_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ("-last_used_at",)
        constraints = [
            models.UniqueConstraint(
                fields=("user", "food", "unit"),
                name="unique_portion_preference_per_user_food_unit",
            )
        ]
        indexes = [
            models.Index(fields=("user", "food", "unit")),
            models.Index(fields=("user", "last_used_at")),
        ]

    def __str__(self) -> str:
        return f"{self.user}: {self.grams_per_unit}g per {self.unit} of {self.food}"


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
