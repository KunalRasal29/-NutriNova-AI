from __future__ import annotations

from decimal import Decimal

from django.conf import settings

PHOTO_DISCLAIMER = (
    "Photo nutrition is an estimate. Confirm food and portion size for better accuracy."
)


class PhotoAnalysisProviderError(Exception):
    pass


class BasePhotoAnalysisProvider:
    provider_name = "manual"

    def analyze_meal_photo(self, analysis):
        raise NotImplementedError

    def analyze_nutrition_label(self, analysis):
        raise NotImplementedError


class MockPhotoAnalysisProvider(BasePhotoAnalysisProvider):
    provider_name = "local_model"

    def analyze_meal_photo(self, analysis):
        image_name = analysis.image.name.lower()
        low_confidence = "low" in image_name or "uncertain" in image_name
        if "egg" in image_name:
            return {
                "provider": self.provider_name,
                "detected_foods": [
                    {
                        "name": "boiled egg",
                        "normalized_name": "egg",
                        "quantity_value": "5",
                        "quantity_unit": "egg",
                        "grams_per_unit_estimate": "50.000",
                        "total_grams_estimate": "250.000",
                        "min_total_grams_estimate": "225.000",
                        "max_total_grams_estimate": "275.000",
                        "count_confidence": "0.9200",
                        "portion_confidence": "0.8000",
                        "confidence": "0.8800",
                        "reasoning_short": (
                            "Five egg-shaped items are visible on the plate."
                        ),
                    }
                ],
                "confidence": "0.8800",
                "disclaimer": PHOTO_DISCLAIMER,
            }
        confidence = Decimal("0.5200") if low_confidence else Decimal("0.8600")
        detected_name = "Mystery curry" if low_confidence else "Paneer"
        estimated_grams = Decimal("180.000") if low_confidence else Decimal("100.000")
        return {
            "provider": self.provider_name,
            "detected_foods": [
                {
                    "name": detected_name,
                    "normalized_name": detected_name.lower(),
                    "quantity_value": "1",
                    "quantity_unit": "serving",
                    "grams_per_unit_estimate": str(estimated_grams),
                    "total_grams_estimate": str(estimated_grams),
                    "min_total_grams_estimate": str(estimated_grams * Decimal("0.85")),
                    "max_total_grams_estimate": str(estimated_grams * Decimal("1.15")),
                    "count_confidence": str(confidence),
                    "portion_confidence": str(confidence),
                    "estimated_portion": "1 serving",
                    "estimated_grams": str(estimated_grams),
                    "confidence": str(confidence),
                    "reasoning_short": (
                        "Low visual certainty in mock analysis."
                        if low_confidence
                        else "Mock provider detected a paneer-like item."
                    ),
                }
            ],
            "confidence": str(confidence),
            "disclaimer": PHOTO_DISCLAIMER,
        }

    def analyze_nutrition_label(self, analysis):
        return {
            "provider": self.provider_name,
            "product_name": "Mock Protein Bar",
            "brand": "NutriNova Sample",
            "serving_size": "1 bar (50 g)",
            "barcode": "8900000000999",
            "parsed_nutrients": {
                "calories": "210.0000",
                "protein_g": "20.0000",
                "carbs_g": "22.0000",
                "fat_g": "7.0000",
                "fiber_g": "5.0000",
                "sugar_g": "3.0000",
                "sodium_mg": "180.0000",
            },
            "ingredients_text": "Mock oats, whey protein, peanuts.",
            "allergens": ["milk", "peanuts"],
            "confidence": "0.8400",
            "disclaimer": PHOTO_DISCLAIMER,
        }


class OpenAIPhotoAnalysisProvider(BasePhotoAnalysisProvider):
    provider_name = "openai"

    def _require_api_key(self):
        api_key = getattr(settings, "OPENAI_API_KEY", "")
        if not api_key:
            raise PhotoAnalysisProviderError("OPENAI_API_KEY is not configured.")
        return api_key

    def analyze_meal_photo(self, analysis):
        self._require_api_key()
        raise PhotoAnalysisProviderError(
            "OpenAI photo analysis transport is intentionally disabled until "
            "a reviewed prompt and network policy are configured."
        )

    def analyze_nutrition_label(self, analysis):
        self._require_api_key()
        raise PhotoAnalysisProviderError(
            "OpenAI nutrition label OCR transport is intentionally disabled until "
            "a reviewed prompt and network policy are configured."
        )


def get_photo_analysis_provider():
    provider_name = getattr(settings, "PHOTO_ANALYSIS_PROVIDER", "mock").lower()
    if provider_name == "openai" and getattr(settings, "OPENAI_API_KEY", ""):
        return OpenAIPhotoAnalysisProvider()
    return MockPhotoAnalysisProvider()
