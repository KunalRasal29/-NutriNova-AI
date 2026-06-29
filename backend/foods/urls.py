from django.urls import path

from foods.views import (
    CustomFoodCreateView,
    FoodDetailView,
    FoodFavoriteView,
    FoodSearchView,
)

urlpatterns = [
    path("search/", FoodSearchView.as_view(), name="food-search"),
    path("custom/", CustomFoodCreateView.as_view(), name="food-custom-create"),
    path("<uuid:id>/favorite/", FoodFavoriteView.as_view(), name="food-favorite"),
    path("<uuid:id>/", FoodDetailView.as_view(), name="food-detail"),
]
