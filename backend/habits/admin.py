from django.contrib import admin

from habits.models import DailyChecklistTask, Habit, HabitCheckIn, HabitTemplate


@admin.register(Habit)
class HabitAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "title",
        "category",
        "recurrence_type",
        "target_count",
        "unit",
        "current_streak",
        "is_active",
    )
    list_filter = ("category", "recurrence_type", "unit", "is_active")
    search_fields = ("user__email", "title", "description")
    autocomplete_fields = ("user",)
    readonly_fields = ("created_at", "updated_at")


@admin.register(HabitCheckIn)
class HabitCheckInAdmin(admin.ModelAdmin):
    list_display = ("user", "habit", "checked_on", "is_completed", "count")
    list_filter = ("is_completed", "checked_on")
    search_fields = ("user__email", "habit__title")
    autocomplete_fields = ("user", "habit")
    readonly_fields = ("created_at", "updated_at")


@admin.register(DailyChecklistTask)
class DailyChecklistTaskAdmin(admin.ModelAdmin):
    list_display = ("user", "title", "task_date", "is_completed", "completed_at")
    list_filter = ("task_date", "is_completed")
    search_fields = ("user__email", "title")
    autocomplete_fields = ("user", "source_habit")
    readonly_fields = ("created_at", "updated_at")


@admin.register(HabitTemplate)
class HabitTemplateAdmin(admin.ModelAdmin):
    list_display = ("title", "category", "default_target_count", "unit", "icon")
    list_filter = ("category", "unit")
    search_fields = ("title", "description", "icon")
