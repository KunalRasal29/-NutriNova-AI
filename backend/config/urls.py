"""URL configuration for NutriNova AI."""

from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from accounts.views import MeView
from common.views import HealthCheckView
from habits.urls import checklist_urlpatterns
from meals.views import MealLogItemDetailView

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/auth/", include("accounts.urls")),
    path("api/foods/", include("foods.urls")),
    path("api/habits/", include("habits.urls")),
    path("api/checklist/", include(checklist_urlpatterns)),
    path("api/meals/", include("meals.urls")),
    path("api/", include("profiles.urls")),
    path(
        "api/meal-items/<uuid:id>/",
        MealLogItemDetailView.as_view(),
        name="meal-item-detail",
    ),
    path("api/photos/", include("photos.urls")),
    path("api/recipes/", include("recipes.urls")),
    path("api/", include("nutrition.urls")),
    path("api/me/", MeView.as_view(), name="me"),
    path("api/health/", HealthCheckView.as_view(), name="health-check"),
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path(
        "api/docs/",
        SpectacularSwaggerView.as_view(url_name="schema"),
        name="swagger-ui",
    ),
]
