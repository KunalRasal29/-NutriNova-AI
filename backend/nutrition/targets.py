from __future__ import annotations

from datetime import date
from decimal import ROUND_HALF_UP, Decimal

from django.utils import timezone

from profiles.models import UserProfile

TARGET_FIELD_MAP = {
    "calories_kcal": "daily_calorie_target_kcal",
    "protein_g": "daily_protein_target_g",
    "carbs_g": "daily_carbs_target_g",
    "fat_g": "daily_fat_target_g",
    "fiber_g": "daily_fiber_target_g",
    "water_ml": "daily_water_target_ml",
}

FALLBACK_TARGETS = {
    "calories_kcal": Decimal("2000"),
    "protein_g": Decimal("75"),
    "carbs_g": Decimal("250"),
    "fat_g": Decimal("70"),
    "fiber_g": Decimal("30"),
    "water_ml": Decimal("2500"),
}

ACTIVITY_FACTORS = {
    UserProfile.ActivityLevel.SEDENTARY: Decimal("1.20"),
    UserProfile.ActivityLevel.LIGHT: Decimal("1.375"),
    UserProfile.ActivityLevel.MODERATE: Decimal("1.55"),
    UserProfile.ActivityLevel.ACTIVE: Decimal("1.725"),
    UserProfile.ActivityLevel.ATHLETE: Decimal("1.90"),
}


def age_on(date_of_birth: date | None, today: date | None = None) -> int | None:
    if not date_of_birth:
        return None
    today = today or timezone.localdate()
    return (
        today.year
        - date_of_birth.year
        - ((today.month, today.day) < (date_of_birth.month, date_of_birth.day))
    )


def _round_to(value: Decimal, increment: Decimal) -> Decimal:
    return (value / increment).quantize(
        Decimal("1"), rounding=ROUND_HALF_UP
    ) * increment


def _clamp(value: Decimal, minimum: Decimal, maximum: Decimal) -> Decimal:
    return max(minimum, min(value, maximum))


def estimate_targets(profile: UserProfile) -> dict:
    if profile.weight_kg is None or profile.height_cm is None:
        return {
            "targets": FALLBACK_TARGETS.copy(),
            "method": "generic_fallback",
            "assumptions": [
                "Add height and weight for a personalised starting estimate."
            ],
            "inputs_used": {
                "height_cm": profile.height_cm,
                "weight_kg": profile.weight_kg,
                "age": age_on(profile.date_of_birth),
                "activity_level": profile.activity_level,
                "goal_type": profile.goal_type,
            },
        }

    weight = Decimal(profile.weight_kg)
    height = Decimal(profile.height_cm)
    age = age_on(profile.date_of_birth)
    calculation_age = Decimal(age if age is not None else 30)
    sex_value = profile.biological_sex or profile.gender_optional
    if sex_value == UserProfile.BiologicalSex.MALE:
        sex_adjustment = Decimal("5")
    elif sex_value == UserProfile.BiologicalSex.FEMALE:
        sex_adjustment = Decimal("-161")
    else:
        sex_adjustment = Decimal("-78")

    bmr = (
        Decimal("10") * weight
        + Decimal("6.25") * height
        - Decimal("5") * calculation_age
        + sex_adjustment
    )
    activity_factor = ACTIVITY_FACTORS.get(
        profile.activity_level,
        ACTIVITY_FACTORS[UserProfile.ActivityLevel.MODERATE],
    )
    calories = bmr * activity_factor
    target_weight = (
        Decimal(profile.target_weight_kg)
        if profile.target_weight_kg is not None
        else None
    )
    if profile.goal_type == UserProfile.GoalType.LOSE_WEIGHT:
        deficit = Decimal("350")
        if target_weight is not None and target_weight < weight:
            deficit = _clamp(
                (weight - target_weight) * Decimal("30"),
                Decimal("250"),
                Decimal("500"),
            )
        calories -= deficit
    elif profile.goal_type == UserProfile.GoalType.GAIN_MUSCLE:
        surplus = Decimal("250")
        if target_weight is not None and target_weight > weight:
            surplus = _clamp(
                (target_weight - weight) * Decimal("20"),
                Decimal("150"),
                Decimal("350"),
            )
        calories += surplus
    calories = _round_to(
        _clamp(calories, Decimal("1200"), Decimal("4500")),
        Decimal("10"),
    )

    protein_multiplier = Decimal("1.2")
    if profile.goal_type in {
        UserProfile.GoalType.LOSE_WEIGHT,
        UserProfile.GoalType.GAIN_MUSCLE,
    }:
        protein_multiplier = Decimal("1.6")
    if profile.dietary_preference == UserProfile.DietaryPreference.HIGH_PROTEIN:
        protein_multiplier = max(protein_multiplier, Decimal("1.8"))
    protein = _round_to(
        _clamp(weight * protein_multiplier, Decimal("50"), Decimal("250")),
        Decimal("1"),
    )

    fat_share = (
        Decimal("0.40")
        if profile.dietary_preference == UserProfile.DietaryPreference.KETO
        else Decimal("0.30")
    )
    fat = _round_to(
        _clamp(calories * fat_share / Decimal("9"), Decimal("40"), Decimal("180")),
        Decimal("1"),
    )
    carbs = _round_to(
        _clamp(
            (calories - (protein * 4) - (fat * 9)) / Decimal("4"),
            Decimal("50"),
            Decimal("600"),
        ),
        Decimal("1"),
    )
    fiber = _round_to(
        _clamp(calories / Decimal("1000") * 14, Decimal("25"), Decimal("50")),
        Decimal("1"),
    )
    water = weight * Decimal("35")
    if profile.activity_level == UserProfile.ActivityLevel.ACTIVE:
        water += Decimal("500")
    elif profile.activity_level == UserProfile.ActivityLevel.ATHLETE:
        water += Decimal("750")
    water = _round_to(
        _clamp(water, Decimal("1500"), Decimal("5000")),
        Decimal("50"),
    )

    assumptions = [
        "Targets are wellness estimates and can be edited.",
        "Activity and goal selections influence the calorie estimate.",
    ]
    if age is None:
        assumptions.append("Age 30 was used because date of birth is missing.")
    if sex_value not in {
        UserProfile.BiologicalSex.MALE,
        UserProfile.BiologicalSex.FEMALE,
    }:
        assumptions.append(
            "A neutral BMR adjustment was used because biological sex is unspecified."
        )

    return {
        "targets": {
            "calories_kcal": calories,
            "protein_g": protein,
            "carbs_g": carbs,
            "fat_g": fat,
            "fiber_g": fiber,
            "water_ml": water,
        },
        "method": "mifflin_st_jeor_wellness_estimate",
        "assumptions": assumptions,
        "inputs_used": {
            "height_cm": height,
            "weight_kg": weight,
            "age": age,
            "activity_level": profile.activity_level,
            "goal_type": profile.goal_type,
            "dietary_preference": profile.dietary_preference,
            "target_weight_kg": target_weight,
        },
    }


