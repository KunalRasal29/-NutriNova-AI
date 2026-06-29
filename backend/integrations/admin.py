from django.contrib import admin

from integrations.models import IntegrationAccount


@admin.register(IntegrationAccount)
class IntegrationAccountAdmin(admin.ModelAdmin):
    list_display = ("user", "provider", "external_user_id", "is_active", "updated_at")
    list_filter = ("provider", "is_active")
    search_fields = ("user__email", "provider", "external_user_id")
