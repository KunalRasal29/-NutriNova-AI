from __future__ import annotations

import re

from foods.models import Food

RAW_TERMS = {"raw", "uncooked"}
SPECIFIC_PREPARATION_TERMS = {
    "baked": Food.PreparationState.BAKED,
    "boiled": Food.PreparationState.BOILED,
    "fried": Food.PreparationState.FRIED,
    "grilled": Food.PreparationState.GRILLED,
    "roasted": Food.PreparationState.ROASTED,
    "steamed": Food.PreparationState.STEAMED,
}
COOKED_TERMS = {"cooked", "sauteed", "sauted"}
PREPARED_DISH_TERMS = {
    "biryani",
    "chapati",
    "curry",
    "dal",
    "dosa",
    "idli",
    "khichdi",
    "poha",
    "roti",
    "sabzi",
    "upma",
}


def infer_preparation_state(
    name: str,
    *,
    food_type: str = Food.FoodType.GENERIC,
) -> str:
    """Conservatively infer preparation only when the name makes it explicit."""
    if food_type == Food.FoodType.BRANDED:
        return Food.PreparationState.AS_SOLD

    words = set(re.findall(r"[a-z]+", (name or "").lower()))
    if words & RAW_TERMS:
        return Food.PreparationState.RAW
    for term, state in SPECIFIC_PREPARATION_TERMS.items():
        if term in words:
            return state
    if words & COOKED_TERMS:
        return Food.PreparationState.COOKED
    if words & PREPARED_DISH_TERMS:
        return Food.PreparationState.PREPARED
    return Food.PreparationState.UNSPECIFIED
