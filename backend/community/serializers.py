from django.db import transaction
from django.utils import timezone
from rest_framework import serializers

from community.models import (
    FriendGroup,
    FriendGroupMember,
    GroupGroceryItem,
    WeeklyChallenge,
)
from recipes.models import Recipe


class FriendGroupCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = FriendGroup
        fields = ("id", "name", "invite_code", "leaderboard_enabled")
        read_only_fields = ("id", "invite_code")

    @transaction.atomic
    def create(self, validated_data):
        user = self.context["request"].user
        group = FriendGroup.objects.create(owner=user, **validated_data)
        FriendGroupMember.objects.create(
            group=group,
            user=user,
            role=FriendGroupMember.Role.OWNER,
        )
        return group


class JoinGroupSerializer(serializers.Serializer):
    invite_code = serializers.CharField(max_length=12)


class WeeklyChallengeSerializer(serializers.ModelSerializer):
    week_start = serializers.DateField(default=timezone.localdate)

    class Meta:
        model = WeeklyChallenge
        fields = ("id", "title", "week_start", "target_count")
        read_only_fields = ("id",)


class ChallengeCheckInSerializer(serializers.Serializer):
    completed_count = serializers.IntegerField(min_value=0)


class SharedRecipeSerializer(serializers.Serializer):
    recipe_id = serializers.PrimaryKeyRelatedField(
        source="recipe",
        queryset=Recipe.objects.none(),
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request:
            self.fields["recipe_id"].queryset = Recipe.objects.filter(user=request.user)


class GroupGroceryItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = GroupGroceryItem
        fields = ("id", "name", "quantity", "unit", "is_checked", "updated_at")
        read_only_fields = ("id", "updated_at")
