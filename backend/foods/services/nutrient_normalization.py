from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, InvalidOperation

USDA_NUTRIENT_CODE_BY_ID = {
    "1008": "calories",
    "2047": "calories",
    "2048": "calories",
    "1062": "energy_kj",
    "1003": "protein_g",
    "1005": "carbs_g",
    "1050": "carbs_g",
    "2039": "carbs_g",
    "1004": "fat_g",
    "1079": "fiber_g",
    "2000": "sugar_g",
    "1063": "sugar_g",
    "1235": "added_sugar_g",
    "1093": "sodium_mg",
    "1092": "potassium_mg",
    "1087": "calcium_mg",
    "1089": "iron_mg",
    "1106": "vitamin_a_mcg",
    "1162": "vitamin_c_mg",
    "1114": "vitamin_d_mcg",
    "1177": "folate_mcg",
    "1186": "folic_acid_mcg",
    "1253": "cholesterol_mg",
    "1258": "saturated_fat_g",
    "1257": "trans_fat_g",
}

USDA_NUTRIENT_CODE_BY_NAME = {
    "energy": "calories",
    "energy kcal": "calories",
    "energy kj": "energy_kj",
    "protein": "protein_g",
    "carbohydrate": "carbs_g",
    "carbohydrate, by difference": "carbs_g",
    "total carbohydrate": "carbs_g",
    "net carbohydrate": "net_carbs_g",
    "fat": "fat_g",
    "total lipid (fat)": "fat_g",
    "fiber": "fiber_g",
    "fiber, total dietary": "fiber_g",
    "sugars": "sugar_g",
    "sugars, total": "sugar_g",
    "sugars, total including nlea": "sugar_g",
    "sugars, added": "added_sugar_g",
    "sodium": "sodium_mg",
    "potassium": "potassium_mg",
    "calcium": "calcium_mg",
    "iron": "iron_mg",
    "vitamin a": "vitamin_a_mcg",
    "vitamin c": "vitamin_c_mg",
    "vitamin d": "vitamin_d_mcg",
    "folate, total": "folate_mcg",
    "folic acid": "folic_acid_mcg",
    "cholesterol": "cholesterol_mg",
    "fatty acids, total saturated": "saturated_fat_g",
    "fatty acids, total trans": "trans_fat_g",
}

OPENFOODFACTS_NUTRIENT_CODE_BY_KEY = {
    "energy-kcal_100g": "calories",
    "energy-kj_100g": "energy_kj",
    "proteins_100g": "protein_g",
    "carbohydrates_100g": "carbs_g",
    "net-carbohydrates_100g": "net_carbs_g",
    "fat_100g": "fat_g",
    "fiber_100g": "fiber_g",
    "sugars_100g": "sugar_g",
    "added-sugars_100g": "added_sugar_g",
    "sodium_100g": "sodium_mg",
    "salt_100g": "sodium_mg",
    "potassium_100g": "potassium_mg",
    "calcium_100g": "calcium_mg",
    "iron_100g": "iron_mg",
    "vitamin-a_100g": "vitamin_a_mcg",
    "vitamin-c_100g": "vitamin_c_mg",
    "vitamin-d_100g": "vitamin_d_mcg",
    "folates_100g": "folate_mcg",
    "cholesterol_100g": "cholesterol_mg",
    "saturated-fat_100g": "saturated_fat_g",
    "trans-fat_100g": "trans_fat_g",
}

CANONICAL_UNITS = {
    "calories": "kcal",
    "energy_kj": "kj",
    "protein_g": "g",
    "carbs_g": "g",
    "net_carbs_g": "g",
    "fat_g": "g",
    "fiber_g": "g",
    "sugar_g": "g",
    "added_sugar_g": "g",
    "sodium_mg": "mg",
    "potassium_mg": "mg",
    "calcium_mg": "mg",
    "iron_mg": "mg",
    "vitamin_a_mcg": "mcg",
    "vitamin_c_mg": "mg",
    "vitamin_d_mcg": "mcg",
    "folate_mcg": "mcg",
    "folic_acid_mcg": "mcg",
    "cholesterol_mg": "mg",
    "saturated_fat_g": "g",
    "trans_fat_g": "g",
}

