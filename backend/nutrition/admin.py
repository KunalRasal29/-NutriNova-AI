from django.contrib import admin

from nutrition.models import (
    FoodNutrientValue,
    Nutrient,
    NutrientDefinition,
    NutritionDataSource,
)


@admin.register(NutritionDataSource)
class NutritionDataSourceAdmin(admin.ModelAdmin):
    list_display = ("name", "source_type", "reliability_score", "is_active")
    list_filter = ("source_type", "is_active")
    search_fields = ("name", "citation", "source_url")
    readonly_fields = ("created_at", "updated_at")


@admin.register(Nutrient)
class NutrientAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "unit", "nutrient_group")
    list_filter = ("nutrient_group", "unit")
    search_fields = ("code", "name", "aliases")
    readonly_fields = ("created_at", "updated_at")


@admin.register(NutrientDefinition)
class NutrientDefinitionAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "unit", "category")
    list_filter = ("category", "unit")
    search_fields = ("code", "name")


@admin.register(FoodNutrientValue)
class FoodNutrientValueAdmin(admin.ModelAdmin):
    list_display = ("food", "nutrient", "amount_per_100g", "source_type", "source_name")
    list_filter = ("source_type", "nutrient__category")
    search_fields = ("food__name", "nutrient__name", "source_name")
