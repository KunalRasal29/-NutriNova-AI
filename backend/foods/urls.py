from django.urls import path

from foods.views import (
    CustomFoodCreateView,
    FavoriteFoodsView,
    FoodDetailView,
    FoodFavoriteView,
    FrequentFoodsView,
    FoodSearchView,
    MyFoodsView,
    RecentFoodsView,
)

urlpatterns = [
    path("search/", FoodSearchView.as_view(), name="food-search"),
    path("recent/", RecentFoodsView.as_view(), name="food-recent"),
    path("frequent/", FrequentFoodsView.as_view(), name="food-frequent"),
    path("favorites/", FavoriteFoodsView.as_view(), name="food-favorites"),
    path("my-foods/", MyFoodsView.as_view(), name="food-my-foods"),
    path("custom/", CustomFoodCreateView.as_view(), name="food-custom-create"),
    path("<uuid:id>/favorite/", FoodFavoriteView.as_view(), name="food-favorite"),
    path("<uuid:id>/", FoodDetailView.as_view(), name="food-detail"),
]
