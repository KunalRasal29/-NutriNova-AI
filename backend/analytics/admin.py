from django.contrib import admin

from analytics.models import CoachInsight, DailyNutritionSummary


@admin.register(DailyNutritionSummary)
class DailyNutritionSummaryAdmin(admin.ModelAdmin):
    list_display = ("user", "summary_date", "calories_kcal", "protein_g", "water_ml")
    list_filter = ("summary_date",)
    search_fields = ("user__email",)


@admin.register(CoachInsight)
class CoachInsightAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "title",
        "insight_type",
        "severity",
        "status",
        "confidence_score",
        "related_date",
        "created_at",
    )
    list_filter = ("insight_type", "severity", "status", "source", "related_date")
    search_fields = ("user__email", "title", "message", "source")
    readonly_fields = ("created_at", "updated_at")
