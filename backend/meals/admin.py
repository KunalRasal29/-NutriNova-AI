from django.contrib import admin

from meals.models import DailyNutritionSummary, MealLog, MealLogItem


class MealLogItemInline(admin.TabularInline):
    model = MealLogItem
    extra = 0
    readonly_fields = ("calories_kcal", "macros_snapshot", "nutrients_snapshot")
    autocomplete_fields = ("food", "serving")


@admin.register(MealLog)
class MealLogAdmin(admin.ModelAdmin):
    list_display = ("user", "date", "meal_type", "name", "is_favorite", "created_at")
    list_filter = ("meal_type", "date", "is_favorite", "created_at")
    search_fields = ("user__email", "name", "notes")
    autocomplete_fields = ("user",)
    readonly_fields = ("created_at", "updated_at")
    inlines = [MealLogItemInline]


@admin.register(MealLogItem)
class MealLogItemAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "meal_log",
        "food",
        "quantity",
        "unit",
        "grams_calculated",
        "calories_kcal",
    )
    list_filter = ("unit", "user_confirmed", "created_at")
    search_fields = ("user__email", "food__canonical_name", "meal_log__name")
    autocomplete_fields = ("user", "meal_log", "food", "serving")
    readonly_fields = (
        "calories_kcal",
        "macros_snapshot",
        "nutrients_snapshot",
        "created_at",
        "updated_at",
    )


@admin.register(DailyNutritionSummary)
class DailyNutritionSummaryAdmin(admin.ModelAdmin):
    list_display = ("user", "date", "calories_kcal", "protein_g", "generated_at")
    list_filter = ("date",)
    search_fields = ("user__email",)
    autocomplete_fields = ("user",)
