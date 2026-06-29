from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.utils import timezone
from drf_spectacular.utils import OpenApiExample, OpenApiParameter, extend_schema
from rest_framework import generics, serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from meals.models import MealLog, MealLogItem
from meals.serializers import (
    CopyYesterdayMealsSerializer,
    DailyNutritionSummarySerializer,
    ManualMealAddResponseSerializer,
    ManualMealAddSerializer,
    MealLogItemSerializer,
    MealLogSerializer,
    QuickAddConfirmResponseSerializer,
    QuickAddTextConfirmSerializer,
    QuickAddTextResponseSerializer,
    QuickAddTextSerializer,
)
from meals.services import (
    copy_meals_from_previous_day,
    get_or_recompute_daily_summary,
    recompute_daily_summary,
)
from meals.services.manual_add import add_food_to_meal
from meals.services.quick_add_parser import confirm_quick_add_text, parse_quick_add_text
from nutrition.calculations import (
    daily_targets_for_user,
    decimal_to_snapshot,
    macro_percentage_split,
    target_progress_for_values,
)


class DateQuerySerializer(serializers.Serializer):
    date = serializers.DateField()


class RangeQuerySerializer(serializers.Serializer):
    start = serializers.DateField()
    end = serializers.DateField()

    def validate(self, attrs):
        if attrs["end"] < attrs["start"]:
            raise serializers.ValidationError({"end": "End date must be after start."})
        if (attrs["end"] - attrs["start"]).days > 366:
            raise serializers.ValidationError(
                {"end": "Range summaries are limited to 366 days."}
            )
        return attrs


class ManualMealAddView(generics.GenericAPIView):
    serializer_class = ManualMealAddSerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(
        tags=["meals"],
        request=ManualMealAddSerializer,
        responses={201: ManualMealAddResponseSerializer},
        examples=[
            OpenApiExample(
                "Add food manually",
                request_only=True,
                value={
                    "date": "2026-06-29",
                    "meal_type": "breakfast",
                    "food_id": "00000000-0000-0000-0000-000000000000",
                    "quantity_value": "2.000",
                    "quantity_unit": "egg",
                },
            )
        ],
    )
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        meal_log, item, preview = add_food_to_meal(
            request.user,
            serializer.validated_data,
        )
        context = self.get_serializer_context()
        return Response(
            {
                "meal": MealLogSerializer(meal_log, context=context).data,
                "item": MealLogItemSerializer(item, context=context).data,
                "preview": preview,
            },
            status=status.HTTP_201_CREATED,
        )


class QuickAddTextView(generics.GenericAPIView):
    serializer_class = QuickAddTextSerializer
    permission_classes = [IsAuthenticated]
    throttle_scope = "quick_add"

    @extend_schema(
        tags=["meals"],
        request=QuickAddTextSerializer,
        responses={200: QuickAddTextResponseSerializer},
        examples=[
            OpenApiExample(
                "Parse quick add",
                request_only=True,
                value={
                    "text": "2 eggs",
                    "date": "2026-06-29",
                    "meal_type": "breakfast",
                },
            )
        ],
    )
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(
            parse_quick_add_text(
                request.user,
                serializer.validated_data["text"],
            )
        )


class QuickAddTextConfirmView(generics.GenericAPIView):
    serializer_class = QuickAddTextConfirmSerializer
    permission_classes = [IsAuthenticated]
    throttle_scope = "quick_add"

    @extend_schema(
        tags=["meals"],
        request=QuickAddTextConfirmSerializer,
        responses={201: QuickAddConfirmResponseSerializer},
    )
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        result = confirm_quick_add_text(request.user, serializer.validated_data)
        context = self.get_serializer_context()
        return Response(
            {
                "meal": MealLogSerializer(result["meal"], context=context).data,
                "items": MealLogItemSerializer(
                    result["items"],
                    many=True,
                    context=context,
                ).data,
                "preview": result["preview"],
            },
            status=status.HTTP_201_CREATED,
        )


