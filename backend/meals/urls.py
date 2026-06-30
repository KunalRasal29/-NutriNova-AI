from django.urls import include, path
from rest_framework.routers import DefaultRouter

from meals.views import (
    ManualMealAddView,
    MealLogItemDetailView,
    MealLogViewSet,
    QuickAddTextConfirmView,
    QuickAddTextView,
)

router = DefaultRouter()
router.register("", MealLogViewSet, basename="meal")

urlpatterns = [
    path("manual-add/", ManualMealAddView.as_view(), name="meal-manual-add"),
    path(
        "items/<uuid:id>/",
        MealLogItemDetailView.as_view(),
        name="meal-item-detail",
    ),
    path("quick-add-text/", QuickAddTextView.as_view(), name="meal-quick-add-text"),
    path(
        "quick-add-text/confirm/",
        QuickAddTextConfirmView.as_view(),
        name="meal-quick-add-text-confirm",
    ),
    path("", include(router.urls)),
]
