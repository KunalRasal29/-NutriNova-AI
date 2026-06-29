class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.hasCompletedOnboarding = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['display_name']?.toString() ??
          json['username']?.toString() ??
          'You',
      hasCompletedOnboarding: json['has_completed_onboarding'] == true,
    );
  }

  final String id;
  final String email;
  final String displayName;
  final bool hasCompletedOnboarding;
}

class AuthTokens {
  const AuthTokens({required this.access, required this.refresh});

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      access: json['access']?.toString() ?? '',
      refresh: json['refresh']?.toString() ?? '',
    );
  }

  final String access;
  final String refresh;
}

class MacroPreview {
  const MacroPreview({
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory MacroPreview.fromJson(Map<String, dynamic> json) {
    return MacroPreview(
      caloriesKcal: _asDouble(json['calories_kcal']),
      proteinG: _asDouble(json['protein_g']),
      carbsG: _asDouble(json['carbs_g']),
      fatG: _asDouble(json['fat_g']),
    );
  }

  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
}

class FoodSummary {
  const FoodSummary({
    required this.id,
    required this.name,
    required this.brand,
    required this.sourceBadge,
    required this.confidenceScore,
    required this.dataClassification,
    required this.verified,
    required this.preview,
  });

  factory FoodSummary.fromJson(Map<String, dynamic> json) {
    final nutrition = json['nutrition_per_100g'] as Map<String, dynamic>? ?? {};
    return FoodSummary(
      id: json['id']?.toString() ?? '',
      name:
          json['name']?.toString() ?? json['canonical_name']?.toString() ?? '',
      brand: json['brand']?.toString() ?? json['brand_name']?.toString() ?? '',
      sourceBadge: json['source_badge']?.toString() ??
          json['source_type']?.toString() ??
          '',
      confidenceScore: _asDouble(json['confidence_score']),
      dataClassification:
          json['data_classification']?.toString() ?? 'official_unverified',
      verified: json['verified'] == true,
      preview: MacroPreview(
        caloriesKcal: _asDouble(nutrition['calories']),
        proteinG: _asDouble(nutrition['protein_g']),
        carbsG: _asDouble(nutrition['carbs_g']),
        fatG: _asDouble(nutrition['fat_g']),
      ),
    );
  }

  final String id;
  final String name;
  final String brand;
  final String sourceBadge;
  final double confidenceScore;
  final String dataClassification;
  final bool verified;
  final MacroPreview preview;
}

class FoodServingOption {
  const FoodServingOption({
    required this.id,
    required this.name,
    required this.grams,
    required this.isDefault,
    this.householdQuantity = '',
  });

  factory FoodServingOption.fromJson(Map<String, dynamic> json) {
    return FoodServingOption(
      id: json['id']?.toString() ?? '',
      name: json['serving_name']?.toString() ??
          json['description']?.toString() ??
          'Serving',
      grams: _asDouble(json['grams']),
      householdQuantity: json['household_quantity']?.toString() ?? '',
      isDefault: json['is_default'] == true,
    );
  }

  final String id;
  final String name;
  final double grams;
  final bool isDefault;
  final String householdQuantity;
}

class FoodNutrientValue {
  const FoodNutrientValue({
    required this.code,
    required this.name,
    required this.unit,
    required this.amountPer100g,
  });

  factory FoodNutrientValue.fromJson(Map<String, dynamic> json) {
    return FoodNutrientValue(
      code: json['nutrient_code']?.toString() ?? '',
      name: json['nutrient_name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      amountPer100g: _asDouble(json['amount_per_100g']),
    );
  }

  final String code;
  final String name;
  final String unit;
  final double amountPer100g;
}

class FoodDetail {
  const FoodDetail({
    required this.id,
    required this.name,
    required this.brand,
    required this.description,
    required this.sourceBadge,
    required this.confidenceScore,
    required this.dataClassification,
    required this.verified,
    required this.defaultServingG,
    required this.servings,
    required this.nutrients,
    required this.isFavorite,
  });

  factory FoodDetail.fromJson(Map<String, dynamic> json) {
    final servings = json['servings'] as List<dynamic>? ?? const [];
    final nutrients = json['nutrients'] as List<dynamic>? ?? const [];
    return FoodDetail(
      id: json['id']?.toString() ?? '',
      name:
          json['canonical_name']?.toString() ?? json['name']?.toString() ?? '',
      brand: json['brand_name']?.toString() ?? json['brand']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      sourceBadge: json['source_badge']?.toString() ??
          (json['source'] as Map<String, dynamic>?)?['source_type']
              ?.toString() ??
          '',
      confidenceScore: _asDouble(json['confidence_score']),
      dataClassification:
          json['data_classification']?.toString() ?? 'official_unverified',
      verified: json['verified'] == true,
      defaultServingG: _asDouble(json['default_serving_g'], fallback: 100),
      servings: servings
          .map(
            (serving) =>
                FoodServingOption.fromJson(serving as Map<String, dynamic>),
          )
          .toList(),
      nutrients: nutrients
          .map(
            (nutrient) =>
                FoodNutrientValue.fromJson(nutrient as Map<String, dynamic>),
          )
          .toList(),
      isFavorite: json['is_favorite'] == true,
    );
  }

  final String id;
  final String name;
  final String brand;
  final String description;
  final String sourceBadge;
  final double confidenceScore;
  final String dataClassification;
  final bool verified;
  final double defaultServingG;
  final List<FoodServingOption> servings;
  final List<FoodNutrientValue> nutrients;
  final bool isFavorite;

  MacroPreview get per100gPreview => MacroPreview(
        caloriesKcal: nutrientAmount('calories'),
        proteinG: nutrientAmount('protein_g'),
        carbsG: nutrientAmount('carbs_g'),
        fatG: nutrientAmount('fat_g'),
      );

  double nutrientAmount(String code) {
    for (final nutrient in nutrients) {
      if (nutrient.code == code) return nutrient.amountPer100g;
    }
    return 0;
  }

  double effectiveGrams({
    required double quantity,
    required String unit,
    double? totalGrams,
  }) {
    if (totalGrams != null && totalGrams > 0) return totalGrams;
    if (unit == 'gram') return quantity;
    FoodServingOption? matchedServing;
    FoodServingOption? defaultServing;
    for (final serving in servings) {
      final text = '${serving.name} ${serving.householdQuantity}'.toLowerCase();
      if (matchedServing == null && text.contains(unit.toLowerCase())) {
        matchedServing = serving;
      }
      if (defaultServing == null && serving.isDefault) {
        defaultServing = serving;
      }
    }
    final grams = matchedServing?.grams ??
        (unit == 'serving' ? defaultServing?.grams : null) ??
        defaultServing?.grams ??
        defaultServingG;
    return quantity * (grams <= 0 ? 100 : grams);
  }

  MacroPreview previewFor({
    required double quantity,
    required String unit,
    double? totalGrams,
  }) {
    final scale = effectiveGrams(
          quantity: quantity,
          unit: unit,
          totalGrams: totalGrams,
        ) /
        100;
    final per100g = per100gPreview;
    return MacroPreview(
      caloriesKcal: per100g.caloriesKcal * scale,
      proteinG: per100g.proteinG * scale,
      carbsG: per100g.carbsG * scale,
      fatG: per100g.fatG * scale,
    );
  }
}

class MealLogSummary {
  const MealLogSummary({
    required this.id,
    required this.date,
    required this.mealType,
    required this.name,
    required this.items,
  });

  factory MealLogSummary.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? const [];
    final mealType = json['meal_type']?.toString() ?? '';
    return MealLogSummary(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      mealType: mealType,
      name: json['name']?.toString() ?? '',
      items: items
          .map(
            (item) => MealItemSummary.fromJson(
              item as Map<String, dynamic>,
              mealType: mealType,
            ),
          )
          .toList(),
    );
  }

  final String id;
  final String date;
  final String mealType;
  final String name;
  final List<MealItemSummary> items;

  double get totalCalories => items.fold<double>(
        0,
        (total, item) => total + item.caloriesKcal,
      );
}

class MealItemSummary {
  const MealItemSummary({
    required this.foodName,
    required this.mealType,
    required this.caloriesKcal,
    this.brandName = '',
    this.source = '',
    this.confidence = 0,
    this.verified = false,
    this.classification = 'official_unverified',
    this.quantity = 0,
    this.unit = '',
    this.grams = 0,
  });

  factory MealItemSummary.fromJson(
    Map<String, dynamic> json, {
    required String mealType,
  }) {
    final source = json['food_source'] as Map<String, dynamic>? ?? {};
    return MealItemSummary(
      foodName: json['food_name']?.toString() ?? 'Food',
      brandName: json['brand_name']?.toString() ?? '',
      mealType: mealType,
      caloriesKcal: _asDouble(json['calories_kcal']),
      source: source['source_type']?.toString() ?? '',
      confidence: _asDouble(
        source['confidence_score'] ?? json['source_confidence'],
      ),
      verified: json['food_verified'] == true,
      classification:
          json['food_data_classification']?.toString() ?? 'official_unverified',
      quantity: _asDouble(json['quantity']),
      unit: json['unit']?.toString() ?? '',
      grams: _asDouble(json['grams_calculated']),
    );
  }

  final String foodName;
  final String brandName;
  final String mealType;
  final double caloriesKcal;
  final String source;
  final double confidence;
  final bool verified;
  final String classification;
  final double quantity;
  final String unit;
  final double grams;
}

class HabitGridItem {
  const HabitGridItem({
    required this.habitId,
    required this.title,
    required this.unit,
    required this.targetCount,
    required this.completedCount,
    required this.isCompleted,
    required this.currentStreak,
    required this.color,
    required this.icon,
  });

  factory HabitGridItem.fromJson(Map<String, dynamic> json) {
    return HabitGridItem(
      habitId: json['habit_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'checkbox',
      targetCount: _asInt(json['target_count'], fallback: 1),
      completedCount: _asInt(json['completed_count']),
      isCompleted: json['is_completed'] == true,
      currentStreak: _asInt(json['current_streak']),
      color: json['color']?.toString() ?? '#22C55E',
      icon: json['icon']?.toString() ?? 'check',
    );
  }

  final String habitId;
  final String title;
  final String unit;
  final int targetCount;
  final int completedCount;
  final bool isCompleted;
  final int currentStreak;
  final String color;
  final String icon;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.consumedCalories,
    required this.targetCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.waterCompleted,
    required this.waterTarget,
    required this.meals,
    required this.habits,
    required this.weightTrend,
    required this.latestWeightKg,
    required this.weightChangeKg,
    required this.insight,
  });

  final double consumedCalories;
  final double targetCalories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final int waterCompleted;
  final int waterTarget;
  final List<MealItemSummary> meals;
  final List<HabitGridItem> habits;
  final List<double> weightTrend;
  final double? latestWeightKg;
  final double? weightChangeKg;
  final String insight;
}

class BodyMetricTrend {
  const BodyMetricTrend({
    required this.weights,
    this.latestWeightKg,
    this.changeKg,
  });

