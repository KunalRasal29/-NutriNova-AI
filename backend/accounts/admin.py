from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from accounts.models import User


@admin.register(User)
class NutriNovaUserAdmin(UserAdmin):
    fieldsets = UserAdmin.fieldsets + (
        (
            "NutriNova",
            {
                "fields": (
                    "timezone",
                    "is_terms_accepted",
                    "terms_accepted_at",
                    "created_at",
                    "updated_at",
                )
            },
        ),
    )
    readonly_fields = ("created_at", "updated_at")
    list_display = ("username", "email", "is_staff", "is_active", "created_at")
    list_filter = ("is_staff", "is_active", "is_terms_accepted", "created_at")
    search_fields = ("username", "email")
