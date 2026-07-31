from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from analytics.services import weekly_report_for_user


class WeeklyReportView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            days = int(request.query_params.get("days", 7))
        except ValueError:
            days = 7
        days = min(30, max(7, days))
        return Response(weekly_report_for_user(request.user, days=days))
