from __future__ import annotations

from django.conf import settings
from drf_spectacular.utils import OpenApiExample, extend_schema
from rest_framework import generics, status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from foods.serializers import FoodDetailSerializer
from meals.serializers import MealLogSerializer
from photos.models import PhotoAnalysis, PhotoDetectedFood
from photos.providers import PHOTO_DISCLAIMER
from photos.serializers import (
    ConfirmLabelFoodResponseSerializer,
    ConfirmPhotoMealResponseSerializer,
    ConfirmPhotoMealSerializer,
    ManualPhotoFoodAddSerializer,
    MatchFoodsResponseSerializer,
    PhotoAnalysisDetailSerializer,
    PhotoAnalysisUploadSerializer,
    PhotoDetectedFoodUpdateSerializer,
    PhotoReviewResponseSerializer,
)
from photos.services import (
    add_manual_food_to_analysis,
    build_review_reasons,
    confirm_analysis_as_meal,
    confirm_label_as_food,
    decrement_detected_food,
    increment_detected_food,
    match_detected_foods,
    recalculate_analysis_preview,
    update_detected_food,
)
from photos.services.photo_nutrition_preview import review_payload
from photos.tasks import analyze_photo_analysis_task


def enqueue_photo_analysis(analysis: PhotoAnalysis) -> None:
    if getattr(settings, "CELERY_TASK_ALWAYS_EAGER", False):
        analyze_photo_analysis_task.apply(args=[str(analysis.id)], throw=True)
    else:
        analyze_photo_analysis_task.delay(str(analysis.id))


class PhotoAnalysisBaseView(generics.GenericAPIView):
    serializer_class = PhotoAnalysisDetailSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = "id"

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return PhotoAnalysis.objects.none()
        return (
            PhotoAnalysis.objects.filter(user=self.request.user)
            .prefetch_related(
                "detected_foods__matched_food",
                "detected_foods__matched_food__servings",
                "detected_foods__matched_food__nutrients__nutrient",
                "detected_foods__matched_food__nutrients__source",
            )
            .select_related("user")
        )


class AnalyzeMealPhotoView(generics.GenericAPIView):
    serializer_class = PhotoAnalysisUploadSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]
    throttle_scope = "photo_upload"

    @extend_schema(
        tags=["photos"],
        request=PhotoAnalysisUploadSerializer,
        responses={201: PhotoAnalysisDetailSerializer},
        examples=[
            OpenApiExample(
                "Upload meal photo",
                request_only=True,
                value={"image": "<multipart file>"},
            )
        ],
    )
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        analysis = PhotoAnalysis.objects.create(
            user=request.user,
            image=serializer.validated_data["image"],
            analysis_type=PhotoAnalysis.AnalysisType.MEAL_PHOTO,
        )
        enqueue_photo_analysis(analysis)
        analysis.refresh_from_db()
        return Response(
            PhotoAnalysisDetailSerializer(
                analysis,
                context={"request": request},
            ).data,
            status=status.HTTP_201_CREATED,
        )


class AnalyzeNutritionLabelView(generics.GenericAPIView):
    serializer_class = PhotoAnalysisUploadSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]
    throttle_scope = "photo_upload"

    @extend_schema(
        tags=["photos"],
        request=PhotoAnalysisUploadSerializer,
        responses={201: PhotoAnalysisDetailSerializer},
    )
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        analysis = PhotoAnalysis.objects.create(
            user=request.user,
            image=serializer.validated_data["image"],
            analysis_type=PhotoAnalysis.AnalysisType.NUTRITION_LABEL,
        )
        enqueue_photo_analysis(analysis)
        analysis.refresh_from_db()
        return Response(
            PhotoAnalysisDetailSerializer(
                analysis,
                context={"request": request},
            ).data,
            status=status.HTTP_201_CREATED,
        )


class PhotoAnalysisDetailView(PhotoAnalysisBaseView):
    @extend_schema(tags=["photos"], responses={200: PhotoAnalysisDetailSerializer})
    def get(self, request, *args, **kwargs):
        return Response(self.get_serializer(self.get_object()).data)


class PhotoAnalysisReviewView(PhotoAnalysisBaseView):
    @extend_schema(tags=["photos"], responses={200: PhotoReviewResponseSerializer})
    def get(self, request, *args, **kwargs):
        return Response(review_payload(self.get_object(), request=request))


