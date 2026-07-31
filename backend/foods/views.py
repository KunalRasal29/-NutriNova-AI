import logging
import uuid

from django.conf import settings
from django.contrib.postgres.search import SearchQuery, SearchRank, TrigramSimilarity
from django.db.models import (
    Case,
    Count,
    Exists,
    IntegerField,
    Max,
    OuterRef,
    Prefetch,
    Q,
    Value,
    When,
)
from django.db.models.functions import Greatest
from drf_spectacular.utils import OpenApiExample, OpenApiParameter, extend_schema
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from foods.models import (
    CustomFoodProfile,
    CustomFoodVersion,
    FavoriteFood,
    Food,
    UserPortionPreference,
)
from foods.search import normalize_search_query, search_variants
from foods.serializers import (
    CustomFoodConfirmSerializer,
    CustomFoodCreateSerializer,
    CustomFoodEstimateRequestSerializer,
    CustomFoodLogSerializer,
    CustomFoodUpdateSerializer,
    CustomFoodVersionSerializer,
    FoodDetailSerializer,
    FoodSearchResultSerializer,
)
from foods.services.custom_food_estimation import estimate_custom_food
from foods.services.custom_foods import (
    confirm_custom_food,
    custom_foods_for_user,
    estimate_profile,
    update_custom_food,
    visible_foods_for_user,
)
from foods.services.openfoodfacts import sync_openfoodfacts_product
from meals.models import MealLogItem
from meals.serializers import ManualMealAddResponseSerializer
from meals.services.manual_add import add_food_to_meal

logger = logging.getLogger(__name__)


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
            OpenApiParameter(
                "food_type",
                str,
                description="Generic, branded, or custom.",
            ),
            OpenApiParameter("preparation_state", str),
            OpenApiParameter("dataset_type", str),
            OpenApiParameter("verified", bool),
        ],
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    def get_queryset(self):
        request = self.request
        queryset = (
            visible_foods_for_user(request.user)
            .select_related("source")
            .prefetch_related(
                "servings",
                "nutrients__nutrient",
                "nutrients__source",
                Prefetch(
                    "user_portion_preferences",
                    queryset=UserPortionPreference.objects.filter(user=request.user),
                    to_attr="request_portions",
                ),
            )
        )

        barcode = request.query_params.get("barcode", "").strip()
        if barcode:
            queryset = queryset.filter(barcode=barcode)

        food_type = request.query_params.get("food_type", "").strip()
        if food_type:
            queryset = queryset.filter(food_type=food_type)
        preparation_state = request.query_params.get("preparation_state", "").strip()
        if preparation_state:
            queryset = queryset.filter(preparation_state=preparation_state)
        dataset_type = request.query_params.get("dataset_type", "").strip()
        if dataset_type:
            queryset = queryset.filter(dataset_type=dataset_type)
        verified = request.query_params.get("verified", "").strip().lower()
        if verified in {"true", "1", "yes"}:
            queryset = queryset.filter(verified=True)
        elif verified in {"false", "0", "no"}:
            queryset = queryset.filter(verified=False)

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
            variants = search_variants(query)
            normalized_query = normalize_search_query(query)
            search_query = SearchQuery(normalized_query)
            priority_conditions = []
            for index, variant in enumerate(variants):
                base_priority = 100 - index
                priority_conditions.extend(
                    (
                        When(
                            canonical_name__iexact=variant,
                            then=Value(base_priority),
                        ),
                        When(
                            aliases__alias__iexact=variant,
                            then=Value(base_priority - 1),
                        ),
                        When(
                            normalized_name=variant,
                            then=Value(base_priority),
                        ),
                        When(
                            aliases__normalized_alias=variant,
                            then=Value(base_priority - 1),
                        ),
                        When(
                            canonical_name__istartswith=variant,
                            then=Value(base_priority - 2),
                        ),
                        When(
                            aliases__alias__istartswith=variant,
                            then=Value(base_priority - 3),
                        ),
                        When(
                            brand_name__iexact=variant,
                            then=Value(base_priority - 4),
                        ),
                    )
                )
            similarity_expressions = []
            match_filter = Q()
            for variant in variants:
                similarity_expressions.extend(
                    (
                        TrigramSimilarity("canonical_name", variant),
                        TrigramSimilarity("normalized_name", variant),
                        TrigramSimilarity("aliases__alias", variant),
                        TrigramSimilarity("aliases__normalized_alias", variant),
                        TrigramSimilarity("brand_name", variant),
                        TrigramSimilarity("search_text", variant),
                    )
                )
                match_filter |= (
                    Q(canonical_name__icontains=variant)
                    | Q(normalized_name__icontains=variant)
                    | Q(brand_name__icontains=variant)
                    | Q(aliases__alias__icontains=variant)
                    | Q(aliases__normalized_alias__icontains=variant)
                )
            queryset = queryset.annotate(
                match_priority=Case(
                    *priority_conditions,
                    default=Value(0),
                    output_field=IntegerField(),
                ),
                search_rank=SearchRank("search_vector", search_query),
                similarity=Greatest(*similarity_expressions),
                user_log_count=Count(
                    "meal_log_items",
                    filter=Q(meal_log_items__user=request.user),
                    distinct=True,
                ),
                last_logged_at=Max(
                    "meal_log_items__created_at",
                    filter=Q(meal_log_items__user=request.user),
                ),
                user_favorite=Exists(
                    FavoriteFood.objects.filter(
                        user=request.user,
                        food_id=OuterRef("pk"),
                    )
                ),
                source_priority=Case(
                    When(dataset_type=Food.DatasetType.USDA_FOUNDATION, then=Value(70)),
                    When(dataset_type=Food.DatasetType.USDA_FNDDS, then=Value(60)),
                    When(dataset_type=Food.DatasetType.USDA_SR_LEGACY, then=Value(50)),
                    When(dataset_type=Food.DatasetType.USDA_BRANDED, then=Value(40)),
                    When(dataset_type=Food.DatasetType.OPEN_FOOD_FACTS, then=Value(30)),
                    When(dataset_type=Food.DatasetType.INDIAN_LICENSED, then=Value(65)),
                    When(dataset_type=Food.DatasetType.USER_CUSTOM, then=Value(20)),
                    When(dataset_type=Food.DatasetType.AI_ESTIMATE, then=Value(10)),
                    default=Value(25),
                    output_field=IntegerField(),
                ),
            ).filter(Q(search_rank__gt=0) | Q(similarity__gt=0.2) | match_filter)
            queryset = queryset.order_by(
                "-match_priority",
                "-user_favorite",
                "-user_log_count",
                "-last_logged_at",
                "-verified",
                "-source_priority",
                "-source__reliability_score",
                "-data_quality_score",
                "-search_rank",
                "-similarity",
                "canonical_name",
            )
        else:
            queryset = queryset.order_by(
                "-verified",
                "-source__reliability_score",
                "-data_quality_score",
                "canonical_name",
            )

        return queryset.distinct()


