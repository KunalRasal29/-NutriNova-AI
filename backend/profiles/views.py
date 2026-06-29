from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.utils import timezone
from drf_spectacular.utils import OpenApiExample, OpenApiParameter, extend_schema
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from profiles.models import BodyMetric
from profiles.serializers import (
    BodyMetricSerializer,
    BodyMetricTrendQuerySerializer,
    BodyMetricTrendResponseSerializer,
)


class BodyMetricViewSet(viewsets.ModelViewSet):
    serializer_class = BodyMetricSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = "id"
    http_method_names = ["get", "post", "patch", "delete", "head", "options"]

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return BodyMetric.objects.none()
        return BodyMetric.objects.filter(user=self.request.user).order_by(
            "-recorded_on",
            "-created_at",
        )

    @extend_schema(
        tags=["body metrics"],
        parameters=[
            OpenApiParameter("start", str, required=False, description="ISO date."),
            OpenApiParameter("end", str, required=False, description="ISO date."),
        ],
        responses={200: BodyMetricSerializer(many=True)},
    )
    def list(self, request, *args, **kwargs):
        queryset = self.filter_queryset(self.get_queryset())
        start = request.query_params.get("start")
        end = request.query_params.get("end")
        if start:
            queryset = queryset.filter(recorded_on__gte=start)
        if end:
            queryset = queryset.filter(recorded_on__lte=end)
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @extend_schema(
        tags=["body metrics"],
        request=BodyMetricSerializer,
        responses={201: BodyMetricSerializer},
        examples=[
            OpenApiExample(
                "Log weight",
                request_only=True,
                value={
                    "recorded_on": "2026-06-29",
                    "weight_kg": "72.50",
                    "waist_cm": "84.00",
                    "notes": "Morning check-in",
                },
            )
        ],
    )
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        metric = serializer.save()
        return Response(
            self.get_serializer(metric).data,
            status=status.HTTP_201_CREATED,
        )

    @extend_schema(
        tags=["body metrics"],
        parameters=[
            OpenApiParameter(
                "days",
                int,
                required=False,
                description="Number of recent days to include, max 365.",
            )
        ],
        responses={200: BodyMetricTrendResponseSerializer},
    )
    @action(detail=False, methods=["get"], url_path="trend")
    def trend(self, request):
        serializer = BodyMetricTrendQuerySerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        days = serializer.validated_data["days"]
        end_date = timezone.localdate()
        start_date = end_date - timedelta(days=days - 1)
        metrics = list(
            BodyMetric.objects.filter(
                user=request.user,
                recorded_on__gte=start_date,
                recorded_on__lte=end_date,
            ).order_by("recorded_on", "created_at")
        )
        items = [_metric_payload(metric, source="body_metric") for metric in metrics]

        profile = getattr(request.user, "profile", None)
        if not items and profile and profile.weight_kg:
            items.append(
                {
                    "id": None,
                    "recorded_on": profile.updated_at.date(),
                    "weight_kg": str(profile.weight_kg),
                    "body_fat_percentage": None,
                    "source": "profile",
                }
            )

        weights = [
            metric.weight_kg for metric in metrics if metric.weight_kg is not None
        ]
        change_kg = (
            str((weights[-1] - weights[0]).quantize(Decimal("0.001")))
            if len(weights) >= 2
            else None
        )
        return Response(
            {
                "start_date": start_date,
                "end_date": end_date,
                "latest": items[-1] if items else None,
                "change_kg": change_kg,
                "target_weight_kg": (
                    str(profile.target_weight_kg)
                    if profile and profile.target_weight_kg is not None
                    else None
                ),
                "items": items,
            }
        )


def _metric_payload(metric: BodyMetric, *, source: str) -> dict:
    return {
        "id": metric.id,
        "recorded_on": metric.recorded_on,
        "weight_kg": str(metric.weight_kg) if metric.weight_kg is not None else None,
        "body_fat_percentage": (
            str(metric.body_fat_percentage)
            if metric.body_fat_percentage is not None
            else None
        ),
        "source": source,
    }
