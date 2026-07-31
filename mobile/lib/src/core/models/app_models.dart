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

class NutritionTargetPlan {
  const NutritionTargetPlan({
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.waterMl,
    required this.method,
    required this.disclaimer,
    this.assumptions = const [],
    this.customized = false,
    this.requiresConfirmation = false,
  });

  factory NutritionTargetPlan.fromJson(Map<String, dynamic> json) {
    final targets = json['targets'] as Map<String, dynamic>? ?? const {};
    return NutritionTargetPlan(
      caloriesKcal: _asDouble(targets['calories_kcal']),
      proteinG: _asDouble(targets['protein_g']),
      carbsG: _asDouble(targets['carbs_g']),
      fatG: _asDouble(targets['fat_g']),
      fiberG: _asDouble(targets['fiber_g']),
      waterMl: _asDouble(targets['water_ml']),
      method: json['method']?.toString() ?? '',
      disclaimer: json['disclaimer']?.toString() ?? '',
      assumptions: (json['assumptions'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      customized: json['customized'] == true,
      requiresConfirmation: json['requires_confirmation'] == true,
    );
  }

  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double waterMl;
  final String method;
  final String disclaimer;
  final List<String> assumptions;
  final bool customized;
  final bool requiresConfirmation;
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
    this.preparationState = 'unspecified',
    this.ingredientsText = '',
    this.allergens = const [],
    this.personalPortionGrams = const {},
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
      preparationState: json['preparation_state']?.toString() ?? 'unspecified',
      ingredientsText: json['ingredients_text']?.toString() ?? '',
      allergens: (json['allergens'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      personalPortionGrams: _personalPortionMap(json),
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
  final String preparationState;
  final String ingredientsText;
  final List<String> allergens;
  final Map<String, double> personalPortionGrams;
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

class FoodSearchRequest {
  const FoodSearchRequest({
    required this.query,
    this.page = 1,
    this.pageSize = 25,
    this.foodType = '',
    this.source = '',
    this.preparationState = '',
    this.verified,
  });

  final String query;
  final int page;
  final int pageSize;
  final String foodType;
  final String source;
  final String preparationState;
  final bool? verified;

  Map<String, dynamic> get queryParameters => {
        'q': query.trim(),
        'page': page,
        'page_size': pageSize,
        if (foodType.isNotEmpty) 'food_type': foodType,
        if (source.isNotEmpty) 'source': source,
        if (preparationState.isNotEmpty) 'preparation_state': preparationState,
        if (verified != null) 'verified': verified,
      };

  String get cacheKey => [
        query.trim().toLowerCase(),
        page,
        pageSize,
        foodType,
        source,
        preparationState,
        verified,
      ].join('|');

  FoodSearchRequest copyWith({int? page}) => FoodSearchRequest(
        query: query,
        page: page ?? this.page,
        pageSize: pageSize,
        foodType: foodType,
        source: source,
        preparationState: preparationState,
        verified: verified,
      );
}

class FoodSearchPage {
  const FoodSearchPage({
    required this.items,
    required this.count,
    required this.page,
    required this.hasMore,
  });

  factory FoodSearchPage.fromJson(
    Map<String, dynamic> json, {
    required int page,
  }) {
    final values = json['results'] as List<dynamic>? ?? const [];
    return FoodSearchPage(
      items: values
          .map((item) => FoodSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      count: (json['count'] as num?)?.toInt() ?? values.length,
      page: page,
      hasMore: json['next'] != null,
    );
  }

  final List<FoodSummary> items;
  final int count;
  final int page;
  final bool hasMore;
}

class NutrientEstimateRange {
  const NutrientEstimateRange({
    required this.minimum,
    required this.likely,
    required this.maximum,
  });

  factory NutrientEstimateRange.fromJson(Map<String, dynamic> json) {
    return NutrientEstimateRange(
      minimum: _asDouble(json['min']),
      likely: _asDouble(json['likely']),
      maximum: _asDouble(json['max']),
    );
  }

  final double minimum;
  final double likely;
  final double maximum;
}

class CustomFoodReference {
  const CustomFoodReference({
    required this.foodId,
    required this.name,
    required this.brand,
    required this.preparationState,
    required this.sourceName,
    required this.sourceBadge,
    required this.matchScore,
    required this.nutrients,
  });

  factory CustomFoodReference.fromJson(Map<String, dynamic> json) {
    final source = json['source'];
    final sourceMap = source is Map<String, dynamic> ? source : const {};
    final nutrients = json['nutrients_for_entered_serving'];
    return CustomFoodReference(
      foodId: json['food_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Reference food',
      brand: json['brand']?.toString() ?? '',
      preparationState: json['preparation_state']?.toString() ?? 'unspecified',
      sourceName:
          sourceMap['name']?.toString() ?? (source is String ? source : ''),
      sourceBadge: json['source_badge']?.toString() ??
          sourceMap['source_type']?.toString() ??
          '',
      matchScore: _asDouble(json['name_match_score']),
      nutrients: _doubleMap(nutrients),
    );
  }

  final String foodId;
  final String name;
  final String brand;
  final String preparationState;
  final String sourceName;
  final String sourceBadge;
  final double matchScore;
  final Map<String, double> nutrients;
}

class CustomFoodEstimate {
  const CustomFoodEstimate({
    required this.normalizedFoodName,
    required this.suggestedNutrients,
    required this.ranges,
    required this.references,
    required this.sourceBadges,
    required this.confidence,
    required this.warnings,
    required this.canEstimate,
    required this.requiresReview,
    required this.message,
    required this.calculatedCaloriesFromMacros,
    required this.accuracyNotice,
    required this.estimationMethod,
  });

  factory CustomFoodEstimate.fromJson(Map<String, dynamic> json) {
    final rangeJson = json['estimated_range'] as Map<String, dynamic>? ?? {};
    final references = json['reference_matches'] as List<dynamic>? ?? const [];
    return CustomFoodEstimate(
      normalizedFoodName: json['normalized_food_name']?.toString() ?? '',
      suggestedNutrients: _doubleMap(json['suggested_nutrients']),
      ranges: {
        for (final entry in rangeJson.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: NutrientEstimateRange.fromJson(
              entry.value as Map<String, dynamic>,
            ),
      },
      references: references
          .map(
            (item) =>
                CustomFoodReference.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      sourceBadges: (json['source_badges'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      confidence: _asDouble(json['confidence']),
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      canEstimate: json['can_estimate'] == true,
      requiresReview: json['requires_review'] != false,
      message: json['message']?.toString() ?? '',
      calculatedCaloriesFromMacros:
          _asDouble(json['calculated_calories_from_macros']),
      accuracyNotice: json['accuracy_notice']?.toString() ?? '',
      estimationMethod: json['estimation_method']?.toString() ?? '',
    );
  }

  final String normalizedFoodName;
  final Map<String, double> suggestedNutrients;
  final Map<String, NutrientEstimateRange> ranges;
  final List<CustomFoodReference> references;
  final List<String> sourceBadges;
  final double confidence;
  final List<String> warnings;
  final bool canEstimate;
  final bool requiresReview;
  final String message;
  final double calculatedCaloriesFromMacros;
  final String accuracyNotice;
  final String estimationMethod;
}

class CustomFoodReview {
  const CustomFoodReview({
    required this.status,
    required this.servingQuantity,
    required this.servingUnit,
    required this.servingWeightG,
    required this.estimationMethod,
    required this.originalEstimate,
    required this.estimate,
    required this.confirmedNutrients,
    required this.effectiveNutrients,
    required this.references,
    required this.confidence,
    required this.userCorrections,
    required this.warnings,
    required this.calculatedCaloriesFromMacros,
    required this.requiresReview,
    required this.version,
  });

  factory CustomFoodReview.fromJson(Map<String, dynamic> json) {
    final references = json['reference_foods'] as List<dynamic>? ?? const [];
    return CustomFoodReview(
      status: json['status']?.toString() ?? 'draft',
      servingQuantity: _asDouble(json['serving_quantity'], fallback: 1),
      servingUnit: json['serving_unit']?.toString() ?? 'serving',
      servingWeightG: _asDouble(json['serving_weight_g']),
      estimationMethod: json['estimation_method']?.toString() ?? '',
      originalEstimate: _doubleMap(json['original_estimated_nutrients']),
      estimate: _doubleMap(json['estimated_nutrients']),
      confirmedNutrients: _doubleMap(json['confirmed_nutrients']),
      effectiveNutrients: _doubleMap(json['effective_review_nutrients']),
      references: references
          .whereType<Map<String, dynamic>>()
          .map(CustomFoodReference.fromJson)
          .toList(),
      confidence: _asDouble(json['confidence']),
      userCorrections: _doubleMap(json['user_corrections']),
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      calculatedCaloriesFromMacros:
          _asDouble(json['calculated_calories_from_macros']),
      requiresReview: json['requires_review'] == true,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  final String status;
  final double servingQuantity;
  final String servingUnit;
  final double servingWeightG;
  final String estimationMethod;
  final Map<String, double> originalEstimate;
  final Map<String, double> estimate;
  final Map<String, double> confirmedNutrients;
  final Map<String, double> effectiveNutrients;
  final List<CustomFoodReference> references;
  final double confidence;
  final Map<String, double> userCorrections;
  final List<String> warnings;
  final double calculatedCaloriesFromMacros;
  final bool requiresReview;
  final int version;
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
    this.preparationState = 'unspecified',
    this.ingredientsText = '',
    this.allergens = const [],
    this.personalPortionGrams = const {},
    this.customFood,
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
      preparationState: json['preparation_state']?.toString() ?? 'unspecified',
      ingredientsText: json['ingredients_text']?.toString() ?? '',
      allergens: (json['allergens'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      personalPortionGrams: _personalPortionMap(json),
      customFood: json['custom_food'] is Map<String, dynamic>
          ? CustomFoodReview.fromJson(
              json['custom_food'] as Map<String, dynamic>,
            )
          : null,
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
  final String preparationState;
  final String ingredientsText;
  final List<String> allergens;
  final Map<String, double> personalPortionGrams;
  final CustomFoodReview? customFood;

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
    final personalGrams = personalPortionGrams[unit];
    if (personalGrams != null && personalGrams > 0) {
      return quantity * personalGrams;
    }
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

Map<String, double> _personalPortionMap(Map<String, dynamic> json) {
  final entries =
      json['personal_portion_preferences'] as List<dynamic>? ?? const [];
  return {
    for (final item in entries)
      if (item is Map<String, dynamic> &&
          (item['unit']?.toString().isNotEmpty ?? false))
        item['unit'].toString(): _asDouble(item['grams_per_unit']),
  };
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
    this.preparationState = 'unspecified',
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
      preparationState:
          json['food_preparation_state']?.toString() ?? 'unspecified',
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
  final String preparationState;
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

class HabitTemplateSummary {
  const HabitTemplateSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.defaultTargetCount,
    required this.unit,
    required this.icon,
  });

  factory HabitTemplateSummary.fromJson(Map<String, dynamic> json) {
    return HabitTemplateSummary(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'custom',
      defaultTargetCount: _asInt(json['default_target_count'], fallback: 1),
      unit: json['unit']?.toString() ?? 'checkbox',
      icon: json['icon']?.toString() ?? 'check',
    );
  }

  final String id;
  final String title;
  final String description;
  final String category;
  final int defaultTargetCount;
  final String unit;
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
    this.targetProteinG = 0,
    this.targetCarbsG = 0,
    this.targetFatG = 0,
    this.targetFiberG = 0,
    this.targetWaterMl = 0,
    this.sugarG = 0,
    this.sodiumMg = 0,
    this.micronutrients = const {},
    this.waterMl = 0,
    this.steps = 0,
    this.workoutMinutes = 0,
    this.exerciseCalories = 0,
  });

  final double consumedCalories;
  final double targetCalories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double targetProteinG;
  final double targetCarbsG;
  final double targetFatG;
  final double targetFiberG;
  final double targetWaterMl;
  final double sugarG;
  final double sodiumMg;
  final Map<String, double> micronutrients;
  final double waterMl;
  final int steps;
  final int workoutMinutes;
  final double exerciseCalories;
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

class NutritionDaySummary {
  const NutritionDaySummary({
    required this.date,
    required this.preview,
  });

  factory NutritionDaySummary.fromJson(Map<String, dynamic> json) {
    return NutritionDaySummary(
      date: json['date']?.toString() ?? '',
      preview: MacroPreview.fromJson(json),
    );
  }

  final String date;
  final MacroPreview preview;

  bool get hasLoggedNutrition =>
      preview.caloriesKcal > 0 ||
      preview.proteinG > 0 ||
      preview.carbsG > 0 ||
      preview.fatG > 0;
}

class HabitCompletionDay {
  const HabitCompletionDay({
    required this.date,
    required this.completed,
    required this.total,
  });

  factory HabitCompletionDay.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? const [];
    final total = items.length;
    final completed = items.where((item) {
      if (item is! Map<String, dynamic>) return false;
      return item['is_completed'] == true;
    }).length;
    return HabitCompletionDay(
      date: json['date']?.toString() ?? '',
      completed: completed,
      total: total,
    );
  }

  final String date;
  final int completed;
  final int total;

  double get completionRate => total <= 0 ? 0 : completed / total;
}

class ProgressReport {
  const ProgressReport({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.totals,
    required this.averages,
    required this.weightTrend,
    required this.habitDays,
    required this.insights,
  });

  factory ProgressReport.fromJson({
    required Map<String, dynamic> rangeSummary,
    required BodyMetricTrend weightTrend,
    required Map<String, dynamic> habitMonthGrid,
  }) {
    final dayRows = rangeSummary['days'] as List<dynamic>? ?? const [];
    final habitRows = habitMonthGrid['days'] as List<dynamic>? ?? const [];
    final days = dayRows
        .map((item) =>
            NutritionDaySummary.fromJson(item as Map<String, dynamic>))
        .toList();
    final startDate = rangeSummary['start']?.toString() ??
        (days.isNotEmpty ? days.first.date : '');
    final endDate = rangeSummary['end']?.toString() ??
        (days.isNotEmpty ? days.last.date : '');
    final report = ProgressReport(
      startDate: startDate,
      endDate: endDate,
      days: days,
      totals: MacroPreview.fromJson(
        rangeSummary['totals'] as Map<String, dynamic>? ?? const {},
      ),
      averages: MacroPreview.fromJson(
        rangeSummary['averages'] as Map<String, dynamic>? ?? const {},
      ),
      weightTrend: weightTrend,
      habitDays: habitRows
          .map((item) =>
              HabitCompletionDay.fromJson(item as Map<String, dynamic>))
          .where((day) {
        if (startDate.isEmpty || endDate.isEmpty) return true;
        return day.date.compareTo(startDate) >= 0 &&
            day.date.compareTo(endDate) <= 0;
      }).toList(),
      insights: const [],
    );
    return report.copyWith(insights: _progressInsights(report));
  }

  final String startDate;
  final String endDate;
  final List<NutritionDaySummary> days;
  final MacroPreview totals;
  final MacroPreview averages;
  final BodyMetricTrend weightTrend;
  final List<HabitCompletionDay> habitDays;
  final List<String> insights;

  int get loggedDays => days.where((day) => day.hasLoggedNutrition).length;
  double get averageCalories => averages.caloriesKcal;
  double get averageProtein => averages.proteinG;
  double get highestCalories => days.fold<double>(
        0,
        (highest, day) => day.preview.caloriesKcal > highest
            ? day.preview.caloriesKcal
            : highest,
      );
  double get totalHabitCompletionRate {
    final total = habitDays.fold<int>(0, (sum, day) => sum + day.total);
    if (total <= 0) return 0;
    final completed = habitDays.fold<int>(0, (sum, day) => sum + day.completed);
    return completed / total;
  }

  ProgressReport copyWith({List<String>? insights}) {
    return ProgressReport(
      startDate: startDate,
      endDate: endDate,
      days: days,
      totals: totals,
      averages: averages,
      weightTrend: weightTrend,
      habitDays: habitDays,
      insights: insights ?? this.insights,
    );
  }
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
    this.eatenPercentage = 100,
    this.splitParentId = '',
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
      eatenPercentage: _asDouble(
        json['eaten_percentage'],
        fallback: 100,
      ),
      splitParentId: json['split_parent']?.toString() ?? '',
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
  final double eatenPercentage;
  final String splitParentId;

  String get portionLabel =>
      '${_formatNumber(quantity)} ${_unitLabel(unit, quantity)}';

  String get gramsLabel =>
      grams > 0 ? '${_formatNumber(grams)}g' : 'grams needed';

  String get estimateRangeLabel => minGrams > 0 && maxGrams > 0
      ? '${_formatNumber(minGrams)}-${_formatNumber(maxGrams)}g likely'
      : '';

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

class NutritionLabelReview {
  const NutritionLabelReview({
    required this.analysisId,
    required this.status,
    required this.imageUrl,
    required this.productName,
    required this.brand,
    required this.servingSize,
    required this.barcode,
    required this.nutrients,
    required this.ingredients,
    required this.allergens,
    required this.confidence,
  });

  factory NutritionLabelReview.fromJson(Map<String, dynamic> json) {
    final label = json['nutrition_label_scan'] as Map<String, dynamic>? ?? {};
    return NutritionLabelReview(
      analysisId: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'processing',
      imageUrl: json['image_url']?.toString() ?? '',
      productName: label['product_name']?.toString() ?? '',
      brand: label['brand']?.toString() ?? '',
      servingSize: label['serving_size']?.toString() ?? '',
      barcode: label['barcode']?.toString() ?? '',
      nutrients: Map<String, dynamic>.from(
        label['parsed_nutrients'] as Map? ?? const {},
      ),
      ingredients: label['ingredients_text']?.toString() ?? '',
      allergens: (label['allergens'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      confidence: _asDouble(label['confidence_score']),
    );
  }

  final String analysisId;
  final String status;
  final String imageUrl;
  final String productName;
  final String brand;
  final String servingSize;
  final String barcode;
  final Map<String, dynamic> nutrients;
  final String ingredients;
  final List<String> allergens;
  final double confidence;

  bool get isProcessing => status == 'uploaded' || status == 'processing';
}

Map<String, double> _doubleMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      entry.key.toString(): _asDouble(entry.value),
  };
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

List<String> _progressInsights(ProgressReport report) {
  final insights = <String>[];
  if (report.loggedDays == 0) {
    return [
      'Start logging meals to unlock calorie, protein, and macro trends.',
      'A week of entries will make this report much more useful.',
    ];
  }
  if (report.loggedDays < report.days.length) {
    insights.add(
      'You logged ${report.loggedDays} of ${report.days.length} days. More complete logs will make trends more reliable.',
    );
  } else {
    insights.add('You logged every day in this report window.');
  }
  if (report.averageProtein >= 100) {
    insights.add(
      'Protein averaged ${report.averageProtein.toStringAsFixed(0)}g per day, which is strong for training consistency.',
    );
  } else if (report.averageProtein > 0) {
    insights.add(
      'Protein averaged ${report.averageProtein.toStringAsFixed(0)}g per day. Add a protein anchor to one more meal if your goal is muscle gain or retention.',
    );
  }
  if (report.totalHabitCompletionRate >= 0.8) {
    insights.add('Habit completion is strong this week.');
  } else if (report.habitDays.any((day) => day.total > 0)) {
    insights.add(
      'Habit completion is ${(report.totalHabitCompletionRate * 100).toStringAsFixed(0)}%. Pick one habit to protect first.',
    );
  }
  if (report.weightTrend.changeKg != null) {
    final change = report.weightTrend.changeKg!;
    if (change.abs() >= 0.1) {
      final direction = change > 0 ? 'up' : 'down';
      insights.add(
        'Weight is $direction ${change.abs().toStringAsFixed(1)} kg across the tracked period.',
      );
    }
  }
  return insights.take(4).toList();
}