def profile_has_saved_targets(profile: UserProfile) -> bool:
    return all(
        getattr(profile, field) is not None for field in TARGET_FIELD_MAP.values()
    )


def targets_from_profile(profile: UserProfile) -> dict[str, Decimal]:
    if not profile_has_saved_targets(profile):
        return estimate_targets(profile)["targets"]
    return {
        code: Decimal(getattr(profile, field))
        for code, field in TARGET_FIELD_MAP.items()
    }


def save_targets(
    profile: UserProfile,
    targets: dict[str, Decimal],
    *,
    method: str,
    customized: bool,
) -> None:
    update_fields = []
    for code, field in TARGET_FIELD_MAP.items():
        setattr(profile, field, targets[code])
        update_fields.append(field)
    profile.nutrition_target_method = method
    profile.nutrition_targets_customized = customized
    profile.nutrition_targets_calculated_at = timezone.now()
    update_fields.extend(
        (
            "nutrition_target_method",
            "nutrition_targets_customized",
            "nutrition_targets_calculated_at",
            "updated_at",
        )
    )
    profile.save(update_fields=update_fields)


def save_initial_estimate(profile: UserProfile) -> None:
    if profile_has_saved_targets(profile):
        return
    estimate = estimate_targets(profile)
    save_targets(
        profile,
        estimate["targets"],
        method=estimate["method"],
        customized=False,
    )


def target_plan_payload(profile: UserProfile) -> dict:
    has_saved_targets = profile_has_saved_targets(profile)
    estimate = estimate_targets(profile)
    targets = targets_from_profile(profile)
    return {
        "targets": {code: str(value) for code, value in targets.items()},
        "has_saved_targets": has_saved_targets,
        "customized": profile.nutrition_targets_customized,
        "method": (
            profile.nutrition_target_method if has_saved_targets else estimate["method"]
        ),
        "calculated_at": profile.nutrition_targets_calculated_at,
        "assumptions": estimate["assumptions"],
        "inputs_used": estimate["inputs_used"],
        "disclaimer": (
            "These are editable wellness estimates, not medical or dietary "
            "treatment advice."
        ),
    }
