from django.urls import include, path
from rest_framework.routers import DefaultRouter

from habits.views import (
    DailyChecklistTaskDetailView,
    DailyChecklistTaskListCreateView,
    HabitViewSet,
)

router = DefaultRouter()
router.register("", HabitViewSet, basename="habit")

urlpatterns = [
    path("", include(router.urls)),
]

checklist_urlpatterns = [
    path(
        "tasks/",
        DailyChecklistTaskListCreateView.as_view(),
        name="checklist-task-list",
    ),
    path(
        "tasks/<uuid:id>/",
        DailyChecklistTaskDetailView.as_view(),
        name="checklist-task-detail",
    ),
]
