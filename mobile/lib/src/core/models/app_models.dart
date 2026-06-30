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
    this.fiberG = 0,
    this.sugarG = 0,
    this.sodiumMg = 0,
    this.calciumMg = 0,
    this.ironMg = 0,
    this.potassiumMg = 0,
    this.cholesterolMg = 0,
    this.saturatedFatG = 0,
  });

  factory MacroPreview.fromJson(Map<String, dynamic> json) {
    return MacroPreview(
      caloriesKcal: _asDouble(json['calories_kcal'] ?? json['calories']),
      proteinG: _asDouble(json['protein_g']),
      carbsG: _asDouble(json['carbs_g']),
      fatG: _asDouble(json['fat_g']),
      fiberG: _asDouble(json['fiber_g']),
      sugarG: _asDouble(json['sugar_g']),
      sodiumMg: _asDouble(json['sodium_mg']),
      calciumMg: _asDouble(json['calcium_mg']),
      ironMg: _asDouble(json['iron_mg']),
      potassiumMg: _asDouble(json['potassium_mg']),
      cholesterolMg: _asDouble(json['cholesterol_mg']),
      saturatedFatG: _asDouble(json['saturated_fat_g']),
    );
  }

  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sugarG;
  final double sodiumMg;
  final double calciumMg;
  final double ironMg;
  final double potassiumMg;
  final double cholesterolMg;
  final double saturatedFatG;
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
    this.isFavorite = false,
    this.defaultServingDescription = '',
    this.defaultServingGrams = 0,
  });

  factory FoodSummary.fromJson(Map<String, dynamic> json) {
    final nutrition = json['nutrition_per_100g'] as Map<String, dynamic>? ?? {};
    final serving = json['default_serving'] as Map<String, dynamic>? ?? {};
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
      isFavorite: json['is_favorite'] == true,
      defaultServingDescription: serving['description']?.toString() ?? '',
      defaultServingGrams: _asDouble(serving['grams']),
      preview: MacroPreview(
        caloriesKcal: _asDouble(nutrition['calories']),
        proteinG: _asDouble(nutrition['protein_g']),
        carbsG: _asDouble(nutrition['carbs_g']),
        fatG: _asDouble(nutrition['fat_g']),
        fiberG: _asDouble(nutrition['fiber_g']),
        sugarG: _asDouble(nutrition['sugar_g']),
        sodiumMg: _asDouble(nutrition['sodium_mg']),
        calciumMg: _asDouble(nutrition['calcium_mg']),
        ironMg: _asDouble(nutrition['iron_mg']),
        potassiumMg: _asDouble(nutrition['potassium_mg']),
        cholesterolMg: _asDouble(nutrition['cholesterol_mg']),
        saturatedFatG: _asDouble(nutrition['saturated_fat_g']),
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
  final bool isFavorite;
  final MacroPreview preview;
  final String defaultServingDescription;
  final double defaultServingGrams;

  String get servingSummary {
    final serving = defaultServingDescription.trim();
    final grams = defaultServingGrams;
    if (serving.isNotEmpty && grams > 0) {
      return '$serving (${grams.toStringAsFixed(grams % 1 == 0 ? 0 : 1)}g)';
    }
    if (serving.isNotEmpty) return serving;
    if (grams > 0) {
      return '${grams.toStringAsFixed(grams % 1 == 0 ? 0 : 1)}g serving';
    }
    return '100g reference';
  }
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
        fiberG: nutrientAmount('fiber_g'),
        sugarG: nutrientAmount('sugar_g'),
        sodiumMg: nutrientAmount('sodium_mg'),
        calciumMg: nutrientAmount('calcium_mg'),
        ironMg: nutrientAmount('iron_mg'),
        potassiumMg: nutrientAmount('potassium_mg'),
        cholesterolMg: nutrientAmount('cholesterol_mg'),
        saturatedFatG: nutrientAmount('saturated_fat_g'),
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
      fiberG: per100g.fiberG * scale,
      sugarG: per100g.sugarG * scale,
      sodiumMg: per100g.sodiumMg * scale,
      calciumMg: per100g.calciumMg * scale,
      ironMg: per100g.ironMg * scale,
      potassiumMg: per100g.potassiumMg * scale,
      cholesterolMg: per100g.cholesterolMg * scale,
      saturatedFatG: per100g.saturatedFatG * scale,
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
    required this.id,
    required this.foodName,
    required this.mealType,
    required this.caloriesKcal,
    required this.foodId,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.fiberG = 0,
    this.sugarG = 0,
    this.sodiumMg = 0,
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
    final macros = json['macros_snapshot'] as Map<String, dynamic>? ?? {};
    final nutrients = json['nutrients_snapshot'] as Map<String, dynamic>? ?? {};
    return MealItemSummary(
      id: json['id']?.toString() ?? '',
      foodName: json['food_name']?.toString() ?? 'Food',
      foodId: json['food']?.toString() ?? '',
      brandName: json['brand_name']?.toString() ?? '',
      mealType: mealType,
      caloriesKcal: _asDouble(
        json['calories_kcal'] ??
            macros['calories_kcal'] ??
            nutrients['calories'],
      ),
      proteinG: _asDouble(json['protein_g'] ?? macros['protein_g']),
      carbsG: _asDouble(json['carbs_g'] ?? macros['carbs_g']),
      fatG: _asDouble(json['fat_g'] ?? macros['fat_g']),
      fiberG: _asDouble(json['fiber_g'] ?? nutrients['fiber_g']),
      sugarG: _asDouble(json['sugar_g'] ?? nutrients['sugar_g']),
      sodiumMg: _asDouble(json['sodium_mg'] ?? nutrients['sodium_mg']),
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

  final String id;
  final String foodName;
  final String foodId;
  final String brandName;
  final String mealType;
  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sugarG;
  final double sodiumMg;
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
    this.fiberG = 0,
    this.sugarG = 0,
    this.sodiumMg = 0,
    this.micronutrients = const {},
  });

  final double consumedCalories;
  final double targetCalories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sugarG;
  final double sodiumMg;
  final Map<String, double> micronutrients;
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

  bool get isProcessing => status == 'uploaded' || status == 'processing';
  bool get isFailed => status == 'failed';
  bool get isConfirmed => status == 'confirmed';
  List<PhotoReviewItem> get activeItems =>
      items.where((item) => !item.isRemoved).toList();
  List<PhotoReviewItem> get removedItems =>
      items.where((item) => item.isRemoved).toList();
  bool get hasConfirmableItems =>
      activeItems.isNotEmpty &&
      activeItems.every(
        (item) => item.matchedFoodId.isNotEmpty && item.grams > 0,
      );
}

