from __future__ import annotations

from foods.text import normalize_catalog_text

SPELLING_CORRECTIONS = {
    "bananna": "banana",
    "bananana": "banana",
    "chappati": "chapati",
    "chapathi": "chapati",
    "chappathi": "chapati",
    "yoghurt": "yogurt",
    "yougurt": "yogurt",
    "biriyani": "biryani",
    "biriani": "biryani",
    "paneeer": "paneer",
    "kichdi": "khichdi",
    "khichri": "khichdi",
}

SEARCH_EQUIVALENT_GROUPS = (
    ("chapati", "roti", "phulka"),
    ("curd", "yogurt", "dahi"),
    ("dal", "lentil", "lentils"),
    ("chana", "chickpea", "chickpeas", "bengal gram"),
    ("rajma", "kidney bean", "kidney beans"),
    ("bhindi", "okra", "lady finger"),
    ("baingan", "brinjal", "eggplant"),
    ("poha", "flattened rice"),
    ("upma", "semolina porridge"),
    ("idli", "idly"),
    ("dosa", "dosai"),
    ("paneer", "indian cottage cheese"),
    ("khichdi", "khichri"),
    ("biryani", "biriyani"),
)


def normalize_search_query(value: str) -> str:
    normalized = normalize_catalog_text(value)
    return SPELLING_CORRECTIONS.get(normalized, normalized)


def search_variants(value: str) -> list[str]:
    original = " ".join((value or "").lower().split())
    normalized = normalize_search_query(value)
    variants = [normalized]
    if original and original != normalized:
        variants.append(original)

    if normalized.endswith("ies") and len(normalized) > 4:
        variants.append(f"{normalized[:-3]}y")
    elif normalized.endswith("es") and len(normalized) > 3:
        variants.append(normalized[:-2])
    elif normalized.endswith("s") and len(normalized) > 2:
        variants.append(normalized[:-1])
    else:
        variants.extend((f"{normalized}s", f"{normalized}es"))

    normalized_tokens = set(normalized.split())
    for group in SEARCH_EQUIVALENT_GROUPS:
        if normalized in group or normalized_tokens.intersection(group):
            variants.extend(group)

    return list(dict.fromkeys(variant for variant in variants if variant))[:10]
