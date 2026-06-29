from __future__ import annotations

from pathlib import Path

from django.conf import settings
from django.core.exceptions import ValidationError
from django.utils.text import get_valid_filename


def validate_uploaded_image(image):
    max_bytes = getattr(settings, "IMAGE_UPLOAD_MAX_BYTES", 8 * 1024 * 1024)
    allowed_types = set(getattr(settings, "IMAGE_UPLOAD_ALLOWED_TYPES", []))
    allowed_extensions = set(getattr(settings, "IMAGE_UPLOAD_ALLOWED_EXTENSIONS", []))

    if image.size > max_bytes:
        max_mb = max_bytes / (1024 * 1024)
        raise ValidationError(f"Image must be {max_mb:.0f}MB or smaller.")

    content_type = (getattr(image, "content_type", "") or "").lower()
    if allowed_types and content_type not in allowed_types:
        raise ValidationError("Unsupported image type.")

    original_name = Path(image.name).name
    safe_name = get_valid_filename(original_name)
    if not safe_name:
        raise ValidationError("Image filename is not valid.")
    image.name = safe_name

    extension = Path(safe_name).suffix.lower()
    if allowed_extensions and extension not in allowed_extensions:
        raise ValidationError("Unsupported image extension.")

    return image