UNIT_ALIASES = {
    "kcal": "kcal",
    "cal": "kcal",
    "kj": "kj",
    "g": "g",
    "gram": "g",
    "grams": "g",
    "mg": "mg",
    "milligram": "mg",
    "milligrams": "mg",
    "ug": "mcg",
    "µg": "mcg",
    "mcg": "mcg",
}


@dataclass(frozen=True, slots=True)
class NormalizedNutrient:
    code: str
    amount: Decimal
    original_amount: Decimal
    original_unit: str
    source_nutrient_id: str = ""
    normalization_notes: str = ""


def _decimal(value) -> Decimal | None:
    try:
        return Decimal(str(value).strip())
    except (InvalidOperation, TypeError, ValueError):
        return None


def _convert_unit(
    amount: Decimal,
    source_unit: str,
    target_unit: str,
) -> tuple[Decimal, str] | None:
    source = UNIT_ALIASES.get((source_unit or "").strip().casefold())
    target = UNIT_ALIASES.get((target_unit or "").strip().casefold(), target_unit)
    if source == target:
        return amount, ""
    factors = {
        ("g", "mg"): Decimal("1000"),
        ("g", "mcg"): Decimal("1000000"),
        ("mg", "g"): Decimal("0.001"),
        ("mg", "mcg"): Decimal("1000"),
        ("mcg", "mg"): Decimal("0.001"),
        ("mcg", "g"): Decimal("0.000001"),
    }
    factor = factors.get((source, target))
    if factor is None:
        return None
    return amount * factor, f"Converted {source} to {target}."


def normalize_usda_nutrient(
    *,
    nutrient_id: str,
    name: str,
    unit: str,
    amount,
) -> NormalizedNutrient | None:
    original = _decimal(amount)
    if original is None:
        return None
    normalized_name = " ".join((name or "").strip().casefold().split())
    code = USDA_NUTRIENT_CODE_BY_ID.get(str(nutrient_id).strip())
    if not code:
        code = USDA_NUTRIENT_CODE_BY_NAME.get(normalized_name)
    if not code:
        return None

    # "Energy" is ambiguous by name; the source unit resolves kcal versus kJ.
    normalized_unit = UNIT_ALIASES.get((unit or "").strip().casefold())
    if normalized_name == "energy":
        code = "energy_kj" if normalized_unit == "kj" else "calories"
    target_unit = CANONICAL_UNITS[code]
    converted = _convert_unit(original, unit, target_unit)
    if converted is None:
        # Vitamin A IU depends on the underlying chemical form and must not be
        # silently treated as a mass value.
        return None
    value, notes = converted
    return NormalizedNutrient(
        code=code,
        amount=value,
        original_amount=original,
        original_unit=unit or "",
        source_nutrient_id=str(nutrient_id or ""),
        normalization_notes=notes,
    )


def normalize_openfoodfacts_nutrient(
    *,
    key: str,
    amount,
) -> NormalizedNutrient | None:
    original = _decimal(amount)
    code = OPENFOODFACTS_NUTRIENT_CODE_BY_KEY.get(key)
    if original is None or not code:
        return None

    source_unit = "kcal" if "kcal" in key else "kj" if "kj" in key else "g"
    notes = ""
    if key == "salt_100g":
        # EU labels define salt as sodium x 2.5. Preserve the label value while
        # normalizing salt grams to sodium milligrams.
        value = original * Decimal("400")
        notes = "Converted salt g to sodium mg using salt = sodium × 2.5."
    else:
        converted = _convert_unit(original, source_unit, CANONICAL_UNITS[code])
        if converted is None:
            return None
        value, notes = converted
    return NormalizedNutrient(
        code=code,
        amount=value,
        original_amount=original,
        original_unit=source_unit,
        source_nutrient_id=key,
        normalization_notes=notes,
    )
