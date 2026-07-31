from __future__ import annotations

import re
import unicodedata


def normalize_catalog_text(value: str | None) -> str:
    """Return a stable, accent-insensitive string for catalog search/deduping."""
    decomposed = unicodedata.normalize("NFKD", value or "")
    ascii_like = "".join(
        character for character in decomposed if not unicodedata.combining(character)
    )
    normalized = re.sub(r"[^\w\s]", " ", ascii_like.casefold(), flags=re.UNICODE)
    return " ".join(normalized.split())
