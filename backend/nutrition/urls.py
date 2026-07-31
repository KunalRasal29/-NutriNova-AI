from django.urls import path

from meals.views import DailyNutritionSummaryView, RangeNutritionSummaryView
from nutrition.views import (
    DataSourceListView,
    NutrientListView,
    NutritionTargetEstimateView,
    NutritionTargetsView,
)

urlpatterns = [
    path("nutrients/", NutrientListView.as_view(), name="nutrient-list"),
    path("data-sources/", DataSourceListView.as_view(), name="data-source-list"),
    path(
        "nutrition/targets/",
        NutritionTargetsView.as_view(),
        name="nutrition-targets",
    ),
    path(
        "nutrition/targets/estimate/",
        NutritionTargetEstimateView.as_view(),
        name="nutrition-target-estimate",
    ),
    path(
        "nutrition/daily-summary/",
        DailyNutritionSummaryView.as_view(),
        name="daily-nutrition-summary",
    ),
    path(
        "nutrition/range-summary/",
        RangeNutritionSummaryView.as_view(),
        name="range-nutrition-summary",
    ),
]