  factory BodyMetricTrend.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? const [];
    final weights = <double>[];
    for (final item in items) {
      final row = item as Map<String, dynamic>;
      final weight = _asDouble(row['weight_kg'], fallback: -1);
      if (weight > 0) weights.add(weight);
    }
    final latest = json['latest'] as Map<String, dynamic>?;
    return BodyMetricTrend(
      weights: weights,
      latestWeightKg:
          latest == null ? null : _nullableDouble(latest['weight_kg']),
      changeKg: _nullableDouble(json['change_kg']),
    );
  }

  final List<double> weights;
  final double? latestWeightKg;
  final double? changeKg;
}

class PhotoReview {
  const PhotoReview({
    required this.analysisId,
    required this.status,
    required this.imageUrl,
    required this.disclaimer,
    required this.items,
    required this.totalPreview,
    required this.warnings,
  });

  factory PhotoReview.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? const [];
    final warnings = json['warnings'] as List<dynamic>? ?? const [];
    return PhotoReview(
      analysisId:
          json['analysis_id']?.toString() ?? json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'needs_review',
      imageUrl: json['image_url']?.toString() ?? '',
      disclaimer: json['disclaimer']?.toString() ??
          'Photo nutrition is an estimate. Confirm food and portion size for better accuracy.',
      items: items
          .map((item) => PhotoReviewItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalPreview: MacroPreview.fromJson(
        json['total_preview'] as Map<String, dynamic>? ?? const {},
      ),
      warnings: warnings.map((warning) => warning.toString()).toList(),
    );
  }

