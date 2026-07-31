from django.urls import include, path
from rest_framework.routers import DefaultRouter

from tracking.views import (
    DailyActivityViewSet,
    ReminderPreferenceView,
    TodayTrackingView,
    WaterIntakeViewSet,
)

router = DefaultRouter()
router.register("water", WaterIntakeViewSet, basename="tracking-water")
router.register("activities", DailyActivityViewSet, basename="tracking-activity")

urlpatterns = [
    path("", include(router.urls)),
    path("today/", TodayTrackingView.as_view(), name="tracking-today"),
    path("reminders/", ReminderPreferenceView.as_view(), name="tracking-reminders"),
]
