from django.contrib import admin

from community.models import (
    ChallengeCheckIn,
    FriendGroup,
    FriendGroupMember,
    GroupGroceryItem,
    SharedGroupRecipe,
    WeeklyChallenge,
)

admin.site.register(FriendGroup)
admin.site.register(FriendGroupMember)
admin.site.register(WeeklyChallenge)
admin.site.register(ChallengeCheckIn)
admin.site.register(SharedGroupRecipe)
admin.site.register(GroupGroceryItem)
