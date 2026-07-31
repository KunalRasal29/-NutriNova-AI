from django.urls import path

from analytics.views import WeeklyReportView

urlpatterns = [
    path("weekly-report/", WeeklyReportView.as_view(), name="weekly-report"),
]
