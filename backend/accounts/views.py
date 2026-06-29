from drf_spectacular.utils import OpenApiExample, OpenApiResponse, extend_schema
from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenRefreshView

from accounts.serializers import (
    AuthTokenResponseSerializer,
    LoginSerializer,
    LogoutSerializer,
    MeSerializer,
    RegisterSerializer,
)


class RegisterView(generics.CreateAPIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    serializer_class = RegisterSerializer

    @extend_schema(
        tags=["auth"],
        request=RegisterSerializer,
        responses={201: AuthTokenResponseSerializer},
        examples=[
            OpenApiExample(
                "Register",
                request_only=True,
                value={
                    "email": "anika@example.com",
                    "password": "strong-local-passphrase",
                    "display_name": "Anika",
                    "timezone": "Asia/Kolkata",
                    "country": "IN",
                },
            ),
        ],
    )
    def post(self, request, *args, **kwargs):
        return super().post(request, *args, **kwargs)


class LoginView(generics.CreateAPIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    serializer_class = LoginSerializer

    @extend_schema(
        tags=["auth"],
        request=LoginSerializer,
        responses={200: AuthTokenResponseSerializer},
        examples=[
            OpenApiExample(
                "Login",
                request_only=True,
                value={
                    "email": "anika@example.com",
                    "password": "strong-local-passphrase",
                },
            ),
        ],
    )
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(
            AuthTokenResponseSerializer(user).data, status=status.HTTP_200_OK
        )


class RefreshView(TokenRefreshView):
    @extend_schema(
        tags=["auth"],
        examples=[
            OpenApiExample(
                "Refresh",
                request_only=True,
                value={"refresh": "eyJ..."},
            ),
        ],
    )
    def post(self, request, *args, **kwargs):
        return super().post(request, *args, **kwargs)


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        tags=["auth"],
        request=LogoutSerializer,
        responses={204: OpenApiResponse(description="Refresh token blacklisted.")},
        examples=[
            OpenApiExample(
                "Logout",
                request_only=True,
                value={"refresh": "eyJ..."},
            ),
        ],
    )
    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = MeSerializer
    permission_classes = [IsAuthenticated]
    http_method_names = ["get", "patch", "head", "options"]

    def get_object(self):
        return self.request.user

    @extend_schema(
        tags=["profile"],
        responses={200: MeSerializer},
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    @extend_schema(
        tags=["profile"],
        request=MeSerializer,
        responses={200: MeSerializer},
        examples=[
            OpenApiExample(
                "Update onboarding profile",
                request_only=True,
                value={
                    "display_name": "Anika",
                    "height_cm": "164.00",
                    "weight_kg": "61.50",
                    "activity_level": "moderate",
                    "goal_type": "gain_muscle",
                    "dietary_preference": "vegetarian",
                    "allergies": ["peanuts"],
                    "disliked_foods": ["mushrooms"],
                    "target_weight_kg": "64.00",
                    "timezone": "Asia/Kolkata",
                    "country": "IN",
                    "has_completed_onboarding": True,
                    "onboarding_step": 4,
                },
            ),
        ],
    )
    def patch(self, request, *args, **kwargs):
        return super().patch(request, *args, **kwargs)
