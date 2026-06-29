import '../api/api_client.dart';
import '../models/app_models.dart';

abstract class NutritionRepository {
  Future<DashboardSnapshot> dashboard();
  Future<BodyMetricTrend> bodyMetricTrend();
  Future<void> logBodyMetric({
    required double weightKg,
    DateTime? recordedOn,
  });
  Future<List<FoodSummary>> searchFoods(String query);
  Future<FoodDetail> foodDetail(String foodId);
  Future<List<MealLogSummary>> mealsForDate(DateTime date);
  Future<MacroPreview> manualFoodPreview({
    required String foodId,
    required double quantity,
    required String unit,
    double? totalGrams,
  });
  Future<void> addManualFood({
    required String foodId,
    required double quantity,
    required String unit,
    required String mealType,
    double? totalGrams,
  });
  Future<Map<String, dynamic>> quickAdd(String text, String mealType);
  Future<void> confirmQuickAdd(Map<String, dynamic> payload);
  Future<void> createCustomFood(Map<String, dynamic> payload);
  Future<List<HabitGridItem>> todayHabits();
  Future<void> checkHabit(String habitId, int completedCount);
  Future<void> uncheckHabit(String habitId);
  Future<Map<String, dynamic>> monthHabitGrid(String month);
  Future<PhotoReview> uploadMealPhoto(String path);
  Future<PhotoReview> photoReview(String analysisId);
  Future<PhotoReview> incrementPhotoFood(String detectedFoodId);
  Future<PhotoReview> decrementPhotoFood(String detectedFoodId);
  Future<PhotoReview> updatePhotoFood({
    required String detectedFoodId,
    double? quantity,
    String? unit,
    double? totalGrams,
    String? matchedFoodId,
    bool? isRemoved,
    String? correctionNote,
  });
  Future<PhotoReview> addManualPhotoFood({
    required String analysisId,
    required String foodId,
    double? quantity,
    String? unit,
    double? totalGrams,
  });
  Future<void> confirmPhotoMeal(String analysisId, String mealType);
}

class ApiNutritionRepository implements NutritionRepository {
  ApiNutritionRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DashboardSnapshot> dashboard() async {
    final today = DateTime.now();
    final summary = await _apiClient.get(
      '/api/nutrition/daily-summary/',
      queryParameters: {'date': _dateString(today)},
    );
    final habits = await todayHabits();
    final mealLogs = await mealsForDate(today);
    final bodyTrend = await bodyMetricTrend();
    final meals = [
      for (final log in mealLogs)
        for (final item in log.items) item,
    ];
    final data = summary.data as Map<String, dynamic>;
    final targetProgress =
        data['daily_target_progress'] as Map<String, dynamic>? ?? {};
    final caloriesTarget =
        targetProgress['calories_kcal'] as Map<String, dynamic>? ?? {};
    return DashboardSnapshot(
      consumedCalories: _asDouble(data['calories_kcal']),
      targetCalories: _asDouble(caloriesTarget['target'], fallback: 2000),
      proteinG: _asDouble(data['protein_g']),
      carbsG: _asDouble(data['carbs_g']),
      fatG: _asDouble(data['fat_g']),
      waterCompleted: habits
          .where((habit) => habit.unit == 'glasses')
          .fold<int>(0, (sum, habit) => sum + habit.completedCount),
      waterTarget: habits
          .where((habit) => habit.unit == 'glasses')
          .fold<int>(0, (sum, habit) => sum + habit.targetCount),
      meals: meals,
      habits: habits,
      weightTrend: bodyTrend.weights,
      latestWeightKg: bodyTrend.latestWeightKg,
      weightChangeKg: bodyTrend.changeKg,
      insight: _dashboardInsight(
        consumed: _asDouble(data['calories_kcal']),
        target: _asDouble(caloriesTarget['target'], fallback: 2000),
        protein: _asDouble(data['protein_g']),
        mealCount: meals.length,
      ),
    );
  }

