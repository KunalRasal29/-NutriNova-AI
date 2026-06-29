from django.db import connection
from drf_spectacular.utils import OpenApiExample, extend_schema
from rest_framework import serializers, status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView


class HealthCheckResponseSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=("ok", "degraded"))
    service = serializers.CharField()
    checks = serializers.DictField(child=serializers.CharField())
    disclaimer = serializers.CharField()


class HealthCheckView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(
        tags=["system"],
        responses={
            200: HealthCheckResponseSerializer,
            503: HealthCheckResponseSerializer,
        },
        examples=[
            OpenApiExample(
                "Healthy",
                value={
                    "status": "ok",
                    "service": "NutriNova AI API",
                    "checks": {"database": "ok"},
                    "disclaimer": (
                        "NutriNova AI is for wellness tracking only and is not "
                        "medical diagnosis, treatment, or emergency guidance."
                    ),
                },
            )
        ],
    )
    def get(self, request):
        checks = {"database": "ok"}
        status_code = status.HTTP_200_OK

        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()
        except Exception:
            checks["database"] = "unavailable"
            status_code = status.HTTP_503_SERVICE_UNAVAILABLE

        return Response(
            {
                "status": "ok" if status_code == status.HTTP_200_OK else "degraded",
                "service": "NutriNova AI API",
                "checks": checks,
                "disclaimer": (
                    "NutriNova AI is for wellness tracking only and is not medical "
                    "diagnosis, treatment, or emergency guidance."
                ),
            },
            status=status_code,
        )