class FoodCollectionBaseView(generics.ListAPIView):
    serializer_class = FoodSearchResultSerializer
    permission_classes = [IsAuthenticated]

    def base_queryset(self):
        return (
            visible_foods_for_user(self.request.user)
            .select_related("source")
            .prefetch_related(
                "servings",
                "nutrients__nutrient",
                "nutrients__source",
                Prefetch(
                    "user_portion_preferences",
                    queryset=UserPortionPreference.objects.filter(
                        user=self.request.user
                    ),
                    to_attr="request_portions",
                ),
            )
        )

    def ordered_queryset_for_ids(self, food_ids):
        ids = list(food_ids)
        if not ids:
            return self.base_queryset().none()
        ordering = Case(
            *[When(id=food_id, then=Value(index)) for index, food_id in enumerate(ids)],
            default=Value(len(ids)),
            output_field=IntegerField(),
        )
        return (
            self.base_queryset()
            .filter(id__in=ids)
            .annotate(collection_order=ordering)
            .order_by("collection_order", "canonical_name")
        )


class RecentFoodsView(FoodCollectionBaseView):
    @extend_schema(
        tags=["foods"], responses={200: FoodSearchResultSerializer(many=True)}
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    def get_queryset(self):
        recent_food_ids = []
        seen = set()
        logged_ids = (
            MealLogItem.objects.filter(user=self.request.user)
            .order_by("-created_at")
            .values_list("food_id", flat=True)[:250]
        )
        for food_id in logged_ids:
            if food_id in seen:
                continue
            seen.add(food_id)
            recent_food_ids.append(food_id)
            if len(recent_food_ids) >= 50:
                break
        return self.ordered_queryset_for_ids(recent_food_ids)


class FrequentFoodsView(FoodCollectionBaseView):
    @extend_schema(
        tags=["foods"], responses={200: FoodSearchResultSerializer(many=True)}
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    def get_queryset(self):
        meal_type = self.request.query_params.get("meal_type", "").strip()
        logged_items = MealLogItem.objects.filter(user=self.request.user)
        if meal_type:
            logged_items = logged_items.filter(meal_log__meal_type=meal_type)
        rows = (
            logged_items.values("food_id")
            .annotate(log_count=Count("id"), last_logged_at=Max("created_at"))
            .order_by("-log_count", "-last_logged_at")[:50]
        )
        return self.ordered_queryset_for_ids([row["food_id"] for row in rows])


class FavoriteFoodsView(FoodCollectionBaseView):
    @extend_schema(
        tags=["foods"], responses={200: FoodSearchResultSerializer(many=True)}
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    def get_queryset(self):
        food_ids = FavoriteFood.objects.filter(user=self.request.user).values_list(
            "food_id",
            flat=True,
        )[:100]
        return self.ordered_queryset_for_ids(food_ids)


class MyFoodsView(FoodCollectionBaseView):
    @extend_schema(
        tags=["foods"], responses={200: FoodSearchResultSerializer(many=True)}
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    def get_queryset(self):
        return self.base_queryset().filter(
            created_by=self.request.user,
            food_type=Food.FoodType.USER_CUSTOM,
        )


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


class BarcodeLookupView(generics.GenericAPIView):
    serializer_class = FoodSearchResultSerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(
        tags=["foods"],
        parameters=[
            OpenApiParameter(
                "barcode",
                str,
                required=True,
                description="Exact packaged-food barcode.",
            )
        ],
        responses={200: dict},
    )
    def get(self, request):
        barcode = request.query_params.get("barcode", "").strip()
        if not barcode:
            return Response(
                {"barcode": "", "results": [], "message": "Enter a barcode."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        queryset = (
            visible_foods_for_user(request.user)
            .filter(barcode=barcode)
            .select_related("source")
            .prefetch_related(
                "servings",
                "nutrients__nutrient",
                "nutrients__source",
                Prefetch(
                    "user_portion_preferences",
                    queryset=UserPortionPreference.objects.filter(
                        user=self.request.user
                    ),
                    to_attr="request_portions",
                ),
            )
        )
        food = queryset.first()
        attempted_live_lookup = False
        lookup_warning = ""

        if food is None and settings.OPENFOODFACTS_LIVE_LOOKUP:
            attempted_live_lookup = True
            if not settings.OPENFOODFACTS_USER_AGENT:
                lookup_warning = (
                    "Live lookup is enabled but OPENFOODFACTS_USER_AGENT "
                    "is not configured."
                )
            else:
                try:
                    food = sync_openfoodfacts_product(
                        barcode,
                        user_agent=settings.OPENFOODFACTS_USER_AGENT,
                    )
                except Exception:
                    logger.exception(
                        "Open Food Facts lookup failed for barcode %s",
                        barcode,
                    )
                    lookup_warning = (
                        "Open Food Facts is temporarily unavailable. "
                        "You can create a custom food instead."
                    )

        results = []
        if food is not None:
            results.append(
                FoodSearchResultSerializer(
                    food,
                    context={"request": request},
                ).data
            )
        return Response(
            {
                "barcode": barcode,
                "results": results,
                "live_lookup_enabled": settings.OPENFOODFACTS_LIVE_LOOKUP,
                "live_lookup_attempted": attempted_live_lookup,
                "message": (
                    lookup_warning
                    or (
                        "Product found."
                        if food is not None
                        else (
                            "Product not found locally. Live Open Food Facts "
                            "lookup is disabled, so you can create a custom food."
                        )
                    )
                ),
            }
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

    @extend_schema(tags=["foods"], responses={200: FoodDetailSerializer(many=True)})
    def get(self, request, *args, **kwargs):
        queryset = (
            custom_foods_for_user(request.user)
            .select_related("source", "custom_profile")
            .prefetch_related(
                "aliases",
                "servings",
                "nutrients__nutrient",
                "nutrients__source",
            )
            .order_by("-updated_at")
        )
        page = self.paginate_queryset(queryset)
        serializer = FoodDetailSerializer(
            page if page is not None else queryset,
            many=True,
            context={"request": request},
        )
        if page is not None:
            return self.get_paginated_response(serializer.data)
        return Response(serializer.data)


class CustomFoodEstimateView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        tags=["foods"],
        request=CustomFoodEstimateRequestSerializer,
        responses={200: dict},
    )
    def post(self, request):
        serializer = CustomFoodEstimateRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        estimate = estimate_custom_food(request.user, serializer.validated_data)
        return Response(estimate)


class CustomFoodOwnedMixin:
    def get_custom_food(self, request, id):
        queryset = (
            custom_foods_for_user(request.user)
            .select_related("source", "custom_profile")
            .prefetch_related(
                "aliases",
                "servings",
                "nutrients__nutrient",
                "nutrients__source",
            )
        )
        return generics.get_object_or_404(queryset, id=id)


class CustomFoodDetailView(CustomFoodOwnedMixin, APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(tags=["foods"], responses={200: FoodDetailSerializer})
    def get(self, request, id):
        food = self.get_custom_food(request, id)
        return Response(FoodDetailSerializer(food, context={"request": request}).data)

    @extend_schema(
        tags=["foods"],
        request=CustomFoodUpdateSerializer,
        responses={200: FoodDetailSerializer},
    )
    def patch(self, request, id):
        food = self.get_custom_food(request, id)
        serializer = CustomFoodUpdateSerializer(
            data=request.data,
            partial=True,
            context={"food": food},
        )
        serializer.is_valid(raise_exception=True)
        food = update_custom_food(food.custom_profile, serializer.validated_data)
        return Response(FoodDetailSerializer(food, context={"request": request}).data)


class CustomFoodReEstimateView(CustomFoodOwnedMixin, APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        tags=["foods"],
        request=CustomFoodEstimateRequestSerializer,
        responses={200: dict},
    )
    def post(self, request, id):
        food = self.get_custom_food(request, id)
        profile = food.custom_profile
        defaults = {
            "food_name": food.canonical_name,
            "preparation_method": food.preparation_state,
            "serving_name": food.serving_description,
            "serving_quantity": profile.serving_quantity,
            "serving_unit": profile.serving_unit,
            "serving_weight_g": profile.serving_weight_g,
            "ingredients": profile.ingredients,
        }
        serializer = CustomFoodEstimateRequestSerializer(
            data={**defaults, **request.data}
        )
        serializer.is_valid(raise_exception=True)
        estimate = estimate_profile(profile, serializer.validated_data)
        return Response(estimate)


class CustomFoodConfirmView(CustomFoodOwnedMixin, APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        tags=["foods"],
        request=CustomFoodConfirmSerializer,
        responses={200: FoodDetailSerializer},
    )
    def post(self, request, id):
        food = self.get_custom_food(request, id)
        serializer = CustomFoodConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        food = confirm_custom_food(food.custom_profile, **serializer.validated_data)
        return Response(FoodDetailSerializer(food, context={"request": request}).data)


class CustomFoodHistoryView(CustomFoodOwnedMixin, APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        tags=["foods"],
        responses={200: CustomFoodVersionSerializer(many=True)},
    )
    def get(self, request, id):
        food = self.get_custom_food(request, id)
        versions = CustomFoodVersion.objects.filter(user=request.user, food=food)
        return Response(CustomFoodVersionSerializer(versions, many=True).data)


class CustomFoodLogView(CustomFoodOwnedMixin, APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        tags=["foods"],
        request=CustomFoodLogSerializer,
        responses={201: ManualMealAddResponseSerializer},
    )
    def post(self, request, id):
        food = self.get_custom_food(request, id)
        if food.custom_profile.status != CustomFoodProfile.Status.CONFIRMED:
            return Response(
                {"detail": "Confirm nutrition before logging this custom food."},
                status=status.HTTP_409_CONFLICT,
            )
        serializer = CustomFoodLogSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        meal, item, preview = add_food_to_meal(
            request.user,
            {**serializer.validated_data, "food": food},
        )
        response = ManualMealAddResponseSerializer(
            {"meal": meal, "item": item, "preview": preview}
        )
        return Response(response.data, status=status.HTTP_201_CREATED)


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
