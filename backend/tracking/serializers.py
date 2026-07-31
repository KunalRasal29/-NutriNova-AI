from django.utils import timezone
from rest_framework import serializers

from tracking.models import DailyActivity, ReminderPreference, WaterIntakeEntry


class WaterIntakeEntrySerializer(serializers.ModelSerializer):
    entry_date = serializers.DateField(default=timezone.localdate)

    class Meta:
        model = WaterIntakeEntry
        fields = ("id", "entry_date", "amount_ml", "note", "created_at")
        read_only_fields = ("id", "created_at")

    def create(self, validated_data):
        return WaterIntakeEntry.objects.create(
            user=self.context["request"].user,
            **validated_data,
        )


class DailyActivitySerializer(serializers.ModelSerializer):
    activity_date = serializers.DateField(default=timezone.localdate)

    class Meta:
        model = DailyActivity
        fields = (
            "id",
            "activity_date",
            "activity_type",
            "title",
            "duration_minutes",
            "steps",
            "calories_burned",
            "notes",
            "created_at",
        )
        read_only_fields = ("id", "created_at")

    def validate(self, attrs):
        activity_type = attrs.get(
            "activity_type",
            getattr(self.instance, "activity_type", None),
        )
        steps = attrs.get("steps", getattr(self.instance, "steps", 0))
        duration = attrs.get(
            "duration_minutes",
            getattr(self.instance, "duration_minutes", 0),
        )
        if activity_type == DailyActivity.ActivityType.STEPS and steps <= 0:
            raise serializers.ValidationError({"steps": "Enter a step count."})
        if activity_type == DailyActivity.ActivityType.WORKOUT and duration <= 0:
            raise serializers.ValidationError(
                {"duration_minutes": "Enter workout duration."}
            )
        return attrs

    def create(self, validated_data):
        return DailyActivity.objects.create(
            user=self.context["request"].user,
            **validated_data,
        )


class ReminderPreferenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReminderPreference
        exclude = ("user",)
        read_only_fields = ("id", "created_at", "updated_at")

    def validate_water_reminder_interval_minutes(self, value):
        if value < 30 or value > 720:
            raise serializers.ValidationError("Use an interval from 30 to 720 minutes.")
        return value

    def validate_weight_reminder_weekday(self, value):
        if value > 6:
            raise serializers.ValidationError("Weekday must be between 0 and 6.")
        return value
