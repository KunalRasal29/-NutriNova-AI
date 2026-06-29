from __future__ import annotations

from drf_spectacular.utils import OpenApiExample, OpenApiParameter, extend_schema
from rest_framework import generics, serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from habits.models import DailyChecklistTask, Habit, HabitCheckIn, HabitTemplate
from habits.serializers import (
    DailyChecklistTaskSerializer,
    DashboardQuerySerializer,
    HabitCheckInInputSerializer,
    HabitCheckInSerializer,
    HabitCreateFromTemplateSerializer,
    HabitDueSummarySerializer,
    HabitGridResponseSerializer,
    HabitMonthGridQuerySerializer,
    HabitMonthGridResponseSerializer,
    HabitSerializer,
    HabitStreaksResponseSerializer,
    HabitTemplateSerializer,
    HabitTodayQuerySerializer,
)
from habits.services import (
    checklist_stats,
    create_habit_from_template,
    delete_habit_check_in,
    ensure_default_habit_templates,
    materialize_daily_checklist,
    month_grid_payload,
    streaks_payload,
    today_habit_grid,
    toggle_checklist_task,
    upsert_habit_check_in,
)


class DateRangeQuerySerializer(serializers.Serializer):
    start = serializers.DateField(required=False)
    end = serializers.DateField(required=False)

    def validate(self, attrs):
        start = attrs.get("start")
        end = attrs.get("end")
        if start and end and end < start:
            raise serializers.ValidationError({"end": "End date must be after start."})
        return attrs


class HabitViewSet(viewsets.ModelViewSet):
    serializer_class = HabitSerializer
    permission_classes = [IsAuthenticated]
    http_method_names = ["get", "post", "patch", "delete", "head", "options"]

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return Habit.objects.none()
        queryset = Habit.objects.filter(user=self.request.user)
        is_active = self.request.query_params.get("is_active")
        if is_active is not None:
            queryset = queryset.filter(is_active=is_active.lower() in {"1", "true"})
        return queryset.order_by("-is_active", "sort_order", "title")

    @extend_schema(
        tags=["habits"],
        parameters=[
            OpenApiParameter(
                "is_active",
                bool,
                required=False,
                description="Filter active or archived habits.",
            )
        ],
        examples=[
            OpenApiExample(
                "Create daily habit",
                request_only=True,
                value={
                    "title": "Drink water",
                    "recurrence": "daily",
                    "start_date": "2026-06-29",
                    "target_count": 1,
                },
            )
        ],
    )
    def list(self, request, *args, **kwargs):
        return super().list(request, *args, **kwargs)

    @extend_schema(
        tags=["habits"],
        request=HabitCheckInInputSerializer,
        responses={200: HabitCheckInSerializer},
    )
    @action(detail=True, methods=["post"], url_path="check-in")
    def check_in(self, request, pk=None):
        habit = self.get_object()
        serializer = HabitCheckInInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            check_in = upsert_habit_check_in(
                habit=habit,
                checked_on=serializer.validated_data["checked_on"],
                is_completed=serializer.validated_data["is_completed"],
                count=serializer.validated_data.get("count"),
                note=serializer.validated_data.get("note", ""),
            )
        except ValueError as exc:
            raise serializers.ValidationError({"checked_on": str(exc)}) from exc
        return Response(HabitCheckInSerializer(check_in).data)

    @extend_schema(
        tags=["habits"],
        request=HabitCheckInInputSerializer,
        responses={200: HabitCheckInSerializer},
        examples=[
            OpenApiExample(
                "Tick water habit",
                request_only=True,
                value={
                    "date": "2026-06-29",
                    "completed_count": 8,
                    "is_completed": True,
                    "note": "Finished before dinner",
                },
            )
        ],
    )
    @action(detail=True, methods=["post", "delete"], url_path="check")
    def check(self, request, pk=None):
        habit = self.get_object()
        if request.method == "DELETE":
            serializer = HabitTodayQuerySerializer(data=request.query_params)
            serializer.is_valid(raise_exception=True)
            delete_habit_check_in(
                habit=habit,
                checked_on=serializer.validated_data["date"],
            )
            return Response(status=status.HTTP_204_NO_CONTENT)

        serializer = HabitCheckInInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            check_in = upsert_habit_check_in(
                habit=habit,
                checked_on=serializer.validated_data["checked_on"],
                is_completed=serializer.validated_data["is_completed"],
                count=serializer.validated_data.get("count"),
                note=serializer.validated_data.get("note", ""),
            )
        except ValueError as exc:
            raise serializers.ValidationError({"date": str(exc)}) from exc
        return Response(HabitCheckInSerializer(check_in).data)

    @extend_schema(
        tags=["habits"],
        parameters=[
            OpenApiParameter("start", str, required=False, description="ISO date."),
            OpenApiParameter("end", str, required=False, description="ISO date."),
        ],
        responses={200: HabitCheckInSerializer(many=True)},
    )
    @action(detail=True, methods=["get"], url_path="check-ins")
    def check_ins(self, request, pk=None):
        habit = self.get_object()
        serializer = DateRangeQuerySerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        queryset = HabitCheckIn.objects.filter(user=request.user, habit=habit)
        if serializer.validated_data.get("start"):
            queryset = queryset.filter(
                checked_on__gte=serializer.validated_data["start"]
            )
        if serializer.validated_data.get("end"):
            queryset = queryset.filter(checked_on__lte=serializer.validated_data["end"])
        return Response(HabitCheckInSerializer(queryset, many=True).data)

    @extend_schema(
        tags=["habits"],
        parameters=[
            OpenApiParameter(
                "date",
                str,
                required=False,
                description="ISO date. Defaults to today.",
            )
        ],
    )
    @action(detail=False, methods=["get"], url_path="dashboard")
    def dashboard(self, request):
        serializer = DashboardQuerySerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        target_date = serializer.validated_data["date"]
        tasks = materialize_daily_checklist(request.user, target_date)
        habits = Habit.objects.filter(user=request.user, is_active=True).order_by(
            "title"
        )
        due_habits = [habit for habit in habits if habit.start_date <= target_date]
        return Response(
            {
                "date": target_date,
                "stats": checklist_stats(tasks),
                "tasks": DailyChecklistTaskSerializer(tasks, many=True).data,
                "habits": HabitDueSummarySerializer(
                    due_habits,
                    many=True,
                    context={"date": target_date},
                ).data,
            }
        )

    @extend_schema(
        tags=["habits"],
        parameters=[
            OpenApiParameter(
                "date",
                str,
                required=False,
                description="ISO date. Defaults to today.",
            )
        ],
        responses={200: HabitGridResponseSerializer},
    )
    @action(detail=False, methods=["get"], url_path="today")
    def today(self, request):
        serializer = HabitTodayQuerySerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        return Response(
            today_habit_grid(request.user, serializer.validated_data["date"])
        )

    @extend_schema(
        tags=["habits"],
        responses={200: HabitStreaksResponseSerializer},
    )
    @action(detail=False, methods=["get"], url_path="streaks")
    def streaks(self, request):
        return Response(streaks_payload(request.user))

    @extend_schema(
        tags=["habits"],
        parameters=[
            OpenApiParameter(
                "month",
                str,
                required=True,
                description="Month in YYYY-MM format.",
            )
        ],
        responses={200: HabitMonthGridResponseSerializer},
    )
    @action(detail=False, methods=["get"], url_path="month-grid")
    def month_grid(self, request):
        serializer = HabitMonthGridQuerySerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        try:
            payload = month_grid_payload(
                request.user,
                serializer.validated_data["month"],
            )
        except ValueError as exc:
            raise serializers.ValidationError({"month": str(exc)}) from exc
        return Response(payload)

    @extend_schema(
        tags=["habits"],
        responses={200: HabitTemplateSerializer(many=True)},
    )
    @action(detail=False, methods=["get"], url_path="templates")
    def templates(self, request):
        ensure_default_habit_templates()
        templates = HabitTemplate.objects.all()
        return Response(HabitTemplateSerializer(templates, many=True).data)

    @extend_schema(
        tags=["habits"],
        request=HabitCreateFromTemplateSerializer,
        responses={201: HabitSerializer},
    )
    @action(detail=False, methods=["post"], url_path="create-from-template")
    def create_from_template(self, request):
        ensure_default_habit_templates()
        serializer = HabitCreateFromTemplateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        template = serializer.validated_data.get("template")
        if not template:
            try:
                template = HabitTemplate.objects.get(
                    title__iexact=serializer.validated_data["title"]
                )
            except HabitTemplate.DoesNotExist as exc:
                raise serializers.ValidationError(
                    {"title": "Template was not found."}
                ) from exc
        habit = create_habit_from_template(
            request.user,
            template,
            start_date=serializer.validated_data["start_date"],
        )
        return Response(
            HabitSerializer(habit, context=self.get_serializer_context()).data,
            status=status.HTTP_201_CREATED,
        )