class MatchPhotoFoodsView(PhotoAnalysisBaseView):
    @extend_schema(
        tags=["photos"],
        responses={200: MatchFoodsResponseSerializer},
    )
    def post(self, request, *args, **kwargs):
        analysis = self.get_object()
        match_detected_foods(analysis)
        analysis.refresh_from_db()
        raw_response = analysis.raw_ai_response or {}
        raw_response["review_reasons"] = build_review_reasons(analysis)
        analysis.raw_ai_response = raw_response
        analysis.save(update_fields=["raw_ai_response", "updated_at"])
        return Response(
            {
                "analysis": PhotoAnalysisDetailSerializer(
                    analysis,
                    context={"request": request},
                ).data
            }
        )


class RecalculatePhotoPreviewView(PhotoAnalysisBaseView):
    @extend_schema(tags=["photos"], responses={200: PhotoReviewResponseSerializer})
    def post(self, request, *args, **kwargs):
        analysis = self.get_object()
        return Response(recalculate_analysis_preview(analysis))


class AddManualPhotoFoodView(PhotoAnalysisBaseView):
    serializer_class = ManualPhotoFoodAddSerializer

    @extend_schema(
        tags=["photos"],
        request=ManualPhotoFoodAddSerializer,
        responses={201: PhotoReviewResponseSerializer},
    )
    def post(self, request, *args, **kwargs):
        analysis = self.get_object()
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        add_manual_food_to_analysis(analysis, serializer.validated_data)
        return Response(
            review_payload(analysis, request=request),
            status=status.HTTP_201_CREATED,
        )


class ConfirmPhotoAsMealView(PhotoAnalysisBaseView):
    serializer_class = ConfirmPhotoMealSerializer

    @extend_schema(
        tags=["photos"],
        request=ConfirmPhotoMealSerializer,
        responses={201: ConfirmPhotoMealResponseSerializer},
        examples=[
            OpenApiExample(
                "Confirm detected foods",
                request_only=True,
                value={
                    "date": "2026-06-29",
                    "meal_type": "lunch",
                    "name": "Photo lunch",
                    "items": [
                        {
                            "detected_food": "00000000-0000-0000-0000-000000000000",
                            "matched_food": "00000000-0000-0000-0000-000000000000",
                            "user_confirmed": True,
                            "user_corrected_grams": "120.000",
                        }
                    ],
                },
            )
        ],
    )
    def post(self, request, *args, **kwargs):
        analysis = self.get_object()
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        meal_log = confirm_analysis_as_meal(analysis, serializer.validated_data)
        return Response(
            {
                "meal": MealLogSerializer(
                    meal_log,
                    context={"request": request},
                ).data,
                "disclaimer": PHOTO_DISCLAIMER,
            },
            status=status.HTTP_201_CREATED,
        )


class ConfirmLabelAsFoodView(PhotoAnalysisBaseView):
    @extend_schema(
        tags=["photos"],
        responses={201: ConfirmLabelFoodResponseSerializer},
    )
    def post(self, request, *args, **kwargs):
        analysis = self.get_object()
        food = confirm_label_as_food(analysis)
        return Response(
            {
                "food": FoodDetailSerializer(
                    food,
                    context={"request": request},
                ).data,
                "disclaimer": PHOTO_DISCLAIMER,
            },
            status=status.HTTP_201_CREATED,
        )


class PhotoDetectedFoodBaseView(generics.GenericAPIView):
    serializer_class = PhotoDetectedFoodUpdateSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = "id"

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return PhotoDetectedFood.objects.none()
        return (
            PhotoDetectedFood.objects.filter(photo_analysis__user=self.request.user)
            .select_related(
                "photo_analysis",
                "photo_analysis__user",
                "matched_food",
                "matched_food__source",
            )
            .prefetch_related(
                "matched_food__servings",
                "matched_food__nutrients__nutrient",
                "matched_food__nutrients__source",
                "matched_food__aliases",
            )
        )


class PhotoDetectedFoodDetailView(PhotoDetectedFoodBaseView):
    @extend_schema(tags=["photos"], request=PhotoDetectedFoodUpdateSerializer)
    def patch(self, request, *args, **kwargs):
        detected = self.get_object()
        serializer = self.get_serializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        preview = update_detected_food(detected, serializer.validated_data)
        return Response(preview)


class IncrementDetectedFoodView(PhotoDetectedFoodBaseView):
    @extend_schema(tags=["photos"], responses={200: PhotoReviewResponseSerializer})
    def post(self, request, *args, **kwargs):
        return Response(increment_detected_food(self.get_object()))


class DecrementDetectedFoodView(PhotoDetectedFoodBaseView):
    @extend_schema(tags=["photos"], responses={200: PhotoReviewResponseSerializer})
    def post(self, request, *args, **kwargs):
        return Response(decrement_detected_food(self.get_object()))
