from __future__ import annotations

from django.utils import timezone
from rest_framework import serializers

from habits.models import DailyChecklistTask, Habit, HabitCheckIn, HabitTemplate
from habits.services import is_habit_due_on


class HabitSerializer(serializers.ModelSerializer):
    class Meta:
        model = Habit
        fields = (
            "id",
            "title",
            "description",
            "category",
            "recurrence",
            "recurrence_type",
            "recurrence_rule",
            "days_of_week",
            "start_date",
            "end_date",
            "target_count",
            "unit",
            "sort_order",
            "color",
            "icon",
            "current_streak",
            "longest_streak",
            "is_active",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "current_streak",
            "longest_streak",
            "created_at",
            "updated_at",
        )

    def validate(self, attrs):
        start_date = attrs.get("start_date") or getattr(
            self.instance,
            "start_date",
            None,
        )
        end_date = attrs.get("end_date") or getattr(self.instance, "end_date", None)
        if start_date and end_date and end_date < start_date:
            raise serializers.ValidationError(
                {"end_date": "End date must be on or after start date."}
            )
        recurrence = attrs.get("recurrence") or getattr(self.instance, "recurrence", "")
        recurrence_type = attrs.get("recurrence_type") or getattr(
            self.instance,
            "recurrence_type",
            Habit.RecurrenceType.DAILY,
        )
        days_of_week = attrs.get("days_of_week")
        if days_of_week is None and self.instance:
            days_of_week = self.instance.days_of_week
        days_of_week = days_of_week or []
        try:
            day_values = [int(day) for day in days_of_week]
        except (TypeError, ValueError) as exc:
            raise serializers.ValidationError(
                {"days_of_week": "Days must be integers from 0 to 6."}
            ) from exc
        if any(day < 0 or day > 6 for day in day_values):
            raise serializers.ValidationError(
                {"days_of_week": "Days must be integers from 0 to 6."}
            )
        attrs["days_of_week"] = sorted(set(day_values))

        recurrence_rule = attrs.get("recurrence_rule")
        if recurrence_rule is None and self.instance:
            recurrence_rule = self.instance.recurrence_rule
        recurrence_rule = recurrence_rule or {}
        if recurrence in {Habit.Recurrence.WEEKLY, Habit.Recurrence.CUSTOM}:
            weekdays = recurrence_rule.get("weekdays")
            if weekdays is not None:
                try:
                    weekday_values = {int(day) for day in weekdays}
                except (TypeError, ValueError) as exc:
                    raise serializers.ValidationError(
                        {"recurrence_rule": "Weekdays must be integers from 0 to 6."}
                    ) from exc
                if any(day < 0 or day > 6 for day in weekday_values):
                    raise serializers.ValidationError(
                        {"recurrence_rule": "Weekdays must be integers from 0 to 6."}
                    )
        if recurrence == Habit.Recurrence.CUSTOM:
            interval_days = int(recurrence_rule.get("interval_days", 1) or 1)
            if interval_days < 1:
                raise serializers.ValidationError(
                    {"recurrence_rule": "interval_days must be at least 1."}
                )
        if (
            recurrence_type
            in {
                Habit.RecurrenceType.WEEKLY,
                Habit.RecurrenceType.CUSTOM_DAYS,
            }
            and day_values
        ):
            attrs["days_of_week"] = sorted(set(day_values))
        if recurrence == Habit.Recurrence.WEEKDAYS:
            attrs["recurrence_type"] = Habit.RecurrenceType.CUSTOM_DAYS
            attrs["days_of_week"] = [0, 1, 2, 3, 4]
        elif recurrence == Habit.Recurrence.WEEKLY and not attrs.get("days_of_week"):
            attrs["recurrence_type"] = Habit.RecurrenceType.WEEKLY
            if start_date:
                attrs["days_of_week"] = [start_date.weekday()]
        elif recurrence == Habit.Recurrence.CUSTOM:
            attrs["recurrence_type"] = Habit.RecurrenceType.CUSTOM_DAYS
        return attrs

    def create(self, validated_data):
        return Habit.objects.create(user=self.context["request"].user, **validated_data)


