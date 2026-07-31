from django.urls import path

from community.views import (
    ChallengeCheckInView,
    FriendGroupDetailView,
    FriendGroupListCreateView,
    GroupGroceryCreateView,
    GroupGroceryDetailView,
    JoinFriendGroupView,
    SharedRecipeView,
    WeeklyChallengeView,
)

urlpatterns = [
    path("groups/", FriendGroupListCreateView.as_view(), name="friend-groups"),
    path("groups/join/", JoinFriendGroupView.as_view(), name="join-friend-group"),
    path(
        "groups/<uuid:id>/", FriendGroupDetailView.as_view(), name="friend-group-detail"
    ),
    path(
        "groups/<uuid:id>/challenge/",
        WeeklyChallengeView.as_view(),
        name="group-challenge",
    ),
    path(
        "groups/<uuid:id>/challenge/<uuid:challenge_id>/check/",
        ChallengeCheckInView.as_view(),
        name="group-challenge-check",
    ),
    path(
        "groups/<uuid:id>/recipes/",
        SharedRecipeView.as_view(),
        name="group-recipes",
    ),
    path(
        "groups/<uuid:id>/grocery/",
        GroupGroceryCreateView.as_view(),
        name="group-grocery-create",
    ),
    path(
        "grocery-items/<uuid:id>/",
        GroupGroceryDetailView.as_view(),
        name="group-grocery-detail",
    ),
]