  @override
  Future<BodyMetricTrend> bodyMetricTrend() async {
    final response = await _apiClient.get(
      '/api/body-metrics/trend/',
      queryParameters: {'days': 30},
    );
    return BodyMetricTrend.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> logBodyMetric({
    required double weightKg,
    DateTime? recordedOn,
  }) async {
    await _apiClient.post(
      '/api/body-metrics/',
      data: {
        'recorded_on': _dateString(recordedOn ?? DateTime.now()),
        'weight_kg': weightKg.toStringAsFixed(2),
      },
    );
  }

  @override
  Future<List<FoodSummary>> searchFoods(String query) async {
    final response = await _apiClient.get(
      '/api/foods/search/',
      queryParameters: {'q': query},
    );
    final data = response.data as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? const [];
    return results
        .map((item) => FoodSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<FoodDetail> foodDetail(String foodId) async {
    final response = await _apiClient.get('/api/foods/$foodId/');
    return FoodDetail.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<MealLogSummary>> mealsForDate(DateTime date) async {
    final response = await _apiClient.get(
      '/api/meals/',
      queryParameters: {'date': _dateString(date)},
    );
    return _extractList(response.data)
        .map((item) => MealLogSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MacroPreview> manualFoodPreview({
    required String foodId,
    required double quantity,
    required String unit,
    double? totalGrams,
  }) async {
    final food = await foodDetail(foodId);
    return food.previewFor(
      quantity: quantity,
      unit: unit,
      totalGrams: totalGrams,
    );
  }

  @override
  Future<void> addManualFood({
    required String foodId,
    required double quantity,
    required String unit,
    required String mealType,
    double? totalGrams,
  }) async {
    await _apiClient.post(
      '/api/meals/manual-add/',
      data: {
        'food_id': foodId,
        'quantity_value': quantity,
        'quantity_unit': unit,
        'meal_type': mealType,
        'date': _dateString(DateTime.now()),
        if (totalGrams != null) 'total_grams': totalGrams,
      },
    );
  }

  @override
  Future<Map<String, dynamic>> quickAdd(String text, String mealType) async {
    final response = await _apiClient.post(
      '/api/meals/quick-add-text/',
      data: {
        'text': text,
        'meal_type': mealType,
        'date': _dateString(DateTime.now()),
      },
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> confirmQuickAdd(Map<String, dynamic> payload) async {
    await _apiClient.post(
      '/api/meals/quick-add-text/confirm/',
      data: {
        'date': _dateString(DateTime.now()),
        ...payload,
      },
    );
  }

  @override
  Future<void> createCustomFood(Map<String, dynamic> payload) async {
    await _apiClient.post('/api/foods/custom/', data: payload);
  }

  @override
  Future<List<HabitGridItem>> todayHabits() async {
    final response = await _apiClient.get('/api/habits/today/');
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => HabitGridItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> checkHabit(String habitId, int completedCount) async {
    await _apiClient.post(
      '/api/habits/$habitId/check/',
      data: {
        'date': _dateString(DateTime.now()),
        'completed_count': completedCount,
        'is_completed': true,
      },
    );
  }

  @override
  Future<void> uncheckHabit(String habitId) async {
    await _apiClient.delete(
      '/api/habits/$habitId/check/',
      queryParameters: {'date': _dateString(DateTime.now())},
    );
  }

  @override
  Future<Map<String, dynamic>> monthHabitGrid(String month) async {
    final response = await _apiClient.get(
      '/api/habits/month-grid/',
      queryParameters: {'month': month},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<PhotoReview> uploadMealPhoto(String path) async {
    final response = await _apiClient.uploadFile(
      '/api/photos/analyze-meal/',
      fieldName: 'image',
      filePath: path,
    );
    final data = response.data as Map<String, dynamic>;
    final analysisId =
        data['analysis_id']?.toString() ?? data['id']?.toString() ?? '';
    if (analysisId.isEmpty) {
      return PhotoReview.fromJson(data);
    }
    return _pollPhotoReview(analysisId);
  }

  @override
  Future<PhotoReview> photoReview(String analysisId) async {
    final response =
        await _apiClient.get('/api/photos/analyses/$analysisId/review/');
    return PhotoReview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PhotoReview> _pollPhotoReview(String analysisId) async {
    PhotoReview review = await photoReview(analysisId);
    for (var attempt = 0; attempt < 8; attempt += 1) {
      final stillProcessing =
          review.status == 'uploaded' || review.status == 'processing';
      if (!stillProcessing || review.items.isNotEmpty) return review;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      review = await photoReview(analysisId);
    }
    return review;
  }

  @override
  Future<PhotoReview> incrementPhotoFood(String detectedFoodId) async {
    final response = await _apiClient.post(
      '/api/photos/detected-foods/$detectedFoodId/increment/',
    );
    return PhotoReview.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PhotoReview> decrementPhotoFood(String detectedFoodId) async {
    final response = await _apiClient.post(
      '/api/photos/detected-foods/$detectedFoodId/decrement/',
    );
    return PhotoReview.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PhotoReview> updatePhotoFood({
    required String detectedFoodId,
    double? quantity,
    String? unit,
    double? totalGrams,
    String? matchedFoodId,
    bool? isRemoved,
    String? correctionNote,
  }) async {
    final response = await _apiClient.patch(
      '/api/photos/detected-foods/$detectedFoodId/',
      data: {
        if (quantity != null) 'user_quantity_value': quantity,
        if (unit != null) 'user_quantity_unit': unit,
        if (totalGrams != null) 'user_total_grams': totalGrams,
        if (matchedFoodId != null) 'matched_food': matchedFoodId,
        if (isRemoved != null) 'is_removed': isRemoved,
        if (correctionNote != null) 'correction_note': correctionNote,
      },
    );
    return PhotoReview.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PhotoReview> addManualPhotoFood({
    required String analysisId,
    required String foodId,
    double? quantity,
    String? unit,
    double? totalGrams,
  }) async {
    final response = await _apiClient.post(
      '/api/photos/analyses/$analysisId/add-manual-food/',
      data: {
        'food_id': foodId,
        if (quantity != null) 'quantity_value': quantity,
        if (unit != null) 'quantity_unit': unit,
        if (totalGrams != null) 'total_grams': totalGrams,
      },
    );
    return PhotoReview.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> confirmPhotoMeal(String analysisId, String mealType) async {
    await _apiClient.post(
      '/api/photos/analyses/$analysisId/confirm-as-meal/',
      data: {
        'meal_type': mealType,
        'date': _dateString(DateTime.now()),
      },
    );
  }
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

List<dynamic> _extractList(Object? data) {
  if (data is List<dynamic>) return data;
  if (data is Map<String, dynamic>) {
    return data['results'] as List<dynamic>? ?? const [];
  }
  return const [];
}

String _dateString(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _dashboardInsight({
  required double consumed,
  required double target,
  required double protein,
  required int mealCount,
}) {
  if (mealCount == 0) {
    return 'Start with a manual log or photo scan so today’s insights use your real meals.';
  }
  if (target > 0 && consumed > target) {
    return 'Calories are above target today. Review portions before adding more snacks.';
  }
  if (protein < 50) {
    return 'Protein is still light today. A high-protein meal can improve the day’s balance.';
  }
  return 'Today’s log is building well. Keep confirming portions for the most accurate trends.';
}

class MockNutritionRepository implements NutritionRepository {
  static const _foods = [
    FoodSummary(
      id: 'egg',
      name: 'Egg, whole, boiled',
      brand: '',
      sourceBadge: 'IFCT_2017',
      confidenceScore: 0.95,
      dataClassification: 'official_verified',
      verified: true,
      preview: MacroPreview(
        caloriesKcal: 155,
        proteinG: 12.6,
        carbsG: 1.1,
        fatG: 10.6,
      ),
    ),
    FoodSummary(
      id: 'rice',
      name: 'Cooked rice',
      brand: '',
      sourceBadge: 'USDA_FDC',
      confidenceScore: 0.92,
      dataClassification: 'official_verified',
      verified: true,
      preview: MacroPreview(
        caloriesKcal: 130,
        proteinG: 2.7,
        carbsG: 28,
        fatG: 0.3,
      ),
    ),
    FoodSummary(
      id: 'dal',
      name: 'Dal',
      brand: 'Home style',
      sourceBadge: 'IFCT_2017',
      confidenceScore: 0.82,
      dataClassification: 'official_unverified',
      verified: true,
      preview: MacroPreview(
        caloriesKcal: 116,
        proteinG: 7.2,
        carbsG: 18,
        fatG: 2,
      ),
    ),
  ];

  @override
  Future<DashboardSnapshot> dashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return DashboardSnapshot(
      consumedCalories: 1420,
      targetCalories: 2100,
      proteinG: 96,
      carbsG: 168,
      fatG: 48,
      waterCompleted: 5,
      waterTarget: 8,
      meals: const [
        MealItemSummary(
          foodName: 'Egg bhurji and toast',
          mealType: 'breakfast',
          caloriesKcal: 420,
        ),
        MealItemSummary(
          foodName: 'Dal rice bowl',
          mealType: 'lunch',
          caloriesKcal: 610,
        ),
      ],
      habits: [
        HabitGridItem(
          habitId: 'water',
          title: 'Drink 8 glasses water',
          unit: 'glasses',
          targetCount: 8,
          completedCount: 5,
          isCompleted: false,
          currentStreak: 4,
          color: '#0EA5E9',
          icon: 'droplets',
        ),
        HabitGridItem(
          habitId: 'protein',
          title: 'Eat 100g protein',
          unit: 'grams',
          targetCount: 100,
          completedCount: 96,
          isCompleted: false,
          currentStreak: 2,
          color: '#E66F51',
          icon: 'drumstick',
        ),
      ],
      weightTrend: const [74.2, 74.0, 73.9, 73.4, 73.2, 73.0, 72.8],
      latestWeightKg: 72.8,
      weightChangeKg: -1.4,
      insight:
          'Your protein is nearly on target. A light high-protein snack would close the day well.',
    );
  }

  @override
  Future<BodyMetricTrend> bodyMetricTrend() async {
    return const BodyMetricTrend(
      weights: [74.2, 74.0, 73.9, 73.4, 73.2, 73.0, 72.8],
      latestWeightKg: 72.8,
      changeKg: -1.4,
    );
  }

  @override
  Future<void> logBodyMetric({
    required double weightKg,
    DateTime? recordedOn,
  }) async {}

  @override
  Future<List<FoodSummary>> searchFoods(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final normalized = query.toLowerCase();
    return _foods
        .where((food) => food.name.toLowerCase().contains(normalized))
        .toList();
  }

  @override
  Future<FoodDetail> foodDetail(String foodId) async {
    final food = _foods.firstWhere((food) => food.id == foodId);
    return FoodDetail(
      id: food.id,
      name: food.name,
      brand: food.brand,
      description: 'Mock food for UI development.',
      sourceBadge: food.sourceBadge,
      confidenceScore: food.confidenceScore,
      dataClassification: food.dataClassification,
      verified: food.verified,
      defaultServingG: 50,
      servings: const [
        FoodServingOption(
          id: 'default',
          name: '1 serving',
          grams: 50,
          isDefault: true,
        ),
      ],
      nutrients: [
        FoodNutrientValue(
          code: 'calories',
          name: 'Calories',
          unit: 'kcal',
          amountPer100g: food.preview.caloriesKcal,
        ),
        FoodNutrientValue(
          code: 'protein_g',
          name: 'Protein',
          unit: 'g',
          amountPer100g: food.preview.proteinG,
        ),
        FoodNutrientValue(
          code: 'carbs_g',
          name: 'Carbs',
          unit: 'g',
          amountPer100g: food.preview.carbsG,
        ),
        FoodNutrientValue(
          code: 'fat_g',
          name: 'Fat',
          unit: 'g',
          amountPer100g: food.preview.fatG,
        ),
      ],
      isFavorite: false,
    );
  }

  @override
  Future<List<MealLogSummary>> mealsForDate(DateTime date) async {
    return const [
      MealLogSummary(
        id: 'breakfast',
        date: '2026-06-29',
        mealType: 'breakfast',
        name: 'Breakfast',
        items: [
          MealItemSummary(
            foodName: 'Egg bhurji and toast',
            mealType: 'breakfast',
            caloriesKcal: 420,
            source: 'IFCT_2017',
            confidence: 0.92,
            verified: true,
            classification: 'official_verified',
            quantity: 1,
            unit: 'serving',
            grams: 240,
          ),
        ],
      ),
    ];
  }

  @override
  Future<MacroPreview> manualFoodPreview({
    required String foodId,
    required double quantity,
    required String unit,
    double? totalGrams,
  }) async {
    final food = _foods.firstWhere((food) => food.id == foodId);
    final grams = totalGrams ?? quantity * 50;
    final scale = grams / 100;
    return MacroPreview(
      caloriesKcal: food.preview.caloriesKcal * scale,
      proteinG: food.preview.proteinG * scale,
      carbsG: food.preview.carbsG * scale,
      fatG: food.preview.fatG * scale,
    );
  }

  @override
  Future<void> addManualFood({
    required String foodId,
    required double quantity,
    required String unit,
    required String mealType,
    double? totalGrams,
  }) async {}

  @override
  Future<Map<String, dynamic>> quickAdd(String text, String mealType) async {
    return {
      'text': text,
      'requires_review': false,
      'confidence': 0.92,
      'preview': {
        'calories_kcal': 155,
        'protein_g': 12.6,
        'carbs_g': 1.1,
        'fat_g': 10.6,
      },
      'parsed_items': [
        {
          'food_id': 'egg',
          'food_name': 'Egg, whole, boiled',
          'quantity_value': 2,
          'quantity_unit': 'egg',
          'effective_total_grams': 100,
        },
      ],
    };
  }

  @override
  Future<void> confirmQuickAdd(Map<String, dynamic> payload) async {}

  @override
  Future<void> createCustomFood(Map<String, dynamic> payload) async {}

  @override
  Future<List<HabitGridItem>> todayHabits() async => (await dashboard()).habits;

  @override
  Future<void> checkHabit(String habitId, int completedCount) async {}

  @override
  Future<void> uncheckHabit(String habitId) async {}

  @override
  Future<Map<String, dynamic>> monthHabitGrid(String month) async {
    return {'month': month, 'days': <Map<String, dynamic>>[], 'stats': {}};
  }

  @override
  Future<PhotoReview> uploadMealPhoto(String path) async {
    return const PhotoReview(
      analysisId: 'mock-analysis',
      status: 'needs_review',
      imageUrl: '',
      disclaimer:
          'Photo nutrition is an estimate. Confirm food and portion size for better accuracy.',
      totalPreview: MacroPreview(
        caloriesKcal: 388,
        proteinG: 31.5,
        carbsG: 2.8,
        fatG: 26.5,
      ),
      warnings: [],
      items: [
        PhotoReviewItem(
          id: 'photo-egg',
          name: 'Boiled eggs',
          matchedFoodId: 'egg',
          quantity: 5,
          unit: 'egg',
          grams: 250,
          preview: MacroPreview(
            caloriesKcal: 388,
            proteinG: 31.5,
            carbsG: 2.8,
            fatG: 26.5,
          ),
          confidence: 0.88,
          isRemoved: false,
          sourceBadges: ['IFCT_2017'],
        ),
      ],
    );
  }

  @override
  Future<PhotoReview> photoReview(String analysisId) => uploadMealPhoto('');

  @override
  Future<PhotoReview> incrementPhotoFood(String detectedFoodId) async {
    return const PhotoReview(
      analysisId: 'mock-analysis',
      status: 'needs_review',
      imageUrl: '',
      disclaimer:
          'Photo nutrition is an estimate. Confirm food and portion size for better accuracy.',
      totalPreview: MacroPreview(
          caloriesKcal: 465, proteinG: 37.8, carbsG: 3.3, fatG: 31.8),
      warnings: [],
      items: [
        PhotoReviewItem(
          id: 'photo-egg',
          name: 'Boiled eggs',
          matchedFoodId: 'egg',
          quantity: 6,
          unit: 'egg',
          grams: 300,
          preview: MacroPreview(
            caloriesKcal: 465,
            proteinG: 37.8,
            carbsG: 3.3,
            fatG: 31.8,
          ),
          confidence: 0.88,
          isRemoved: false,
          sourceBadges: ['IFCT_2017'],
        ),
      ],
    );
  }

  @override
  Future<PhotoReview> decrementPhotoFood(String detectedFoodId) =>
      uploadMealPhoto('');

  @override
  Future<PhotoReview> updatePhotoFood({
    required String detectedFoodId,
    double? quantity,
    String? unit,
    double? totalGrams,
    String? matchedFoodId,
    bool? isRemoved,
    String? correctionNote,
  }) =>
      uploadMealPhoto('');

  @override
  Future<PhotoReview> addManualPhotoFood({
    required String analysisId,
    required String foodId,
    double? quantity,
    String? unit,
    double? totalGrams,
  }) =>
      uploadMealPhoto('');

  @override
  Future<void> confirmPhotoMeal(String analysisId, String mealType) async {}
}
