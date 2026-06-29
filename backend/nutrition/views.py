from drf_spectacular.utils import extend_schema
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from nutrition.models import Nutrient, NutritionDataSource
from nutrition.serializers import NutrientSerializer, NutritionDataSourceSerializer


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
