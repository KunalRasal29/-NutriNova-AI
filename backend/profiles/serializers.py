from __future__ import annotations

from decimal import Decimal

from django.utils import timezone
from rest_framework import serializers

from profiles.models import BodyMetric


class BodyMetricSerializer(serializers.ModelSerializer):
    recorded_on = serializers.DateField(default=timezone.localdate)

    class Meta:
        model = BodyMetric
        fields = (
            "id",
            "recorded_on",
            "weight_kg",
            "waist_cm",
            "hip_cm",
            "chest_cm",
            "body_fat_percentage",
            "notes",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")

    def validate(self, attrs):
        metric_fields = (
            "weight_kg",
            "waist_cm",
            "hip_cm",
            "chest_cm",
            "body_fat_percentage",
        )
        instance = self.instance
        has_metric = any(
            attrs.get(field) is not None
            or (instance and getattr(instance, field) is not None)
            for field in metric_fields
        )
        if not has_metric:
            raise serializers.ValidationError("Add at least one body metric value.")

        for field in metric_fields:
            value = attrs.get(field)
            if value is not None and value <= 0:
                raise serializers.ValidationError(
                    {field: "Value must be greater than zero."}
                )

        body_fat = attrs.get("body_fat_percentage")
        if body_fat is not None and body_fat > Decimal("100"):
            raise serializers.ValidationError(
                {"body_fat_percentage": "Body fat percentage cannot exceed 100."}
            )
        return attrs

    def create(self, validated_data):
        user = self.context["request"].user
        recorded_on = validated_data.pop("recorded_on")
        metric, _ = BodyMetric.objects.update_or_create(
            user=user,
            recorded_on=recorded_on,
            defaults=validated_data,
        )
        return metric

    def update(self, instance, validated_data):
        validated_data.pop("recorded_on", None)
        return super().update(instance, validated_data)


class BodyMetricTrendQuerySerializer(serializers.Serializer):
    days = serializers.IntegerField(default=30, min_value=1, max_value=365)


class BodyMetricTrendResponseSerializer(serializers.Serializer):
    start_date = serializers.DateField()
    end_date = serializers.DateField()
    latest = serializers.JSONField(allow_null=True)
    change_kg = serializers.DecimalField(
        max_digits=7,
        decimal_places=3,
        allow_null=True,
    )
    target_weight_kg = serializers.DecimalField(
        max_digits=6,
        decimal_places=2,
        allow_null=True,
    )
    items = serializers.JSONField()
