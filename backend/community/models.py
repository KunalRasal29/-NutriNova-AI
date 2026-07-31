import secrets

from django.conf import settings
from django.db import models

from common.models import TimeStampedModel


def invite_code():
    return secrets.token_hex(4).upper()


class FriendGroup(TimeStampedModel):
    name = models.CharField(max_length=120)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="owned_friend_groups",
    )
    invite_code = models.CharField(max_length=12, unique=True, default=invite_code)
    leaderboard_enabled = models.BooleanField(default=True)

    class Meta:
        ordering = ("name",)


class FriendGroupMember(TimeStampedModel):
    class Role(models.TextChoices):
        OWNER = "owner", "Owner"
        MEMBER = "member", "Member"

    group = models.ForeignKey(
        FriendGroup,
        on_delete=models.CASCADE,
        related_name="memberships",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="friend_group_memberships",
    )
    role = models.CharField(max_length=16, choices=Role.choices, default=Role.MEMBER)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=("group", "user"),
                name="unique_friend_group_member",
            )
        ]


class WeeklyChallenge(TimeStampedModel):
    group = models.ForeignKey(
        FriendGroup,
        on_delete=models.CASCADE,
        related_name="challenges",
    )
    title = models.CharField(max_length=160)
    week_start = models.DateField()
    target_count = models.PositiveIntegerField(default=7)

    class Meta:
        ordering = ("-week_start",)
        constraints = [
            models.UniqueConstraint(
                fields=("group", "week_start"),
                name="unique_group_weekly_challenge",
            )
        ]


class ChallengeCheckIn(TimeStampedModel):
    challenge = models.ForeignKey(
        WeeklyChallenge,
        on_delete=models.CASCADE,
        related_name="check_ins",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="challenge_check_ins",
    )
    completed_count = models.PositiveIntegerField(default=0)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=("challenge", "user"),
                name="unique_challenge_user_checkin",
            )
        ]


class SharedGroupRecipe(TimeStampedModel):
    group = models.ForeignKey(
        FriendGroup,
        on_delete=models.CASCADE,
        related_name="shared_recipes",
    )
    recipe = models.ForeignKey(
        "recipes.Recipe",
        on_delete=models.CASCADE,
        related_name="group_shares",
    )
    shared_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="shared_group_recipes",
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=("group", "recipe"),
                name="unique_group_shared_recipe",
            )
        ]


class GroupGroceryItem(TimeStampedModel):
    group = models.ForeignKey(
        FriendGroup,
        on_delete=models.CASCADE,
        related_name="grocery_items",
    )
    added_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="group_grocery_items",
    )
    name = models.CharField(max_length=180)
    quantity = models.DecimalField(max_digits=8, decimal_places=2, default=1)
    unit = models.CharField(max_length=32, default="item")
    is_checked = models.BooleanField(default=False)

    class Meta:
        ordering = ("is_checked", "name")
