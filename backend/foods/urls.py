from django.urls import path

from foods.views import (
    BarcodeLookupView,
    CustomFoodConfirmView,
    CustomFoodCreateView,
    CustomFoodDetailView,
    CustomFoodEstimateView,
    CustomFoodHistoryView,
    CustomFoodLogView,
    CustomFoodReEstimateView,
    FavoriteFoodsView,
    FoodDetailView,
    FoodFavoriteView,
    FoodSearchView,
    FrequentFoodsView,
    MyFoodsView,
    RecentFoodsView,
)

urlpatterns = [
    path("barcode-lookup/", BarcodeLookupView.as_view(), name="food-barcode-lookup"),
    path("search/", FoodSearchView.as_view(), name="food-search"),
    path("recent/", RecentFoodsView.as_view(), name="food-recent"),
    path("frequent/", FrequentFoodsView.as_view(), name="food-frequent"),
    path("favorites/", FavoriteFoodsView.as_view(), name="food-favorites"),
    path("my-foods/", MyFoodsView.as_view(), name="food-my-foods"),
    path(
        "custom/estimate/",
        CustomFoodEstimateView.as_view(),
        name="food-custom-estimate",
    ),
    path("custom/", CustomFoodCreateView.as_view(), name="food-custom-create"),
    path(
        "custom/<uuid:id>/re-estimate/",
        CustomFoodReEstimateView.as_view(),
        name="food-custom-re-estimate",
    ),
    path(
        "custom/<uuid:id>/confirm/",
        CustomFoodConfirmView.as_view(),
        name="food-custom-confirm",
    ),
    path(
        "custom/<uuid:id>/history/",
        CustomFoodHistoryView.as_view(),
        name="food-custom-history",
    ),
    path(
        "custom/<uuid:id>/log/",
        CustomFoodLogView.as_view(),
        name="food-custom-log",
    ),
    path(
        "custom/<uuid:id>/",
        CustomFoodDetailView.as_view(),
        name="food-custom-detail",
    ),
    path("<uuid:id>/favorite/", FoodFavoriteView.as_view(), name="food-favorite"),
    path("<uuid:id>/", FoodDetailView.as_view(), name="food-detail"),
]
