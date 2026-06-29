from django.db import models

from common.models import UserOwnedModel


class IntegrationAccount(UserOwnedModel):
    provider = models.CharField(max_length=80)
    external_user_id = models.CharField(max_length=180, blank=True)
    token_reference = models.CharField(
        max_length=255,
        blank=True,
        help_text="Reference to encrypted secret storage; never store raw tokens here.",
    )
    scopes = models.JSONField(default=list, blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ("provider",)
        constraints = [
            models.UniqueConstraint(
                fields=("user", "provider", "external_user_id"),
                name="unique_integration_account_per_provider_user",
            )
        ]
        indexes = [models.Index(fields=("user", "provider", "is_active"))]

    def __str__(self) -> str:
        return f"{self.provider} for {self.user}"