class DailyChecklistTaskListCreateView(generics.ListCreateAPIView):
    serializer_class = DailyChecklistTaskSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return DailyChecklistTask.objects.none()
        target_date = self.request.query_params.get("date")
        queryset = DailyChecklistTask.objects.filter(user=self.request.user)
        if target_date:
            queryset = queryset.filter(task_date=target_date)
        return queryset.select_related("source_habit").order_by(
            "task_date",
            "sort_order",
            "created_at",
        )

    @extend_schema(
        tags=["habits"],
        parameters=[
            OpenApiParameter(
                "date",
                str,
                required=False,
                description=(
                    "ISO date. When provided, recurring habit tasks are generated."
                ),
            )
        ],
        responses={200: DailyChecklistTaskSerializer(many=True)},
    )
    def get(self, request, *args, **kwargs):
        target_date = request.query_params.get("date")
        if target_date:
            serializer = DashboardQuerySerializer(data={"date": target_date})
            serializer.is_valid(raise_exception=True)
            materialize_daily_checklist(request.user, serializer.validated_data["date"])
        return super().get(request, *args, **kwargs)

    @extend_schema(
        tags=["habits"],
        request=DailyChecklistTaskSerializer,
        responses={201: DailyChecklistTaskSerializer},
    )
    def post(self, request, *args, **kwargs):
        return super().post(request, *args, **kwargs)


class DailyChecklistTaskDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = DailyChecklistTaskSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = "id"
    http_method_names = ["get", "patch", "delete", "head", "options"]

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return DailyChecklistTask.objects.none()
        return DailyChecklistTask.objects.filter(user=self.request.user).select_related(
            "source_habit"
        )

    @extend_schema(tags=["habits"], request=DailyChecklistTaskSerializer)
    def patch(self, request, *args, **kwargs):
        return super().patch(request, *args, **kwargs)

    def perform_update(self, serializer):
        is_completed_changed = "is_completed" in serializer.validated_data
        if is_completed_changed:
            updated_task = serializer.save()
            toggle_checklist_task(
                updated_task,
                serializer.validated_data["is_completed"],
            )
        else:
            serializer.save()
