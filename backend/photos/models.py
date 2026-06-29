from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from common.models import TimeStampedModel, UserOwnedModel


class PhotoAnalysis(UserOwnedModel):
    class Status(models.TextChoices):
        UPLOADED = "uploaded", "Uploaded"
        PROCESSING = "processing", "Processing"
        NEEDS_REVIEW = "needs_review", "Needs review"
        CONFIRMED = "confirmed", "Confirmed"
        FAILED = "failed", "Failed"

    class AnalysisType(models.TextChoices):
        MEAL_PHOTO = "meal_photo", "Meal photo"
        NUTRITION_LABEL = "nutrition_label", "Nutrition label"
        BARCODE_PHOTO = "barcode_photo", "Barcode photo"

    class AIProvider(models.TextChoices):
        OPENAI = "openai", "OpenAI"
        GOOGLE_VISION = "google_vision", "Google Vision"
        LOCAL_MODEL = "local_model", "Local model"
        MANUAL = "manual", "Manual"

    image = models.ImageField(upload_to="photo-analyses/%Y/%m/%d/")
    status = models.CharField(
        max_length=32,
        choices=Status.choices,
        default=Status.UPLOADED,
    )
    analysis_type = models.CharField(
        max_length=32,
        choices=AnalysisType.choices,
        default=AnalysisType.MEAL_PHOTO,
    )
    ai_provider = models.CharField(
        max_length=32,
        choices=AIProvider.choices,
        default=AIProvider.LOCAL_MODEL,
    )
    raw_ai_response = models.JSONField(default=dict, blank=True)
    confidence_score = models.DecimalField(
        max_digits=5,
        decimal_places=4,
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(1)],
    )
    error_message = models.TextField(blank=True)

    class Meta:
        ordering = ("-created_at",)
        indexes = [
            models.Index(fields=("user", "status", "created_at")),
            models.Index(fields=("user", "analysis_type", "created_at")),
        ]

    def __str__(self) -> str:
        return f"{self.status} photo analysis for {self.user}"


class PhotoDetectedFood(TimeStampedModel):
    class QuantityUnit(models.TextChoices):
        PIECE = "piece", "Piece"
        EGG = "egg", "Egg"
        SLICE = "slice", "Slice"
        BOWL = "bowl", "Bowl"
        CUP = "cup", "Cup"
        GLASS = "glass", "Glass"
        TABLESPOON = "tablespoon", "Tablespoon"
        TEASPOON = "teaspoon", "Teaspoon"
        SERVING = "serving", "Serving"
        GRAM = "gram", "Gram"
        ML = "ml", "Milliliter"
        HANDFUL = "handful", "Handful"
        SCOOP = "scoop", "Scoop"
        PACKET = "packet", "Packet"
        CUSTOM = "custom", "Custom"

    photo_analysis = models.ForeignKey(
        PhotoAnalysis,
        on_delete=models.CASCADE,
        related_name="detected_foods",
    )
    detected_name = models.CharField(max_length=255)
    normalized_name = models.CharField(max_length=255, blank=True)
    matched_food = models.ForeignKey(
        "foods.Food",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="photo_detections",
    )
    quantity_estimate = models.DecimalField(max_digits=10, decimal_places=3, default=1)
    unit_estimate = models.CharField(max_length=32, default="serving")
    quantity_value = models.DecimalField(
        max_digits=10,
        decimal_places=3,
        null=True,
        blank=True,
    )
    quantity_unit = models.CharField(
        max_length=32,
        choices=QuantityUnit.choices,
        null=True,
        blank=True,
    )
    grams_estimate = models.DecimalField(
        max_digits=10,
        decimal_places=3,
        null=True,
        blank=True,
    )
    grams_per_unit_estimate = models.DecimalField(
        max_digits=10,
        decimal_places=3,
        null=True,
        blank=True,
    )
    total_grams_estimate = models.DecimalField(
        max_digits=10,
        decimal_places=3,
        null=True,
        blank=True,
    )
    min_total_grams_estimate = models.DecimalField(
        max_digits=10,
        decimal_places=3,
        null=True,
        blank=True,
    )
    max_total_grams_estimate = models.DecimalField(
        max_digits=10,
        decimal_places=3,
        null=True,
        blank=True,
    )
    confidence_score = models.DecimalField(
        max_digits=5,
        decimal_places=4,
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(1)],
    )
    count_confidence = models.DecimalField(
        max_digits=5,
        decimal_places=4,
        null=True,
        blank=True,
        validators=[MinValueValidator(0), MaxValueValidator(1)],
    )
    portion_confidence = models.DecimalField(
        max_digits=5,
        decimal_places=4,
        null=True,
        blank=True,
        validators=[MinValueValidator(0), MaxValueValidator(1)],
    )
    bounding_box = models.JSONField(default=dict, blank=True)
    user_confirmed = models.BooleanField(default=False)
    user_corrected_name = models.CharField(max_length=255, blank=True)
    user_quantity_value = models.DecimalField(
        max_digits=10,
        decimal_places=3,
        null=True,
        blank=True,
    )
    user_quantity_unit = models.CharField(
        max_length=32,
        choices=QuantityUnit.choices,
        null=True,
        blank=True,
    )
    user_corrected_grams = models.DecimalField(
        max_digits=10,
        decimal_places=3,
        null=True,
        blank=True,
    )
    user_total_grams = models.DecimalField(
        max_digits=10,
        decimal_places=3,
        null=True,
        blank=True,
    )
    is_user_corrected = models.BooleanField(default=False)
    is_removed = models.BooleanField(default=False)
    correction_note = models.TextField(blank=True)
    nutrition_preview_snapshot = models.JSONField(default=dict, blank=True)
    added_manually = models.BooleanField(default=False)
    reasoning_short = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ("-confidence_score", "detected_name")
        indexes = [
            models.Index(fields=("photo_analysis", "user_confirmed")),
            models.Index(fields=("photo_analysis", "is_removed")),
            models.Index(fields=("matched_food",)),
            models.Index(fields=("normalized_name",)),
        ]

    def __str__(self) -> str:
        return self.detected_name


class NutritionLabelScan(TimeStampedModel):
    photo_analysis = models.OneToOneField(
        PhotoAnalysis,
        on_delete=models.CASCADE,
        related_name="nutrition_label_scan",
    )
    product_name = models.CharField(max_length=255, blank=True)
    brand = models.CharField(max_length=255, blank=True)
    serving_size = models.CharField(max_length=120, blank=True)
    barcode = models.CharField(max_length=64, blank=True)
    parsed_nutrients = models.JSONField(default=dict, blank=True)
    ingredients_text = models.TextField(blank=True)
    allergens = models.JSONField(default=list, blank=True)
    confidence_score = models.DecimalField(
        max_digits=5,
        decimal_places=4,
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(1)],
    )

    class Meta:
        indexes = [
            models.Index(fields=("barcode",)),
            models.Index(fields=("product_name", "brand")),
        ]

    def __str__(self) -> str:
        return self.product_name or f"Label scan for {self.photo_analysis_id}"
