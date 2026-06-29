from django.contrib import admin

from goals.models import Goal


@admin.register(Goal)
class GoalAdmin(admin.ModelAdmin):
    list_display = ("user", "goal_type", "target_value", "unit", "status")
    list_filter = ("goal_type", "status")
    search_fields = ("user__email", "title")
