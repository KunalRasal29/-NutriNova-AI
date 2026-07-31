from django.db import transaction
from django.shortcuts import get_object_or_404
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from community.models import (
    ChallengeCheckIn,
    FriendGroup,
    FriendGroupMember,
    GroupGroceryItem,
    SharedGroupRecipe,
    WeeklyChallenge,
)
from community.serializers import (
    ChallengeCheckInSerializer,
    FriendGroupCreateSerializer,
    GroupGroceryItemSerializer,
    JoinGroupSerializer,
    SharedRecipeSerializer,
    WeeklyChallengeSerializer,
)


def groups_for(user):
    return FriendGroup.objects.filter(memberships__user=user).distinct()


def group_for(user, group_id):
    return get_object_or_404(groups_for(user), id=group_id)


def group_payload(group, user):
    challenge = group.challenges.prefetch_related("check_ins__user").first()
    own_check = None
    leaderboard = []
    if challenge:
        own_check = challenge.check_ins.filter(user=user).first()
        if group.leaderboard_enabled:
            leaderboard = [
                {
                    "display_name": (
                        getattr(check.user, "profile", None).display_name
                        if getattr(check.user, "profile", None)
                        and check.user.profile.display_name
                        else "Friend"
                    ),
                    "completed_count": check.completed_count,
                }
                for check in challenge.check_ins.select_related(
                    "user__profile"
                ).order_by(
                    "-completed_count",
                    "created_at",
                )
            ]
    return {
        "id": group.id,
        "name": group.name,
        "invite_code": group.invite_code,
        "is_owner": group.owner_id == user.id,
        "leaderboard_enabled": group.leaderboard_enabled,
        "members": [
            {
                "id": membership.user_id,
                "display_name": (
                    membership.user.profile.display_name
                    if hasattr(membership.user, "profile")
                    and membership.user.profile.display_name
                    else "Friend"
                ),
                "role": membership.role,
            }
            for membership in group.memberships.select_related("user__profile")
        ],
        "challenge": (
            {
                **WeeklyChallengeSerializer(challenge).data,
                "my_completed_count": own_check.completed_count if own_check else 0,
                "leaderboard": leaderboard,
            }
            if challenge
            else None
        ),
        "recipes": [
            {
                "id": shared.id,
                "recipe_id": shared.recipe_id,
                "name": shared.recipe.name,
                "servings": shared.recipe.servings,
            }
            for shared in group.shared_recipes.select_related("recipe")
        ],
        "grocery_items": GroupGroceryItemSerializer(
            group.grocery_items.all(),
            many=True,
        ).data,
        "privacy_note": (
            "Meals, weight, body measurements, and nutrition totals stay private."
        ),
    }


class FriendGroupListCreateView(generics.GenericAPIView):
    serializer_class = FriendGroupCreateSerializer
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(
            [group_payload(group, request.user) for group in groups_for(request.user)]
        )

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        group = serializer.save()
        return Response(
            group_payload(group, request.user), status=status.HTTP_201_CREATED
        )


class JoinFriendGroupView(generics.GenericAPIView):
    serializer_class = JoinGroupSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        group = get_object_or_404(
            FriendGroup,
            invite_code=serializer.validated_data["invite_code"].strip().upper(),
        )
        FriendGroupMember.objects.get_or_create(group=group, user=request.user)
        return Response(group_payload(group, request.user))


class FriendGroupDetailView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, id):
        return Response(group_payload(group_for(request.user, id), request.user))


class WeeklyChallengeView(generics.GenericAPIView):
    serializer_class = WeeklyChallengeSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        group = group_for(request.user, id)
        if group.owner_id != request.user.id:
            return Response(
                {"detail": "Only the group owner can set the challenge."},
                status=403,
            )
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        values = serializer.validated_data
        WeeklyChallenge.objects.update_or_create(
            group=group,
            week_start=values["week_start"],
            defaults={"title": values["title"], "target_count": values["target_count"]},
        )
        return Response(group_payload(group, request.user))


class ChallengeCheckInView(generics.GenericAPIView):
    serializer_class = ChallengeCheckInSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request, id, challenge_id):
        group = group_for(request.user, id)
        challenge = get_object_or_404(group.challenges, id=challenge_id)
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        ChallengeCheckIn.objects.update_or_create(
            challenge=challenge,
            user=request.user,
            defaults=serializer.validated_data,
        )
        return Response(group_payload(group, request.user))


class SharedRecipeView(generics.GenericAPIView):
    serializer_class = SharedRecipeSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        group = group_for(request.user, id)
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        SharedGroupRecipe.objects.get_or_create(
            group=group,
            recipe=serializer.validated_data["recipe"],
            defaults={"shared_by": request.user},
        )
        return Response(group_payload(group, request.user))


class GroupGroceryCreateView(generics.GenericAPIView):
    serializer_class = GroupGroceryItemSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        group = group_for(request.user, id)
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(group=group, added_by=request.user)
        return Response(
            group_payload(group, request.user), status=status.HTTP_201_CREATED
        )


class GroupGroceryDetailView(generics.GenericAPIView):
    serializer_class = GroupGroceryItemSerializer
    permission_classes = [IsAuthenticated]

    def patch(self, request, id):
        item = get_object_or_404(
            GroupGroceryItem, id=id, group__memberships__user=request.user
        )
        serializer = self.get_serializer(item, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(group_payload(item.group, request.user))

    @transaction.atomic
    def delete(self, request, id):
        item = get_object_or_404(
            GroupGroceryItem, id=id, group__memberships__user=request.user
        )
        group = item.group
        item.delete()
        return Response(group_payload(group, request.user))
