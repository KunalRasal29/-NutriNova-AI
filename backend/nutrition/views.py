from drf_spectacular.utils import extend_schema
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from nutrition.models import Nutrient, NutritionDataSource
from nutrition.serializers import (
    NutrientSerializer,
    NutritionDataSourceSerializer,
    NutritionTargetConfirmationSerializer,
    NutritionTargetUpdateSerializer,
)
from nutrition.targets import (
    estimate_targets,
    save_targets,
    target_plan_payload,
)


class NutrientListView(generics.ListAPIView):
    serializer_class = NutrientSerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(tags=["nutrition"], responses={200: NutrientSerializer(many=True)})
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    def get_queryset(self):
        return Nutrient.objects.all().order_by("nutrient_group", "name")


class DataSourceListView(generics.ListAPIView):
    serializer_class = NutritionDataSourceSerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(
        tags=["nutrition"],
        responses={200: NutritionDataSourceSerializer(many=True)},
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    def get_queryset(self):
        return NutritionDataSource.objects.filter(is_active=True).order_by("name")


class NutritionTargetsView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(tags=["nutrition targets"], responses={200: dict})
    def get(self, request):
        return Response(target_plan_payload(request.user.profile))

    @extend_schema(
        tags=["nutrition targets"],
        request=NutritionTargetUpdateSerializer,
        responses={200: dict},
    )
    def patch(self, request):
        serializer = NutritionTargetUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        save_targets(
            request.user.profile,
            serializer.validated_data,
            method="user_custom",
            customized=True,
        )
        return Response(target_plan_payload(request.user.profile))


class NutritionTargetEstimateView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(tags=["nutrition targets"], responses={200: dict})
    def get(self, request):
        profile = request.user.profile
        estimate = estimate_targets(profile)
        return Response(
            {
                "targets": {
                    code: str(value) for code, value in estimate["targets"].items()
                },
                "method": estimate["method"],
                "assumptions": estimate["assumptions"],
                "inputs_used": estimate["inputs_used"],
                "requires_confirmation": True,
                "disclaimer": (
                    "Review these wellness estimates before applying them. "
                    "They are not medical or dietary treatment advice."
                ),
            }
        )

    @extend_schema(
        tags=["nutrition targets"],
        request=NutritionTargetConfirmationSerializer,
        responses={200: dict},
    )
    def post(self, request):
        serializer = NutritionTargetConfirmationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile = request.user.profile
        estimate = estimate_targets(profile)
        save_targets(
            profile,
            estimate["targets"],
            method=estimate["method"],
            customized=False,
        )
        return Response(target_plan_payload(profile))