class HabitCheckInSerializer(serializers.ModelSerializer):
    habit_title = serializers.CharField(source="habit.title", read_only=True)
    date = serializers.DateField(source="checked_on", read_only=True)
    completed_count = serializers.IntegerField(source="count", read_only=True)

    class Meta:
        model = HabitCheckIn
        fields = (
            "id",
            "habit",
            "habit_title",
            "date",
            "checked_on",
            "is_completed",
            "completed_count",
            "count",
            "note",
            "completed_at",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "habit",
            "habit_title",
            "date",
            "completed_count",
            "completed_at",
            "created_at",
            "updated_at",
        )


class HabitCheckInInputSerializer(serializers.Serializer):
    checked_on = serializers.DateField(default=timezone.localdate)
    date = serializers.DateField(required=False)
    is_completed = serializers.BooleanField(default=True)
    completed_count = serializers.IntegerField(min_value=0, required=False)
    count = serializers.IntegerField(min_value=0, required=False)
    note = serializers.CharField(required=False, allow_blank=True)

    def validate(self, attrs):
        if attrs.get("date"):
            attrs["checked_on"] = attrs["date"]
        if attrs.get("completed_count") is not None:
            attrs["count"] = attrs["completed_count"]
        return attrs


class DailyChecklistTaskSerializer(serializers.ModelSerializer):
    source_habit_title = serializers.CharField(
        source="source_habit.title",
        read_only=True,
    )
    source_habit_current_streak = serializers.IntegerField(
        source="source_habit.current_streak",
        read_only=True,
    )

    class Meta:
        model = DailyChecklistTask
        fields = (
            "id",
            "title",
            "task_date",
            "is_completed",
            "completed_at",
            "sort_order",
            "source_habit",
            "source_habit_title",
            "source_habit_current_streak",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "completed_at",
            "source_habit",
            "source_habit_title",
            "source_habit_current_streak",
            "created_at",
            "updated_at",
        )

    def create(self, validated_data):
        return DailyChecklistTask.objects.create(
            user=self.context["request"].user,
            **validated_data,
        )


class DashboardQuerySerializer(serializers.Serializer):
    date = serializers.DateField(default=timezone.localdate)


class HabitDueSummarySerializer(serializers.ModelSerializer):
    is_due = serializers.SerializerMethodField()

    class Meta:
        model = Habit
        fields = (
            "id",
            "title",
            "recurrence",
            "target_count",
            "current_streak",
            "longest_streak",
            "is_due",
        )

    def get_is_due(self, obj):
        target_date = self.context["date"]
        return is_habit_due_on(obj, target_date)


class HabitTodayQuerySerializer(serializers.Serializer):
    date = serializers.DateField(default=timezone.localdate)


class HabitMonthGridQuerySerializer(serializers.Serializer):
    month = serializers.RegexField(regex=r"^\d{4}-\d{2}$")


class HabitGridResponseSerializer(serializers.Serializer):
    date = serializers.DateField()
    stats = serializers.JSONField()
    items = serializers.JSONField()


class HabitStreaksResponseSerializer(serializers.Serializer):
    as_of = serializers.DateField()
    habits = serializers.JSONField()


class HabitMonthGridResponseSerializer(serializers.Serializer):
    month = serializers.CharField()
    days = serializers.JSONField()
    stats = serializers.JSONField()


class HabitTemplateSerializer(serializers.ModelSerializer):
    class Meta:
        model = HabitTemplate
        fields = (
            "id",
            "title",
            "description",
            "category",
            "default_target_count",
            "unit",
            "icon",
        )


class HabitCreateFromTemplateSerializer(serializers.Serializer):
    template_id = serializers.PrimaryKeyRelatedField(
        source="template",
        queryset=HabitTemplate.objects.none(),
        required=False,
    )
    title = serializers.CharField(required=False, allow_blank=True)
    start_date = serializers.DateField(default=timezone.localdate)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["template_id"].queryset = HabitTemplate.objects.all()

    def validate(self, attrs):
        if not attrs.get("template") and not attrs.get("title"):
            raise serializers.ValidationError(
                {"template_id": "Choose a template or provide a template title."}
            )
        return attrs