  final String analysisId;
  final String status;
  final String imageUrl;
  final String disclaimer;
  final List<PhotoReviewItem> items;
  final MacroPreview totalPreview;
  final List<String> warnings;
}

class PhotoReviewItem {
  const PhotoReviewItem({
    required this.id,
    required this.name,
    required this.matchedFoodId,
    required this.quantity,
    required this.unit,
    required this.grams,
    required this.preview,
    required this.confidence,
    required this.isRemoved,
    this.sourceBadges = const [],
    this.warnings = const [],
    this.alternatives = const [],
    this.addedManually = false,
  });

  factory PhotoReviewItem.fromJson(Map<String, dynamic> json) {
    final warnings = json['warnings'] as List<dynamic>? ?? const [];
    final sourceBadges = json['source_badges'] as List<dynamic>? ?? const [];
    final alternatives =
        json['alternative_matches'] as List<dynamic>? ?? const [];
    return PhotoReviewItem(
      id: json['id']?.toString() ?? '',
      name: _firstNonEmpty([
        json['matched_food_name'],
        json['detected_name'],
      ]),
      matchedFoodId: json['matched_food']?.toString() ?? '',
      quantity: _asDouble(
        json['effective_quantity_value'] ?? json['quantity_value'],
        fallback: 1,
      ),
      unit: json['effective_quantity_unit']?.toString() ??
          json['quantity_unit']?.toString() ??
          'serving',
      grams: _asDouble(json['effective_total_grams']),
      preview: MacroPreview.fromJson(json),
      confidence: _asDouble(json['confidence_score']),
      isRemoved: json['is_removed'] == true,
      sourceBadges: sourceBadges.map((source) => source.toString()).toList(),
      warnings: warnings.map((warning) => warning.toString()).toList(),
      alternatives: alternatives
          .map((item) => FoodSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      addedManually: json['added_manually'] == true,
    );
  }

  final String id;
  final String name;
  final String matchedFoodId;
  final double quantity;
  final String unit;
  final double grams;
  final MacroPreview preview;
  final double confidence;
  final bool isRemoved;
  final List<String> sourceBadges;
  final List<String> warnings;
  final List<FoodSummary> alternatives;
  final bool addedManually;
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double? _nullableDouble(Object? value) {
  if (value == null || value == '') return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    final text = value?.toString() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}
