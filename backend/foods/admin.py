from django.contrib import admin

from foods.models import (
    CustomFoodProfile,
    CustomFoodVersion,
    FavoriteFood,
    Food,
    FoodAlias,
    FoodCategory,
    FoodDataImportJob,
    FoodItem,
    FoodNutrient,
    FoodServing,
    GroceryList,
    GroceryListItem,
    PantryItem,
    UserPortionPreference,
)


class FoodAliasInline(admin.TabularInline):
    model = FoodAlias
    extra = 0


class FoodNutrientInline(admin.TabularInline):
    model = FoodNutrient
    extra = 0


class FoodServingInline(admin.TabularInline):
    model = FoodServing
    extra = 0


class GroceryListItemInline(admin.TabularInline):
    model = GroceryListItem
    extra = 0
    autocomplete_fields = ("food",)


@admin.register(Food)
class FoodAdmin(admin.ModelAdmin):
    list_display = (
        "canonical_name",
        "brand_name",
        "source",
        "food_type",
        "preparation_state",
        "dataset_type",
        "dataset_release",
        "country_code",
        "verified",
        "is_deprecated",
        "completeness_score",
        "data_quality_score",
        "created_by",
        "created_at",
    )
    list_filter = (
        "food_type",
        "preparation_state",
        "dataset_type",
        "source",
        "country_code",
        "verified",
        "is_deprecated",
        "created_at",
    )
    search_fields = (
        "canonical_name",
        "brand_name",
        "barcode",
        "external_id",
        "created_by__email",
    )
    autocomplete_fields = ("source", "created_by", "replacement_food")
    inlines = [FoodAliasInline, FoodServingInline, FoodNutrientInline]
    readonly_fields = (
        "normalized_name",
        "search_text",
        "imported_at",
        "created_at",
        "updated_at",
    )
    actions = ("deprecate_selected", "restore_selected")

    @admin.action(
        description="Mark selected foods deprecated (references are preserved)"
    )
    def deprecate_selected(self, request, queryset):
        queryset.update(is_deprecated=True)

    @admin.action(description="Restore selected foods to active search")
    def restore_selected(self, request, queryset):
        queryset.update(is_deprecated=False, replacement_food=None)


@admin.register(CustomFoodProfile)
class CustomFoodProfileAdmin(admin.ModelAdmin):
    list_display = (
        "food",
        "user",
        "status",
        "estimation_method",
        "confidence_score",
        "version_number",
        "confirmed_at",
        "updated_at",
    )
    list_filter = ("status", "estimation_method", "confirmed_at")
    search_fields = ("food__canonical_name", "food__brand_name", "user__email")
    autocomplete_fields = ("food", "user")
    readonly_fields = ("created_at", "updated_at", "confirmed_at")


@admin.register(CustomFoodVersion)
class CustomFoodVersionAdmin(admin.ModelAdmin):
    list_display = ("food", "user", "version", "event", "status", "created_at")
    list_filter = ("event", "status", "created_at")
    search_fields = ("food__canonical_name", "user__email")
    autocomplete_fields = ("food", "user")
    readonly_fields = ("snapshot", "created_at", "updated_at")


@admin.register(FoodDataImportJob)
class FoodDataImportJobAdmin(admin.ModelAdmin):
    list_display = (
        "source",
        "status",
        "rows_processed",
        "rows_created",
        "rows_updated",
        "rows_skipped",
        "dataset_type",
        "release_version",
        "resume_offset",
        "created_at",
    )
    list_filter = ("source", "status", "dataset_type", "created_at")
    search_fields = ("file_name", "checksum")
    readonly_fields = (
        "started_at",
        "finished_at",
        "rows_processed",
        "rows_created",
        "rows_updated",
        "rows_skipped",
        "resume_offset",
        "errors",
        "metadata",
        "created_at",
        "updated_at",
    )


@admin.register(FavoriteFood)
class FavoriteFoodAdmin(admin.ModelAdmin):
    list_display = ("user", "food", "created_at")
    search_fields = ("user__email", "food__canonical_name")
    autocomplete_fields = ("user", "food")


@admin.register(UserPortionPreference)
class UserPortionPreferenceAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "food",
        "unit",
        "grams_per_unit",
        "times_used",
        "last_used_at",
    )
    search_fields = ("user__email", "food__canonical_name", "unit")
    autocomplete_fields = ("user", "food")
    readonly_fields = ("times_used", "last_used_at", "created_at", "updated_at")


@admin.register(FoodCategory)
class FoodCategoryAdmin(admin.ModelAdmin):
    list_display = ("name", "slug", "created_at")
    search_fields = ("name", "slug")


@admin.register(FoodItem)
class FoodItemAdmin(admin.ModelAdmin):
    list_display = ("name", "brand", "user", "is_public", "is_indian_food")
    list_filter = ("is_public", "is_indian_food", "cuisine")
    search_fields = ("name", "normalized_name", "brand", "barcode")


@admin.register(FoodAlias)
class FoodAliasAdmin(admin.ModelAdmin):
    list_display = ("food", "alias", "language_code")
    list_filter = ("language_code",)
    search_fields = ("food__canonical_name", "alias")
    autocomplete_fields = ("food",)
    readonly_fields = ("created_at", "updated_at")


@admin.register(FoodServing)
class FoodServingAdmin(admin.ModelAdmin):
    list_display = ("food", "serving_name", "grams", "household_quantity", "is_default")
    list_filter = ("is_default",)
    search_fields = ("food__canonical_name", "serving_name", "household_quantity")
    autocomplete_fields = ("food",)
    readonly_fields = ("created_at", "updated_at")


@admin.register(FoodNutrient)
class FoodNutrientAdmin(admin.ModelAdmin):
    list_display = (
        "food",
        "nutrient",
        "amount_per_100g",
        "original_amount",
        "original_unit",
        "source",
        "confidence_score",
        "derivation_method",
    )
    list_filter = ("source", "derivation_method", "nutrient__nutrient_group")
    search_fields = ("food__canonical_name", "nutrient__code", "nutrient__name")
    autocomplete_fields = ("food", "nutrient", "source")
    readonly_fields = (
        "original_amount",
        "original_unit",
        "source_nutrient_id",
        "normalization_notes",
        "created_at",
        "updated_at",
    )


@admin.register(PantryItem)
class PantryItemAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "food",
        "quantity",
        "unit",
        "stock_status",
        "expiry_date",
        "location",
    )
    list_filter = ("stock_status", "expiry_date", "location")
    search_fields = ("user__email", "food__canonical_name", "location", "notes")
    autocomplete_fields = ("user", "food")
    readonly_fields = ("created_at", "updated_at")


@admin.register(GroceryList)
class GroceryListAdmin(admin.ModelAdmin):
    list_display = ("user", "name", "status", "planned_for", "created_at")
    list_filter = ("status", "planned_for", "created_at")
    search_fields = ("user__email", "name", "notes")
    autocomplete_fields = ("user",)
    readonly_fields = ("created_at", "updated_at")
    inlines = [GroceryListItemInline]


@admin.register(GroceryListItem)
class GroceryListItemAdmin(admin.ModelAdmin):
    list_display = (
        "grocery_list",
        "name",
        "food",
        "quantity",
        "unit",
        "is_checked",
        "source",
    )
    list_filter = ("is_checked", "source", "created_at")
    search_fields = (
        "grocery_list__user__email",
        "grocery_list__name",
        "name",
        "food__canonical_name",
    )
    autocomplete_fields = ("grocery_list", "food")
    readonly_fields = ("created_at", "updated_at")
