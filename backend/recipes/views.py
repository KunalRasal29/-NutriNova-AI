from __future__ import annotations

from drf_spectacular.utils import OpenApiExample, extend_schema
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from meals.serializers import MealLogSerializer
from recipes.models import Recipe
from recipes.serializers import (
    RecipeCalculationSerializer,
    RecipeLogAsMealResponseSerializer,
    RecipeLogAsMealSerializer,
    RecipeSerializer,
)
from recipes.services import calculate_recipe_totals, log_recipe_as_meal


class RecipeViewSet(viewsets.ModelViewSet):
    serializer_class = RecipeSerializer
    permission_classes = [IsAuthenticated]
    http_method_names = ["get", "post", "patch", "delete", "head", "options"]

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return Recipe.objects.none()
        return (
            Recipe.objects.filter(user=self.request.user)
            .prefetch_related(
                "ingredients__food",
                "ingredients__serving",
            )
            .order_by("name")
        )

    @extend_schema(
        tags=["recipes"],
        request=RecipeSerializer,
        examples=[
            OpenApiExample(
                "Create recipe",
                request_only=True,
                value={
                    "name": "Paneer bowl",
                    "servings": "2.00",
                    "visibility": "private",
                    "cuisine": "Indian",
                    "tags": ["high_protein"],
                    "ingredients": [
                        {
                            "food": "00000000-0000-0000-0000-000000000000",
                            "quantity": "200.000",
                            "unit": "grams",
                        }
                    ],
                },
            )
        ],
    )
    def create(self, request, *args, **kwargs):
        return super().create(request, *args, **kwargs)

    def perform_create(self, serializer):
        serializer.save()

    @extend_schema(
        tags=["recipes"],
        responses={200: RecipeCalculationSerializer},
    )
    @action(detail=True, methods=["post"], url_path="calculate")
    def calculate(self, request, pk=None):
        recipe = self.get_object()
        payload = calculate_recipe_totals(recipe)
        return Response(RecipeCalculationSerializer(payload).data)

    @extend_schema(
        tags=["recipes"],
        request=RecipeLogAsMealSerializer,
        responses={201: RecipeLogAsMealResponseSerializer},
    )
    @action(detail=True, methods=["post"], url_path="log-as-meal")
    def log_as_meal(self, request, pk=None):
        recipe = self.get_object()
        serializer = RecipeLogAsMealSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        meal_log = log_recipe_as_meal(
            recipe,
            request.user,
            serializer.validated_data,
        )
        return Response(
            {"meal": MealLogSerializer(meal_log, context={"request": request}).data},
            status=status.HTTP_201_CREATED,
        )
