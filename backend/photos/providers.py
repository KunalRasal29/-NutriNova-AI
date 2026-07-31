from __future__ import annotations

import base64
import json
import mimetypes
from decimal import Decimal
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

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

    MEAL_SCHEMA = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "detected_foods": {
                "type": "array",
                "maxItems": 20,
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "name": {"type": "string"},
                        "normalized_name": {"type": "string"},
                        "quantity_value": {"type": ["number", "null"]},
                        "quantity_unit": {
                            "type": "string",
                            "enum": [
                                "piece",
                                "egg",
                                "slice",
                                "bowl",
                                "cup",
                                "glass",
                                "tablespoon",
                                "teaspoon",
                                "serving",
                                "gram",
                                "ml",
                                "handful",
                                "scoop",
                                "packet",
                                "custom",
                            ],
                        },
                        "grams_per_unit_estimate": {"type": ["number", "null"]},
                        "total_grams_estimate": {"type": ["number", "null"]},
                        "min_total_grams_estimate": {"type": ["number", "null"]},
                        "max_total_grams_estimate": {"type": ["number", "null"]},
                        "count_confidence": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                        },
                        "portion_confidence": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                        },
                        "confidence": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                        },
                        "reasoning_short": {"type": "string"},
                    },
                    "required": [
                        "name",
                        "normalized_name",
                        "quantity_value",
                        "quantity_unit",
                        "grams_per_unit_estimate",
                        "total_grams_estimate",
                        "min_total_grams_estimate",
                        "max_total_grams_estimate",
                        "count_confidence",
                        "portion_confidence",
                        "confidence",
                        "reasoning_short",
                    ],
                },
            },
            "confidence": {"type": "number", "minimum": 0, "maximum": 1},
        },
        "required": ["detected_foods", "confidence"],
    }

    LABEL_SCHEMA = {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "product_name": {"type": "string"},
            "brand": {"type": "string"},
            "serving_size": {"type": "string"},
            "barcode": {"type": "string"},
            "parsed_nutrients": {
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "calories": {"type": ["number", "null"]},
                    "protein_g": {"type": ["number", "null"]},
                    "carbs_g": {"type": ["number", "null"]},
                    "fat_g": {"type": ["number", "null"]},
                    "fiber_g": {"type": ["number", "null"]},
                    "sugar_g": {"type": ["number", "null"]},
                    "sodium_mg": {"type": ["number", "null"]},
                },
                "required": [
                    "calories",
                    "protein_g",
                    "carbs_g",
                    "fat_g",
                    "fiber_g",
                    "sugar_g",
                    "sodium_mg",
                ],
            },
            "ingredients_text": {"type": "string"},
            "allergens": {"type": "array", "items": {"type": "string"}},
            "confidence": {"type": "number", "minimum": 0, "maximum": 1},
        },
        "required": [
            "product_name",
            "brand",
            "serving_size",
            "barcode",
            "parsed_nutrients",
            "ingredients_text",
            "allergens",
            "confidence",
        ],
    }

    def _require_api_key(self):
        api_key = getattr(settings, "OPENAI_API_KEY", "")
        if not api_key:
            raise PhotoAnalysisProviderError("OPENAI_API_KEY is not configured.")
        return api_key

    def _image_data_url(self, analysis):
        image = analysis.image
        mime_type = mimetypes.guess_type(image.name)[0] or "image/jpeg"
        with image.open("rb") as image_file:
            encoded = base64.b64encode(image_file.read()).decode("ascii")
        return f"data:{mime_type};base64,{encoded}"

    def _extract_output_text(self, response):
        if isinstance(response.get("output_text"), str):
            return response["output_text"]
        parts = []
        for output in response.get("output", []):
            if output.get("type") != "message":
                continue
            for content in output.get("content", []):
                if content.get("type") == "output_text" and content.get("text"):
                    parts.append(content["text"])
        if not parts:
            raise PhotoAnalysisProviderError(
                "The AI service returned no readable analysis. Please try again."
            )
        return "".join(parts)

    def _request_structured_analysis(self, analysis, *, prompt, schema, schema_name):
        payload = {
            "model": getattr(settings, "OPENAI_VISION_MODEL", "gpt-5.6"),
            "store": False,
            "input": [
                {
                    "role": "user",
                    "content": [
                        {"type": "input_text", "text": prompt},
                        {
                            "type": "input_image",
                            "image_url": self._image_data_url(analysis),
                            "detail": "auto",
                        },
                    ],
                }
            ],
            "text": {
                "format": {
                    "type": "json_schema",
                    "name": schema_name,
                    "strict": True,
                    "schema": schema,
                }
            },
        }
        request = Request(
            "https://api.openai.com/v1/responses",
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {self._require_api_key()}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            timeout = int(getattr(settings, "OPENAI_REQUEST_TIMEOUT_SECONDS", 60))
            with urlopen(request, timeout=timeout) as api_response:  # noqa: S310
                response = json.loads(api_response.read().decode("utf-8"))
        except HTTPError as exc:
            message = "The AI service could not analyze this image."
            try:
                error_payload = json.loads(exc.read().decode("utf-8"))
                message = error_payload.get("error", {}).get("message") or message
            except (UnicodeDecodeError, json.JSONDecodeError):
                pass
            raise PhotoAnalysisProviderError(message) from exc
        except (URLError, TimeoutError) as exc:
            raise PhotoAnalysisProviderError(
                "The AI service is temporarily unreachable. Please try again."
            ) from exc
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise PhotoAnalysisProviderError(
                "The AI service returned an unreadable response. Please try again."
            ) from exc

        try:
            result = json.loads(self._extract_output_text(response))
        except json.JSONDecodeError as exc:
            raise PhotoAnalysisProviderError(
                "The AI analysis was incomplete. Please try again."
            ) from exc
        result["provider"] = self.provider_name
        result["disclaimer"] = PHOTO_DISCLAIMER
        return result

    def analyze_meal_photo(self, analysis):
        return self._request_structured_analysis(
            analysis,
            schema=self.MEAL_SCHEMA,
            schema_name="meal_photo_analysis",
            prompt=(
                "Identify every distinct food visible in this meal photo. Estimate "
                "counts for countable foods and grams for uncountable portions. "
                "Give conservative min/max gram ranges and honest confidence scores. "
                "Use common searchable food names, do not invent ingredients that "
                "are not visible, and keep reasoning_short under 20 words. This is "
                "only a wellness estimate and the user will review every item."
            ),
        )

    def analyze_nutrition_label(self, analysis):
        return self._request_structured_analysis(
            analysis,
            schema=self.LABEL_SCHEMA,
            schema_name="nutrition_label_analysis",
            prompt=(
                "Read only values visibly printed on this nutrition label. Extract "
                "the product, brand, serving size, barcode when visible, nutrients "
                "per printed serving, ingredients, and allergens. Use null for a "
                "nutrient that is not visible and an empty string for missing text. "
                "Do not calculate or guess missing label values."
            ),
        )


def get_photo_analysis_provider():
    provider_name = getattr(settings, "PHOTO_ANALYSIS_PROVIDER", "mock").lower()
    if provider_name == "openai" and getattr(settings, "OPENAI_API_KEY", ""):
        return OpenAIPhotoAnalysisProvider()
    return MockPhotoAnalysisProvider()
