from django.contrib import admin

from profiles.models import BodyMetric, UserProfile


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "display_name",
        "activity_level",
        "goal_type",
        "has_completed_onboarding",
        "updated_at",
    )
    list_filter = (
        "activity_level",
        "goal_type",
        "dietary_preference",
        "has_completed_onboarding",
        "country",
    )
    search_fields = ("user__email", "user__username")
    autocomplete_fields = ("user",)
    readonly_fields = ("created_at", "updated_at")


@admin.register(BodyMetric)
class BodyMetricAdmin(admin.ModelAdmin):
    list_display = ("user", "recorded_on", "weight_kg", "body_fat_percentage")
    list_filter = ("recorded_on",)
    search_fields = ("user__email", "user__username")
    autocomplete_fields = ("user",)
    readonly_fields = ("created_at", "updated_at")
