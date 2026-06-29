from django.urls import include, path
from rest_framework.routers import DefaultRouter

from profiles.views import BodyMetricViewSet

router = DefaultRouter()
router.register("body-metrics", BodyMetricViewSet, basename="body-metric")

urlpatterns = [
    path("", include(router.urls)),
]
