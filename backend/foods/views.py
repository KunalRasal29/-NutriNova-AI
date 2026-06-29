import uuid

from django.contrib.postgres.search import SearchQuery, SearchRank, TrigramSimilarity
from django.db.models import Q
from django.db.models.functions import Greatest
from drf_spectacular.utils import OpenApiExample, OpenApiParameter, extend_schema
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from foods.models import FavoriteFood
from foods.serializers import (
    CustomFoodCreateSerializer,
    FoodDetailSerializer,
    FoodSearchResultSerializer,
)
from foods.services.custom_foods import visible_foods_for_user


class FoodSearchView(generics.ListAPIView):
    serializer_class = FoodSearchResultSerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(
        tags=["foods"],
        parameters=[
            OpenApiParameter("q", str, description="Fuzzy food name search query."),
            OpenApiParameter(
                "source",
                str,
                description="Source type, source id, or name.",
            ),
            OpenApiParameter("barcode", str, description="Exact barcode lookup."),
        ],
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    def get_queryset(self):
        request = self.request
        queryset = (
            visible_foods_for_user(request.user)
            .select_related("source")
            .prefetch_related("servings", "nutrients__nutrient", "nutrients__source")
        )

        barcode = request.query_params.get("barcode", "").strip()
        if barcode:
            queryset = queryset.filter(barcode=barcode)

        source = request.query_params.get("source", "").strip()
        if source:
            source_filter = Q(source__source_type__iexact=source) | Q(
                source__name__icontains=source
            )
            try:
                source_filter |= Q(source_id=uuid.UUID(source))
            except ValueError:
                pass
            queryset = queryset.filter(source_filter)

        query = request.query_params.get("q", "").strip()
        if query:
            search_query = SearchQuery(query)
            queryset = queryset.annotate(
                search_rank=SearchRank("search_vector", search_query),
                similarity=Greatest(
                    TrigramSimilarity("canonical_name", query),
                    TrigramSimilarity("brand_name", query),
                    TrigramSimilarity("search_text", query),
                ),
            ).filter(
                Q(search_rank__gt=0)
                | Q(similarity__gt=0.1)
                | Q(canonical_name__icontains=query)
                | Q(brand_name__icontains=query)
                | Q(aliases__alias__icontains=query)
            )
            queryset = queryset.order_by("-verified", "-search_rank", "-similarity")
        else:
            queryset = queryset.order_by("-verified", "canonical_name")

        return queryset.distinct()


class FoodDetailView(generics.RetrieveAPIView):
    serializer_class = FoodDetailSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = "id"

    @extend_schema(tags=["foods"], responses={200: FoodDetailSerializer})
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    def get_queryset(self):
        return (
            visible_foods_for_user(self.request.user)
            .select_related("source", "created_by")
            .prefetch_related(
                "aliases",
                "servings",
                "nutrients__nutrient",
                "nutrients__source",
            )
        )


class CustomFoodCreateView(generics.CreateAPIView):
    serializer_class = CustomFoodCreateSerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(
        tags=["foods"],
        request=CustomFoodCreateSerializer,
        responses={201: FoodDetailSerializer},
        examples=[
            OpenApiExample(
                "Create custom paneer",
                request_only=True,
                value={
                    "canonical_name": "Homemade paneer",
                    "brand_name": "",
                    "country_code": "IN",
                    "serving_description": "1 bowl",
                    "default_serving_g": "100.00",
                    "nutrients": [
                        {
                            "nutrient_code": "calories",
                            "amount_per_100g": "265.0000",
                            "confidence_score": "0.6000",
                            "derivation_method": "user_entered",
                        },
                        {
                            "nutrient_code": "protein_g",
                            "amount_per_100g": "18.3000",
                            "confidence_score": "0.6000",
                            "derivation_method": "user_entered",
                        },
                    ],
                },
            )
        ],
    )
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        food = serializer.save()
        return Response(
            FoodDetailSerializer(food, context=self.get_serializer_context()).data,
            status=status.HTTP_201_CREATED,
        )


class FoodFavoriteView(generics.GenericAPIView):
    serializer_class = FoodDetailSerializer
    permission_classes = [IsAuthenticated]

    def get_food(self, request, id):
        return generics.get_object_or_404(visible_foods_for_user(request.user), id=id)

    @extend_schema(tags=["foods"], responses={200: FoodDetailSerializer})
    def post(self, request, id):
        food = self.get_food(request, id)
        FavoriteFood.objects.get_or_create(user=request.user, food=food)
        return Response(FoodDetailSerializer(food, context={"request": request}).data)

    @extend_schema(tags=["foods"], responses={200: FoodDetailSerializer})
    def delete(self, request, id):
        food = self.get_food(request, id)
        FavoriteFood.objects.filter(user=request.user, food=food).delete()
        return Response(FoodDetailSerializer(food, context={"request": request}).data)
