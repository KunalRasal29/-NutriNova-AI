from django.db.models import Sum
from django.utils import timezone
from rest_framework import generics, viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from tracking.models import DailyActivity, ReminderPreference, WaterIntakeEntry
from tracking.serializers import (
    DailyActivitySerializer,
    ReminderPreferenceSerializer,
    WaterIntakeEntrySerializer,
)


class UserOwnedViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    lookup_field = "id"
    http_method_names = ["get", "post", "patch", "delete", "head", "options"]

    def filtered_date(self, queryset, field):
        value = self.request.query_params.get("date")
        return queryset.filter(**{field: value}) if value else queryset


class WaterIntakeViewSet(UserOwnedViewSet):
    serializer_class = WaterIntakeEntrySerializer

    def get_queryset(self):
        queryset = WaterIntakeEntry.objects.filter(user=self.request.user)
        return self.filtered_date(queryset, "entry_date")


class DailyActivityViewSet(UserOwnedViewSet):
    serializer_class = DailyActivitySerializer

    def get_queryset(self):
        queryset = DailyActivity.objects.filter(user=self.request.user)
        return self.filtered_date(queryset, "activity_date")


class ReminderPreferenceView(generics.GenericAPIView):
    serializer_class = ReminderPreferenceSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        preference, _ = ReminderPreference.objects.get_or_create(user=self.request.user)
        return preference

    def get(self, request):
        return Response(self.get_serializer(self.get_object()).data)

    def patch(self, request):
        serializer = self.get_serializer(
            self.get_object(),
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class TodayTrackingView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        entry_date = request.query_params.get("date") or timezone.localdate()
        water = WaterIntakeEntry.objects.filter(
            user=request.user,
            entry_date=entry_date,
        )
        activities = DailyActivity.objects.filter(
            user=request.user,
            activity_date=entry_date,
        )
        totals = activities.aggregate(
            steps=Sum("steps"),
            duration_minutes=Sum("duration_minutes"),
            calories_burned=Sum("calories_burned"),
        )
        profile = getattr(request.user, "profile", None)
        return Response(
            {
                "date": entry_date,
                "water_ml": water.aggregate(total=Sum("amount_ml"))["total"] or 0,
                "water_target_ml": (
                    profile.daily_water_target_ml
                    if profile and profile.daily_water_target_ml
                    else 2500
                ),
                "steps": totals["steps"] or 0,
                "duration_minutes": totals["duration_minutes"] or 0,
                "calories_burned": totals["calories_burned"] or 0,
                "activities": DailyActivitySerializer(activities, many=True).data,
            }
        )
