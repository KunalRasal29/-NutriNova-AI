from django.urls import path

from meals.views import DailyNutritionSummaryView, RangeNutritionSummaryView
from nutrition.views import DataSourceListView, NutrientListView

urlpatterns = [
    path("nutrients/", NutrientListView.as_view(), name="nutrient-list"),
    path("data-sources/", DataSourceListView.as_view(), name="data-source-list"),
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
