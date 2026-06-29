from django.contrib import admin

from recipes.models import Recipe, RecipeIngredient


class RecipeIngredientInline(admin.TabularInline):
    model = RecipeIngredient
    extra = 0
    autocomplete_fields = ("food", "serving")


@admin.register(Recipe)
class RecipeAdmin(admin.ModelAdmin):
    list_display = ("name", "user", "servings", "visibility", "cuisine", "updated_at")
    list_filter = ("visibility", "cuisine", "created_at", "updated_at")
    search_fields = ("name", "user__email", "description", "tags")
    autocomplete_fields = ("user",)
    readonly_fields = ("created_at", "updated_at")
    inlines = [RecipeIngredientInline]