class MealLogViewSet(viewsets.ModelViewSet):
    serializer_class = MealLogSerializer
    permission_classes = [IsAuthenticated]
    http_method_names = ["get", "post", "patch", "delete", "head", "options"]

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return MealLog.objects.none()
        queryset = (
            MealLog.objects.filter(user=self.request.user)
            .prefetch_related(
                "items__food__source",
                "items__serving",
            )
            .order_by("-date", "meal_type", "created_at")
        )
        date = self.request.query_params.get("date")
        if date:
            queryset = queryset.filter(date=date)
        return queryset

    @extend_schema(
        tags=["meals"],
        parameters=[OpenApiParameter("date", str, description="ISO date filter.")],
        examples=[
            OpenApiExample(
                "Create breakfast",
                request_only=True,
                value={
                    "date": "2026-06-29",
                    "meal_type": "breakfast",
                    "name": "High protein breakfast",
                    "timezone": "Asia/Kolkata",
                },
            )
        ],
    )
    def list(self, request, *args, **kwargs):
        return super().list(request, *args, **kwargs)

    @extend_schema(tags=["meals"], request=MealLogSerializer)
    def create(self, request, *args, **kwargs):
        return super().create(request, *args, **kwargs)

    def perform_update(self, serializer):
        old_date = serializer.instance.date
        meal_log = serializer.save()
        recompute_daily_summary(self.request.user, old_date)
        if meal_log.date != old_date:
            recompute_daily_summary(self.request.user, meal_log.date)

    def perform_destroy(self, instance):
        date = instance.date
        instance.delete()
        recompute_daily_summary(self.request.user, date)

    @extend_schema(
        tags=["meals"],
        request=MealLogItemSerializer,
        responses={201: MealLogItemSerializer},
        examples=[
            OpenApiExample(
                "Add paneer serving",
                request_only=True,
                value={
                    "food": "00000000-0000-0000-0000-000000000000",
                    "quantity": "1.000",
                    "unit": "serving",
                    "serving": "00000000-0000-0000-0000-000000000000",
                    "user_confirmed": True,
                },
            )
        ],
    )
    @action(detail=True, methods=["post"], url_path="items")
    def add_item(self, request, pk=None):
        meal_log = self.get_object()
        serializer = MealLogItemSerializer(
            data=request.data,
            context={**self.get_serializer_context(), "meal_log": meal_log},
        )
        serializer.is_valid(raise_exception=True)
        item = serializer.save()
        recompute_daily_summary(request.user, meal_log.date)
        return Response(
            MealLogItemSerializer(item, context=self.get_serializer_context()).data,
            status=status.HTTP_201_CREATED,
        )

    @extend_schema(tags=["meals"], responses={200: MealLogSerializer})
    @action(detail=True, methods=["post", "delete"], url_path="favorite")
    def favorite(self, request, pk=None):
        meal_log = self.get_object()
        meal_log.is_favorite = request.method == "POST"
        meal_log.save(update_fields=["is_favorite", "updated_at"])
        return Response(self.get_serializer(meal_log).data)

    @extend_schema(
        tags=["meals"],
        request=CopyYesterdayMealsSerializer,
        responses={201: MealLogSerializer(many=True)},
    )
    @action(detail=False, methods=["post"], url_path="copy-yesterday")
    def copy_yesterday(self, request):
        serializer = CopyYesterdayMealsSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        copied_meals = copy_meals_from_previous_day(
            request.user,
            serializer.validated_data["date"],
        )
        return Response(
            self.get_serializer(copied_meals, many=True).data,
            status=status.HTTP_201_CREATED,
        )


class MealLogItemDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = MealLogItemSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = "id"
    http_method_names = ["get", "patch", "delete", "head", "options"]

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return MealLogItem.objects.none()
        return (
            MealLogItem.objects.filter(user=self.request.user)
            .select_related("meal_log", "food", "food__source", "serving")
            .prefetch_related(
                "food__servings",
                "food__nutrients__nutrient",
                "food__nutrients__source",
            )
        )

    @extend_schema(tags=["meals"], request=MealLogItemSerializer)
    def patch(self, request, *args, **kwargs):
        return super().patch(request, *args, **kwargs)

    def perform_update(self, serializer):
        item = serializer.save()
        recompute_daily_summary(self.request.user, item.meal_log.date)

    def perform_destroy(self, instance):
        date = instance.meal_log.date
        instance.delete()
        recompute_daily_summary(self.request.user, date)


class DailyNutritionSummaryView(generics.GenericAPIView):
    serializer_class = DailyNutritionSummarySerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(
        tags=["nutrition"],
        parameters=[
            OpenApiParameter(
                "date",
                str,
                required=False,
                description="ISO date. Defaults to today in the server timezone.",
            )
        ],
        responses={200: DailyNutritionSummarySerializer},
    )
    def get(self, request, *args, **kwargs):
        date_value = request.query_params.get("date")
        if date_value:
            date_serializer = DateQuerySerializer(data={"date": date_value})
            date_serializer.is_valid(raise_exception=True)
            date = date_serializer.validated_data["date"]
        else:
            date = timezone.localdate()
        summary = get_or_recompute_daily_summary(request.user, date)
        return Response(self.get_serializer(summary).data)


class RangeNutritionSummaryView(generics.GenericAPIView):
    serializer_class = RangeQuerySerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(
        tags=["nutrition"],
        parameters=[
            OpenApiParameter(
                "start",
                str,
                required=True,
                description="ISO start date.",
            ),
            OpenApiParameter("end", str, required=True, description="ISO end date."),
        ],
    )
    def get(self, request, *args, **kwargs):
        serializer = RangeQuerySerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        start = serializer.validated_data["start"]
        end = serializer.validated_data["end"]
        days = []
        totals = {
            "calories_kcal": Decimal("0"),
            "protein_g": Decimal("0"),
            "carbs_g": Decimal("0"),
            "fat_g": Decimal("0"),
            "fiber_g": Decimal("0"),
            "sugar_g": Decimal("0"),
            "sodium_mg": Decimal("0"),
        }
        current = start
        while current <= end:
            summary = get_or_recompute_daily_summary(request.user, current)
            day_payload = DailyNutritionSummarySerializer(summary).data
            days.append(day_payload)
            for field in totals:
                totals[field] += getattr(summary, field)
            current += timedelta(days=1)

        day_count = Decimal(len(days)) if days else Decimal("1")
        averages = {
            field: decimal_to_snapshot(total / day_count)
            for field, total in totals.items()
        }
        total_payload = {
            field: decimal_to_snapshot(total) for field, total in totals.items()
        }
        return Response(
            {
                "start": start,
                "end": end,
                "days": days,
                "totals": total_payload,
                "averages": averages,
                "macro_percentage_split": macro_percentage_split(total_payload),
                "daily_target_progress": target_progress_for_values(
                    averages,
                    daily_targets_for_user(request.user, end),
                ),
            }
        )
