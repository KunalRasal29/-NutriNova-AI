from django.contrib import admin

from photos.models import NutritionLabelScan, PhotoAnalysis, PhotoDetectedFood


class PhotoDetectedFoodInline(admin.TabularInline):
    model = PhotoDetectedFood
    extra = 0
    autocomplete_fields = ("matched_food",)
    readonly_fields = ("nutrition_preview_snapshot",)


class NutritionLabelScanInline(admin.StackedInline):
    model = NutritionLabelScan
    extra = 0
    max_num = 1


@admin.register(PhotoAnalysis)
class PhotoAnalysisAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "status",
        "analysis_type",
        "ai_provider",
        "confidence_score",
        "created_at",
    )
    list_filter = ("status", "analysis_type", "ai_provider", "created_at")
    search_fields = ("user__email", "error_message")
    readonly_fields = ("raw_ai_response", "created_at", "updated_at")
    autocomplete_fields = ("user",)
    inlines = [PhotoDetectedFoodInline, NutritionLabelScanInline]


@admin.register(PhotoDetectedFood)
class PhotoDetectedFoodAdmin(admin.ModelAdmin):
    list_display = (
        "photo_analysis",
        "detected_name",
        "matched_food",
        "grams_estimate",
        "confidence_score",
        "user_confirmed",
    )
    list_filter = (
        "user_confirmed",
        "is_user_corrected",
        "is_removed",
        "added_manually",
    )
    search_fields = (
        "detected_name",
        "normalized_name",
        "matched_food__canonical_name",
        "photo_analysis__user__email",
    )
    autocomplete_fields = ("matched_food",)
    readonly_fields = ("nutrition_preview_snapshot", "created_at", "updated_at")


@admin.register(NutritionLabelScan)
class NutritionLabelScanAdmin(admin.ModelAdmin):
    list_display = (
        "photo_analysis",
        "product_name",
        "brand",
        "barcode",
        "confidence_score",
    )
    search_fields = ("product_name", "brand", "barcode")