class PhotoReviewItem {
  const PhotoReviewItem({
    required this.id,
    required this.name,
    required this.detectedName,
    required this.matchedFoodName,
    required this.matchedFoodId,
    required this.quantity,
    required this.unit,
    required this.grams,
    required this.preview,
    required this.confidence,
    required this.isRemoved,
    this.gramsPerUnit = 0,
    this.minGrams = 0,
    this.maxGrams = 0,
    this.reasoning = '',
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
      detectedName: json['detected_name']?.toString() ?? '',
      matchedFoodName: json['matched_food_name']?.toString() ?? '',
      matchedFoodId: json['matched_food']?.toString() ?? '',
      quantity: _asDouble(
        json['effective_quantity_value'] ?? json['quantity_value'],
        fallback: 1,
      ),
      unit: json['effective_quantity_unit']?.toString() ??
          json['quantity_unit']?.toString() ??
          'serving',
      grams: _asDouble(json['effective_total_grams']),
      gramsPerUnit: _asDouble(json['grams_per_unit_estimate']),
      minGrams: _asDouble(json['min_total_grams_estimate']),
      maxGrams: _asDouble(json['max_total_grams_estimate']),
      preview: MacroPreview.fromJson(json),
      confidence: _asDouble(json['confidence_score']),
      isRemoved: json['is_removed'] == true,
      reasoning: json['reasoning_short']?.toString() ?? '',
      sourceBadges: sourceBadges.map(_sourceBadgeLabel).toList(),
      warnings: warnings.map((warning) => warning.toString()).toList(),
      alternatives: alternatives
          .map((item) => FoodSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      addedManually: json['added_manually'] == true,
    );
  }

  final String id;
  final String name;
  final String detectedName;
  final String matchedFoodName;
  final String matchedFoodId;
  final double quantity;
  final String unit;
  final double grams;
  final double gramsPerUnit;
  final double minGrams;
  final double maxGrams;
  final MacroPreview preview;
  final double confidence;
  final bool isRemoved;
  final String reasoning;
  final List<String> sourceBadges;
  final List<String> warnings;
  final List<FoodSummary> alternatives;
  final bool addedManually;

  String get portionLabel =>
      '${_formatNumber(quantity)} ${_unitLabel(unit, quantity)}';

  String get gramsLabel =>
      grams > 0 ? '${_formatNumber(grams)}g' : 'grams needed';

  String get matchLabel {
    if (matchedFoodName.isNotEmpty && detectedName.isNotEmpty) {
      if (matchedFoodName.toLowerCase() != detectedName.toLowerCase()) {
        return 'Detected as $detectedName';
      }
    }
    return addedManually ? 'Added manually' : 'Detected from photo';
  }

  bool get needsAttention =>
      !isRemoved &&
      (matchedFoodId.isEmpty || grams <= 0 || warnings.isNotEmpty);
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

String _sourceBadgeLabel(Object? value) {
  if (value is Map<String, dynamic>) {
    final source = value['source_type']?.toString() ??
        value['source_name']?.toString() ??
        '';
    final verified = value['food_verified'] == true ? ' verified' : '';
    return source.isEmpty ? 'Source pending' : '$source$verified';
  }
  return value?.toString() ?? '';
}

String _formatNumber(double value) {
  if (value % 1 == 0) return value.toStringAsFixed(0);
  if (value >= 10) return value.toStringAsFixed(1);
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}

String _unitLabel(String unit, double quantity) {
  final normalized = unit.replaceAll('_', ' ');
  if (quantity == 1) return normalized;
  switch (normalized) {
    case 'serving':
      return 'servings';
    case 'egg':
      return 'eggs';
    case 'piece':
      return 'pieces';
    case 'slice':
      return 'slices';
    case 'bowl':
      return 'bowls';
    case 'cup':
      return 'cups';
    case 'scoop':
      return 'scoops';
    case 'glass':
      return 'glasses';
    case 'packet':
      return 'packets';
    case 'gram':
      return 'g';
    default:
      return normalized;
  }
}
