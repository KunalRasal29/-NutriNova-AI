import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../models/app_models.dart';

class _FoodSearchCacheEntry {
  const _FoodSearchCacheEntry(this.page, this.savedAt);

  final FoodSearchPage page;
  final DateTime savedAt;

  bool get isFresh =>
      DateTime.now().difference(savedAt) < const Duration(seconds: 90);
}

abstract class NutritionRepository {
  Future<DashboardSnapshot> dashboard();
  Future<ProgressReport> progressReport();
  Future<BodyMetricTrend> bodyMetricTrend();
  Future<void> logBodyMetric({
    required double weightKg,
    DateTime? recordedOn,
  });
  Future<NutritionTargetPlan> nutritionTargets();
  Future<NutritionTargetPlan> estimateNutritionTargets();
  Future<NutritionTargetPlan> applyEstimatedNutritionTargets();
  Future<NutritionTargetPlan> updateNutritionTargets(
    Map<String, dynamic> payload,
  );
  Future<List<FoodSummary>> searchFoods(String query);
  Future<FoodSearchPage> searchFoodsAdvanced(FoodSearchRequest request);
  Future<List<FoodSummary>> recentFoods();
  Future<List<FoodSummary>> frequentFoods();
  Future<List<FoodSummary>> usualFoods(String mealType);
  Future<List<FoodSummary>> favoriteFoods();
  Future<List<FoodSummary>> myFoods();
  Future<void> setFoodFavorite({
    required String foodId,
    required bool isFavorite,
  });
  Future<List<FoodSummary>> lookupBarcode(String barcode);
  Future<FoodDetail> foodDetail(String foodId);
  Future<List<MealLogSummary>> mealsForDate(DateTime date);
  Future<void> copyYesterday(DateTime targetDate);
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
  Future<void> updateMealItem({
    required String itemId,
    required String foodId,
    required double quantity,
    required String unit,
    double? totalGrams,
  });
  Future<void> deleteMealItem(String itemId);
  Future<Map<String, dynamic>> quickAdd(String text, String mealType);
  Future<void> confirmQuickAdd(Map<String, dynamic> payload);
  Future<FoodDetail> createCustomFood(Map<String, dynamic> payload);
  Future<List<FoodDetail>> customFoods();
  Future<CustomFoodEstimate> estimateCustomFood(Map<String, dynamic> payload);
  Future<FoodDetail> customFoodDetail(String foodId);
  Future<FoodDetail> updateCustomFood(
    String foodId,
    Map<String, dynamic> payload,
  );
  Future<CustomFoodEstimate> reEstimateCustomFood(
    String foodId,
    Map<String, dynamic> payload,
  );
  Future<FoodDetail> confirmCustomFood(
    String foodId,
    Map<String, dynamic> payload,
  );
  Future<List<Map<String, dynamic>>> customFoodHistory(String foodId);
  Future<void> logCustomFood(
    String foodId, {
    required String mealType,
    double quantity = 1,
    String unit = 'serving',
    double? totalGrams,
  });
  Future<void> archiveCustomFood(String foodId);
  Future<Map<String, dynamic>> createRecipe(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> calculateRecipe(String recipeId);
  Future<void> logRecipeAsMeal({
    required String recipeId,
    required String mealType,
  });
  Future<List<HabitGridItem>> todayHabits();
  Future<List<HabitTemplateSummary>> habitTemplates();
  Future<void> createHabitFromTemplate(String templateId);
  Future<void> createHabit({
    required String title,
    required int targetCount,
    required String unit,
    required String category,
  });
  Future<void> checkHabit(
    String habitId,
    int completedCount, {
    bool isCompleted = true,
  });
  Future<void> uncheckHabit(String habitId);
  Future<Map<String, dynamic>> monthHabitGrid(String month);
  Future<PhotoReview> uploadMealPhoto({
    required String fileName,
    required List<int> bytes,
  });
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
  Future<PhotoReview> applyEatenPercentage(
    String detectedFoodId,
    double percentage,
  ) async =>
      photoReview('mock-analysis');
  Future<PhotoReview> splitPhotoFood(
    String detectedFoodId,
    List<Map<String, dynamic>> items,
  ) async =>
      photoReview('mock-analysis');
  Future<NutritionLabelReview> uploadNutritionLabel({
    required String fileName,
    required List<int> bytes,
  }) async =>
      const NutritionLabelReview(
        analysisId: 'mock-label',
        status: 'needs_review',
        imageUrl: '',
        productName: 'Sample protein bar',
        brand: 'Friends Beta',
        servingSize: '1 bar (50 g)',
        barcode: '',
        nutrients: {'calories': 210, 'protein_g': 20},
        ingredients: 'Sample ingredients',
        allergens: ['milk'],
        confidence: 0.84,
      );
  Future<NutritionLabelReview> nutritionLabelReview(String analysisId) =>
      uploadNutritionLabel(fileName: 'mock.jpg', bytes: const []);
  Future<FoodDetail> confirmNutritionLabel(
    String analysisId,
    Map<String, dynamic> payload,
  ) =>
      createCustomFood(payload);
  Future<Map<String, dynamic>> dailyTracking() async => const {
        'water_ml': 0,
        'water_target_ml': 2500,
        'steps': 0,
        'duration_minutes': 0,
        'calories_burned': 0,
        'activities': <dynamic>[],
      };
  Future<void> addWater(int amountMl) async {}
  Future<void> addActivity(Map<String, dynamic> payload) async {}
  Future<Map<String, dynamic>> reminderPreferences() async => const {};
  Future<void> updateReminderPreferences(Map<String, dynamic> payload) async {}
  Future<Map<String, dynamic>> weeklyBetaReport() async => const {};
  Future<List<Map<String, dynamic>>> friendGroups() async => const [];
  Future<Map<String, dynamic>> createFriendGroup(String name) async => const {};
  Future<Map<String, dynamic>> joinFriendGroup(String inviteCode) async =>
      const {};
  Future<Map<String, dynamic>> createGroupChallenge(
    String groupId,
    Map<String, dynamic> payload,
  ) async =>
      const {};
  Future<Map<String, dynamic>> checkGroupChallenge(
    String groupId,
    String challengeId,
    int count,
  ) async =>
      const {};
  Future<Map<String, dynamic>> addGroupGroceryItem(
    String groupId,
    Map<String, dynamic> payload,
  ) async =>
      const {};
  Future<Map<String, dynamic>> updateGroupGroceryItem(
    String itemId,
    Map<String, dynamic> payload,
  ) async =>
      const {};
  Future<List<Map<String, dynamic>>> recipes() async => const [];
  Future<Map<String, dynamic>> shareGroupRecipe(
    String groupId,
    String recipeId,
  ) async =>
      const {};
}

class ApiNutritionRepository implements NutritionRepository {
  ApiNutritionRepository(this._apiClient);

  final ApiClient _apiClient;
  final Map<String, List<FoodSummary>> _foodListCache = {};
  final Map<String, FoodDetail> _foodDetailCache = {};
  final Map<String, _FoodSearchCacheEntry> _foodSearchCache = {};
  CancelToken? _activeFoodSearch;

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
    final tracking = await dailyTracking();
    final meals = [
      for (final log in mealLogs)
        for (final item in log.items) item,
    ];
    final data = summary.data as Map<String, dynamic>;
    final targetProgress =
        data['daily_target_progress'] as Map<String, dynamic>? ?? {};
    final caloriesTarget =
        targetProgress['calories_kcal'] as Map<String, dynamic>? ?? {};
    double targetFor(String code) {
      final progress =
          targetProgress[code] as Map<String, dynamic>? ?? const {};
      return _asDouble(progress['target']);
    }

    final micronutrients = _doubleMap(data['micronutrients']);
    return DashboardSnapshot(
      consumedCalories: _asDouble(data['calories_kcal']),
      targetCalories: _asDouble(caloriesTarget['target'], fallback: 2000),
      proteinG: _asDouble(data['protein_g']),
      carbsG: _asDouble(data['carbs_g']),
      fatG: _asDouble(data['fat_g']),
      fiberG: _asDouble(data['fiber_g']),
      targetProteinG: targetFor('protein_g'),
      targetCarbsG: targetFor('carbs_g'),
      targetFatG: targetFor('fat_g'),
      targetFiberG: targetFor('fiber_g'),
      targetWaterMl: targetFor('water_ml'),
      sugarG: _asDouble(data['sugar_g']),
      sodiumMg: _asDouble(data['sodium_mg']),
      micronutrients: micronutrients,
      waterMl: _asDouble(tracking['water_ml']),
      waterCompleted: (_asDouble(tracking['water_ml']) / 250).round(),
      waterTarget: (_asDouble(
                tracking['water_target_ml'],
                fallback: 2500,
              ) /
              250)
          .round(),
      steps: _asDouble(tracking['steps']).round(),
      workoutMinutes: _asDouble(tracking['duration_minutes']).round(),
      exerciseCalories: _asDouble(tracking['calories_burned']),
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
  Future<ProgressReport> progressReport() async {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 6));
    final rangeSummary = await _apiClient.get(
      '/api/nutrition/range-summary/',
      queryParameters: {
        'start': _dateString(start),
        'end': _dateString(end),
      },
    );
    final bodyTrend = await bodyMetricTrend();
    final habitGrid = await monthHabitGrid(_monthKey(end));
    return ProgressReport.fromJson(
      rangeSummary: rangeSummary.data as Map<String, dynamic>,
      weightTrend: bodyTrend,
      habitMonthGrid: habitGrid,
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
  Future<NutritionTargetPlan> nutritionTargets() async {
    final response = await _apiClient.get('/api/nutrition/targets/');
    return NutritionTargetPlan.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<NutritionTargetPlan> estimateNutritionTargets() async {
    final response = await _apiClient.get('/api/nutrition/targets/estimate/');
    return NutritionTargetPlan.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<NutritionTargetPlan> applyEstimatedNutritionTargets() async {
    final response = await _apiClient.post(
      '/api/nutrition/targets/estimate/',
      data: {'confirm': true},
    );
    return NutritionTargetPlan.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<NutritionTargetPlan> updateNutritionTargets(
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.patch(
      '/api/nutrition/targets/',
      data: payload,
    );
    return NutritionTargetPlan.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<List<FoodSummary>> searchFoods(String query) async {
    final page = await searchFoodsAdvanced(FoodSearchRequest(query: query));
    return page.items;
  }

  @override
  Future<FoodSearchPage> searchFoodsAdvanced(FoodSearchRequest request) async {
    final key = request.cacheKey;
    final cached = _foodSearchCache[key];
    if (cached != null && cached.isFresh) return cached.page;
    _activeFoodSearch?.cancel('Replaced by a newer food search.');
    final cancelToken = CancelToken();
    _activeFoodSearch = cancelToken;
    try {
      final response = await _apiClient.get(
        '/api/foods/search/',
        queryParameters: request.queryParameters,
        cancelToken: cancelToken,
      );
      final data = response.data as Map<String, dynamic>;
      final page = FoodSearchPage.fromJson(data, page: request.page);
      _foodSearchCache[key] = _FoodSearchCacheEntry(page, DateTime.now());
      return page;
    } on ApiException {
      if (cached != null) return cached.page;
      rethrow;
    } finally {
      if (identical(_activeFoodSearch, cancelToken)) {
        _activeFoodSearch = null;
      }
    }
  }

  @override
  Future<List<FoodSummary>> recentFoods() => _foodList('/api/foods/recent/');

  @override
  Future<List<FoodSummary>> frequentFoods() =>
      _foodList('/api/foods/frequent/');

  @override
  Future<List<FoodSummary>> usualFoods(String mealType) async {
    final response = await _apiClient.get(
      '/api/foods/frequent/',
      queryParameters: {'meal_type': mealType},
    );
    return _extractList(response.data)
        .map((item) => FoodSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<FoodSummary>> favoriteFoods() =>
      _foodList('/api/foods/favorites/');

  @override
  Future<List<FoodSummary>> myFoods() => _foodList('/api/foods/my-foods/');

  Future<List<FoodSummary>> _foodList(String path) async {
    try {
      final response = await _apiClient.get(path);
      final foods = _extractList(response.data)
          .map((item) => FoodSummary.fromJson(item as Map<String, dynamic>))
          .toList();
      _foodListCache[path] = foods;
      return foods;
    } on ApiException {
      final cached = _foodListCache[path];
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<void> setFoodFavorite({
    required String foodId,
    required bool isFavorite,
  }) async {
    if (isFavorite) {
      await _apiClient.post('/api/foods/$foodId/favorite/');
    } else {
      await _apiClient.delete('/api/foods/$foodId/favorite/');
    }
  }

  @override
  Future<List<FoodSummary>> lookupBarcode(String barcode) async {
    final response = await _apiClient.get(
      '/api/foods/barcode-lookup/',
      queryParameters: {'barcode': barcode},
    );
    final data = response.data as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? const [];
    return results
        .map((item) => FoodSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<FoodDetail> foodDetail(String foodId) async {
    try {
      final response = await _apiClient.get('/api/foods/$foodId/');
      final food = FoodDetail.fromJson(response.data as Map<String, dynamic>);
      _foodDetailCache[foodId] = food;
      return food;
    } on ApiException {
      final cached = _foodDetailCache[foodId];
      if (cached != null) return cached;
      rethrow;
    }
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
  Future<void> copyYesterday(DateTime targetDate) async {
    await _apiClient.post(
      '/api/meals/copy-yesterday/',
      data: {'date': _dateString(targetDate)},
    );
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
  Future<void> updateMealItem({
    required String itemId,
    required String foodId,
    required double quantity,
    required String unit,
    double? totalGrams,
  }) async {
    await _apiClient.patch(
      '/api/meals/items/$itemId/',
      data: {
        'food': foodId,
        'quantity': quantity,
        'unit': _mealItemUnit(unit),
        if (totalGrams != null) 'grams_calculated': totalGrams,
      },
    );
  }

  @override
  Future<void> deleteMealItem(String itemId) async {
    await _apiClient.delete('/api/meals/items/$itemId/');
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
  Future<FoodDetail> createCustomFood(Map<String, dynamic> payload) async {
    final response = await _apiClient.post('/api/foods/custom/', data: payload);
    final food = FoodDetail.fromJson(response.data as Map<String, dynamic>);
    _foodDetailCache[food.id] = food;
    _foodListCache.clear();
    _foodSearchCache.clear();
    return food;
  }

  @override
  Future<List<FoodDetail>> customFoods() async {
    final response = await _apiClient.get(
      '/api/foods/custom/',
      queryParameters: {'page_size': 100},
    );
    return _extractList(response.data)
        .map((item) => FoodDetail.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CustomFoodEstimate> estimateCustomFood(
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post(
      '/api/foods/custom/estimate/',
      data: payload,
    );
    return CustomFoodEstimate.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<FoodDetail> customFoodDetail(String foodId) async {
    final response = await _apiClient.get('/api/foods/custom/$foodId/');
    return FoodDetail.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<FoodDetail> updateCustomFood(
    String foodId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.patch(
      '/api/foods/custom/$foodId/',
      data: payload,
    );
    final food = FoodDetail.fromJson(response.data as Map<String, dynamic>);
    _foodDetailCache[foodId] = food;
    _foodListCache.clear();
    _foodSearchCache.clear();
    return food;
  }

  @override
  Future<CustomFoodEstimate> reEstimateCustomFood(
    String foodId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post(
      '/api/foods/custom/$foodId/re-estimate/',
      data: payload,
    );
    _foodDetailCache.remove(foodId);
    return CustomFoodEstimate.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<FoodDetail> confirmCustomFood(
    String foodId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post(
      '/api/foods/custom/$foodId/confirm/',
      data: payload,
    );
    final food = FoodDetail.fromJson(response.data as Map<String, dynamic>);
    _foodDetailCache[foodId] = food;
    _foodListCache.clear();
    _foodSearchCache.clear();
    return food;
  }

  @override
  Future<List<Map<String, dynamic>>> customFoodHistory(String foodId) async {
    final response = await _apiClient.get(
      '/api/foods/custom/$foodId/history/',
    );
    return (response.data as List<dynamic>)
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }

  @override
  Future<void> logCustomFood(
    String foodId, {
    required String mealType,
    double quantity = 1,
    String unit = 'serving',
    double? totalGrams,
  }) async {
    await _apiClient.post(
      '/api/foods/custom/$foodId/log/',
      data: {
        'date': _dateString(DateTime.now()),
        'meal_type': mealType,
        'quantity_value': quantity,
        'quantity_unit': unit,
        if (totalGrams != null) 'total_grams': totalGrams,
      },
    );
  }

  @override
  Future<void> archiveCustomFood(String foodId) async {
    await updateCustomFood(foodId, {'status': 'archived'});
  }

  @override
  Future<Map<String, dynamic>> createRecipe(
      Map<String, dynamic> payload) async {
    final response = await _apiClient.post('/api/recipes/', data: payload);
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> calculateRecipe(String recipeId) async {
    final response = await _apiClient.post('/api/recipes/$recipeId/calculate/');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> logRecipeAsMeal({
    required String recipeId,
    required String mealType,
  }) async {
    await _apiClient.post(
      '/api/recipes/$recipeId/log-as-meal/',
      data: {
        'date': _dateString(DateTime.now()),
        'meal_type': mealType,
        'quantity': '1.000',
        'unit': 'serving',
      },
    );
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
  Future<List<HabitTemplateSummary>> habitTemplates() async {
    final response = await _apiClient.get('/api/habits/templates/');
    final data = _extractList(response.data);
    return data
        .map((item) =>
            HabitTemplateSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> createHabitFromTemplate(String templateId) async {
    await _apiClient.post(
      '/api/habits/create-from-template/',
      data: {
        'template_id': templateId,
        'start_date': _dateString(DateTime.now()),
      },
    );
  }

  @override
  Future<void> createHabit({
    required String title,
    required int targetCount,
    required String unit,
    required String category,
  }) async {
    await _apiClient.post(
      '/api/habits/',
      data: {
        'title': title,
        'category': category,
        'recurrence': 'daily',
        'recurrence_type': 'daily',
        'start_date': _dateString(DateTime.now()),
        'target_count': targetCount,
        'unit': unit,
        'icon': _habitIconForCategory(category),
        'color': _habitColorForCategory(category),
        'is_active': true,
      },
    );
  }

  @override
  Future<void> checkHabit(
    String habitId,
    int completedCount, {
    bool isCompleted = true,
  }) async {
    await _apiClient.post(
      '/api/habits/$habitId/check/',
      data: {
        'date': _dateString(DateTime.now()),
        'completed_count': completedCount,
        'is_completed': isCompleted,
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
  Future<PhotoReview> uploadMealPhoto({
    required String fileName,
    required List<int> bytes,
  }) async {
    final response = await _apiClient.uploadBytes(
      '/api/photos/analyze-meal/',
      fieldName: 'image',
      fileName: fileName,
      bytes: bytes,
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

  @override
  Future<PhotoReview> applyEatenPercentage(
    String detectedFoodId,
    double percentage,
  ) async {
    final response = await _apiClient.post(
      '/api/photos/detected-foods/$detectedFoodId/eaten-percentage/',
      data: {'eaten_percentage': percentage},
    );
    return PhotoReview.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PhotoReview> splitPhotoFood(
    String detectedFoodId,
    List<Map<String, dynamic>> items,
  ) async {
    final response = await _apiClient.post(
      '/api/photos/detected-foods/$detectedFoodId/split/',
      data: {'items': items},
    );
    return PhotoReview.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<NutritionLabelReview> uploadNutritionLabel({
    required String fileName,
    required List<int> bytes,
  }) async {
    final response = await _apiClient.uploadBytes(
      '/api/photos/analyze-label/',
      fieldName: 'image',
      fileName: fileName,
      bytes: bytes,
    );
    final data = response.data as Map<String, dynamic>;
    final id = data['id']?.toString() ?? '';
    if (id.isEmpty) return NutritionLabelReview.fromJson(data);
    return _pollLabelReview(id);
  }

  @override
  Future<NutritionLabelReview> nutritionLabelReview(String analysisId) async {
    final response = await _apiClient.get('/api/photos/analyses/$analysisId/');
    return NutritionLabelReview.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<NutritionLabelReview> _pollLabelReview(String analysisId) async {
    var review = await nutritionLabelReview(analysisId);
    for (var attempt = 0; attempt < 8 && review.isProcessing; attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      review = await nutritionLabelReview(analysisId);
    }
    return review;
  }

  @override
  Future<FoodDetail> confirmNutritionLabel(
    String analysisId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post(
      '/api/photos/analyses/$analysisId/confirm-label-as-food/',
      data: payload,
    );
    final data = response.data as Map<String, dynamic>;
    return FoodDetail.fromJson(data['food'] as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> dailyTracking() async {
    final response = await _apiClient.get('/api/tracking/today/');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> addWater(int amountMl) async {
    await _apiClient.post(
      '/api/tracking/water/',
      data: {'amount_ml': amountMl, 'entry_date': _dateString(DateTime.now())},
    );
  }

  @override
  Future<void> addActivity(Map<String, dynamic> payload) async {
    await _apiClient.post(
      '/api/tracking/activities/',
      data: {'activity_date': _dateString(DateTime.now()), ...payload},
    );
  }

  @override
  Future<Map<String, dynamic>> reminderPreferences() async {
    final response = await _apiClient.get('/api/tracking/reminders/');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<void> updateReminderPreferences(Map<String, dynamic> payload) async {
    await _apiClient.patch('/api/tracking/reminders/', data: payload);
  }

  @override
  Future<Map<String, dynamic>> weeklyBetaReport() async {
    final response = await _apiClient.get('/api/analytics/weekly-report/');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> friendGroups() async {
    final response = await _apiClient.get('/api/community/groups/');
    return (response.data as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> createFriendGroup(String name) async {
    final response = await _apiClient.post(
      '/api/community/groups/',
      data: {'name': name},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<Map<String, dynamic>> joinFriendGroup(String inviteCode) async {
    final response = await _apiClient.post(
      '/api/community/groups/join/',
      data: {'invite_code': inviteCode},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<Map<String, dynamic>> createGroupChallenge(
    String groupId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post(
      '/api/community/groups/$groupId/challenge/',
      data: payload,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<Map<String, dynamic>> checkGroupChallenge(
    String groupId,
    String challengeId,
    int count,
  ) async {
    final response = await _apiClient.post(
      '/api/community/groups/$groupId/challenge/$challengeId/check/',
      data: {'completed_count': count},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<Map<String, dynamic>> addGroupGroceryItem(
    String groupId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post(
      '/api/community/groups/$groupId/grocery/',
      data: payload,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<Map<String, dynamic>> updateGroupGroceryItem(
    String itemId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.patch(
      '/api/community/grocery-items/$itemId/',
      data: payload,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> recipes() async {
    final response = await _apiClient.get('/api/recipes/');
    return _extractList(response.data)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> shareGroupRecipe(
    String groupId,
    String recipeId,
  ) async {
    final response = await _apiClient.post(
      '/api/community/groups/$groupId/recipes/',
      data: {'recipe_id': recipeId},
    );
    return Map<String, dynamic>.from(response.data as Map);
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

Map<String, double> _doubleMap(Object? value) {
  if (value is! Map<String, dynamic>) return const {};
  return {
    for (final entry in value.entries) entry.key: _asDouble(entry.value),
  };
}

String _dateString(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _monthKey(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  return '${local.year}-$month';
}

String _mealItemUnit(String unit) {
  if (unit == 'gram') return 'grams';
  if (unit == 'bowl' || unit == 'egg' || unit == 'slice' || unit == 'scoop') {
    return 'serving';
  }
  return unit;
}

String _habitIconForCategory(String category) {
  return switch (category) {
    'water' => 'droplets',
    'nutrition' => 'utensils',
    'workout' => 'dumbbell',
    'sleep' => 'moon',
    'study' => 'book',
    'productivity' => 'check',
    _ => 'check',
  };
}

String _habitColorForCategory(String category) {
  return switch (category) {
    'water' => '#0EA5E9',
    'nutrition' => '#22C55E',
    'workout' => '#F97316',
    'sleep' => '#8B5CF6',
    'study' => '#3B82F6',
    'productivity' => '#FACC15',
    _ => '#22C55E',
  };
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

double _mockServingGrams(String foodId) {
  switch (foodId) {
    case 'egg':
      return 50;
    case 'banana':
      return 118;
    case 'chapati':
      return 45;
    default:
      return 100;
  }
}

class MockNutritionRepository extends NutritionRepository {
  static const _foods = [
    FoodSummary(
      id: 'egg',
      name: 'Egg, whole, boiled',
      brand: '',
      sourceBadge: 'IFCT_2017',
      confidenceScore: 0.95,
      dataClassification: 'official_verified',
      verified: true,
      isFavorite: true,
      preview: MacroPreview(
        caloriesKcal: 155,
        proteinG: 12.6,
        carbsG: 1.1,
        fatG: 10.6,
        sodiumMg: 124,
        cholesterolMg: 373,
        saturatedFatG: 3.3,
      ),
    ),
    FoodSummary(
      id: 'chicken-breast',
      name: 'Chicken breast, cooked, skinless',
      brand: '',
      sourceBadge: 'USDA_FDC',
      confidenceScore: 0.96,
      dataClassification: 'official_verified',
      verified: true,
      preview: MacroPreview(
        caloriesKcal: 165,
        proteinG: 31,
        carbsG: 0,
        fatG: 3.6,
        sodiumMg: 74,
        cholesterolMg: 85,
        saturatedFatG: 1,
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
        fiberG: 0.4,
        sugarG: 0.1,
        sodiumMg: 1,
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
        fiberG: 5,
        sugarG: 1.8,
        sodiumMg: 240,
      ),
    ),
    FoodSummary(
      id: 'banana',
      name: 'Banana',
      brand: '',
      sourceBadge: 'USDA_FDC',
      confidenceScore: 0.93,
      dataClassification: 'official_verified',
      verified: true,
      preview: MacroPreview(
        caloriesKcal: 89,
        proteinG: 1.1,
        carbsG: 22.8,
        fatG: 0.3,
        fiberG: 2.6,
        sugarG: 12.2,
        potassiumMg: 358,
      ),
    ),
    FoodSummary(
      id: 'chapati',
      name: 'Whole wheat chapati',
      brand: 'Home style',
      sourceBadge: 'IFCT_2017',
      confidenceScore: 0.88,
      dataClassification: 'official_verified',
      verified: true,
      preview: MacroPreview(
        caloriesKcal: 260,
        proteinG: 8.7,
        carbsG: 46.4,
        fatG: 4.5,
        fiberG: 6.7,
        sugarG: 1.7,
        sodiumMg: 300,
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
      fiberG: 24,
      targetProteinG: 115,
      targetCarbsG: 270,
      targetFatG: 70,
      targetFiberG: 30,
      targetWaterMl: 2600,
      sugarG: 34,
      sodiumMg: 1180,
      micronutrients: const {
        'calcium_mg': 620,
        'iron_mg': 11,
        'potassium_mg': 2450,
        'cholesterol_mg': 210,
      },
      waterCompleted: 5,
      waterTarget: 8,
      meals: const [
        MealItemSummary(
          id: 'mock-breakfast-egg',
          foodId: 'egg',
          foodName: 'Egg bhurji and toast',
          mealType: 'breakfast',
          caloriesKcal: 420,
          proteinG: 24,
          carbsG: 30,
          fatG: 22,
          fiberG: 4,
          sugarG: 5,
          sodiumMg: 410,
        ),
        MealItemSummary(
          id: 'mock-lunch-dal',
          foodId: 'dal',
          foodName: 'Dal rice bowl',
          mealType: 'lunch',
          caloriesKcal: 610,
          proteinG: 26,
          carbsG: 82,
          fatG: 18,
          fiberG: 11,
          sugarG: 7,
          sodiumMg: 520,
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
  Future<ProgressReport> progressReport() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return ProgressReport.fromJson(
      rangeSummary: {
        'start': '2026-06-24',
        'end': '2026-06-30',
        'days': const [
          {
            'date': '2026-06-24',
            'calories_kcal': 1820,
            'protein_g': 92,
            'carbs_g': 210,
            'fat_g': 54,
            'fiber_g': 22,
            'sugar_g': 36,
            'sodium_mg': 1320,
          },
          {
            'date': '2026-06-25',
            'calories_kcal': 1985,
            'protein_g': 108,
            'carbs_g': 222,
            'fat_g': 62,
            'fiber_g': 25,
            'sugar_g': 42,
            'sodium_mg': 1480,
          },
          {
            'date': '2026-06-26',
            'calories_kcal': 1740,
            'protein_g': 88,
            'carbs_g': 188,
            'fat_g': 58,
            'fiber_g': 19,
            'sugar_g': 31,
            'sodium_mg': 1180,
          },
          {
            'date': '2026-06-27',
            'calories_kcal': 2120,
            'protein_g': 116,
            'carbs_g': 246,
            'fat_g': 64,
            'fiber_g': 28,
            'sugar_g': 45,
            'sodium_mg': 1650,
          },
          {
            'date': '2026-06-28',
            'calories_kcal': 1650,
            'protein_g': 82,
            'carbs_g': 180,
            'fat_g': 50,
            'fiber_g': 21,
            'sugar_g': 28,
            'sodium_mg': 1100,
          },
          {
            'date': '2026-06-29',
            'calories_kcal': 1900,
            'protein_g': 104,
            'carbs_g': 198,
            'fat_g': 61,
            'fiber_g': 26,
            'sugar_g': 34,
            'sodium_mg': 1260,
          },
          {
            'date': '2026-06-30',
            'calories_kcal': 1420,
            'protein_g': 96,
            'carbs_g': 168,
            'fat_g': 48,
            'fiber_g': 24,
            'sugar_g': 34,
            'sodium_mg': 1180,
          },
        ],
        'totals': const {
          'calories_kcal': 12635,
          'protein_g': 686,
          'carbs_g': 1412,
          'fat_g': 397,
          'fiber_g': 165,
          'sugar_g': 250,
          'sodium_mg': 9170,
        },
        'averages': const {
          'calories_kcal': 1805,
          'protein_g': 98,
          'carbs_g': 202,
          'fat_g': 56.7,
          'fiber_g': 23.5,
          'sugar_g': 35.7,
          'sodium_mg': 1310,
        },
      },
      weightTrend: const BodyMetricTrend(
        weights: [74.2, 74.0, 73.9, 73.4, 73.2, 73.0, 72.8],
        latestWeightKg: 72.8,
        changeKg: -1.4,
      ),
      habitMonthGrid: {
        'month': '2026-06',
        'days': [
          for (var day = 24; day <= 30; day += 1)
            {
              'date': '2026-06-${day.toString().padLeft(2, '0')}',
              'items': [
                {'title': 'Drink water', 'is_completed': day != 28},
                {'title': 'Log meals', 'is_completed': day >= 25},
                {'title': 'Walk 8,000 steps', 'is_completed': day.isEven},
              ],
            },
        ],
      },
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
  Future<NutritionTargetPlan> nutritionTargets() async {
    return _mockNutritionTargetPlan();
  }

  @override
  Future<NutritionTargetPlan> estimateNutritionTargets() async {
    return _mockNutritionTargetPlan(requiresConfirmation: true);
  }

  @override
  Future<NutritionTargetPlan> applyEstimatedNutritionTargets() async {
    return _mockNutritionTargetPlan();
  }

  @override
  Future<NutritionTargetPlan> updateNutritionTargets(
    Map<String, dynamic> payload,
  ) async {
    return NutritionTargetPlan(
      caloriesKcal: _asDouble(payload['calories_kcal'], fallback: 2200),
      proteinG: _asDouble(payload['protein_g'], fallback: 115),
      carbsG: _asDouble(payload['carbs_g'], fallback: 270),
      fatG: _asDouble(payload['fat_g'], fallback: 70),
      fiberG: _asDouble(payload['fiber_g'], fallback: 30),
      waterMl: _asDouble(payload['water_ml'], fallback: 2600),
      method: 'user_custom',
      disclaimer: 'Editable wellness estimates, not medical advice.',
      customized: true,
    );
  }

  @override
  Future<List<FoodSummary>> searchFoods(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final normalized = query.toLowerCase();
    if (normalized.trim().isEmpty) return _foods;
    return _foods
        .where((food) => food.name.toLowerCase().contains(normalized))
        .toList();
  }

  @override
  Future<FoodSearchPage> searchFoodsAdvanced(FoodSearchRequest request) async {
    var foods = await searchFoods(request.query);
    if (request.foodType.isNotEmpty) {
      foods = foods.where((food) {
        if (request.foodType == 'custom') {
          return food.dataClassification == 'user_custom';
        }
        return request.foodType == 'branded'
            ? food.brand.isNotEmpty
            : food.dataClassification != 'user_custom' && food.brand.isEmpty;
      }).toList();
    }
    if (request.verified != null) {
      foods = foods.where((food) => food.verified == request.verified).toList();
    }
    if (request.preparationState.isNotEmpty) {
      foods = foods
          .where(
            (food) => food.preparationState == request.preparationState,
          )
          .toList();
    }
    final start = (request.page - 1) * request.pageSize;
    final items = start >= foods.length
        ? const <FoodSummary>[]
        : foods.skip(start).take(request.pageSize).toList();
    return FoodSearchPage(
      items: items,
      count: foods.length,
      page: request.page,
      hasMore: start + items.length < foods.length,
    );
  }

  @override
  Future<List<FoodSummary>> recentFoods() async {
    return _foods.take(4).toList();
  }

  @override
  Future<List<FoodSummary>> frequentFoods() async {
    return _foods.take(5).toList();
  }

  @override
  Future<List<FoodSummary>> usualFoods(String mealType) async {
    return _foods.take(3).toList();
  }

  @override
  Future<List<FoodSummary>> favoriteFoods() async {
    return _foods.where((food) => food.isFavorite).toList();
  }

  @override
  Future<List<FoodSummary>> myFoods() async {
    return _foods
        .where((food) => food.dataClassification == 'user_custom')
        .toList();
  }

  @override
  Future<void> setFoodFavorite({
    required String foodId,
    required bool isFavorite,
  }) async {}

  @override
  Future<List<FoodSummary>> lookupBarcode(String barcode) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _foods.take(1).toList();
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
      defaultServingG: _mockServingGrams(food.id),
      servings: [
        FoodServingOption(
          id: 'default',
          name: '1 serving',
          grams: _mockServingGrams(food.id),
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
        FoodNutrientValue(
          code: 'fiber_g',
          name: 'Fiber',
          unit: 'g',
          amountPer100g: food.preview.fiberG,
        ),
        FoodNutrientValue(
          code: 'sugar_g',
          name: 'Sugar',
          unit: 'g',
          amountPer100g: food.preview.sugarG,
        ),
        FoodNutrientValue(
          code: 'sodium_mg',
          name: 'Sodium',
          unit: 'mg',
          amountPer100g: food.preview.sodiumMg,
        ),
        FoodNutrientValue(
          code: 'calcium_mg',
          name: 'Calcium',
          unit: 'mg',
          amountPer100g: food.preview.calciumMg,
        ),
        FoodNutrientValue(
          code: 'iron_mg',
          name: 'Iron',
          unit: 'mg',
          amountPer100g: food.preview.ironMg,
        ),
        FoodNutrientValue(
          code: 'potassium_mg',
          name: 'Potassium',
          unit: 'mg',
          amountPer100g: food.preview.potassiumMg,
        ),
        FoodNutrientValue(
          code: 'cholesterol_mg',
          name: 'Cholesterol',
          unit: 'mg',
          amountPer100g: food.preview.cholesterolMg,
        ),
        FoodNutrientValue(
          code: 'saturated_fat_g',
          name: 'Saturated fat',
          unit: 'g',
          amountPer100g: food.preview.saturatedFatG,
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
            id: 'mock-log-egg',
            foodId: 'egg',
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
  Future<void> copyYesterday(DateTime targetDate) async {}

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
  }) async {}

  @override
  Future<void> updateMealItem({
    required String itemId,
    required String foodId,
    required double quantity,
    required String unit,
    double? totalGrams,
  }) async {}

  @override
  Future<void> deleteMealItem(String itemId) async {}

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
  Future<FoodDetail> createCustomFood(Map<String, dynamic> payload) async {
    return FoodDetail(
      id: 'custom-food',
      name: payload['name']?.toString() ?? 'Custom food',
      brand: payload['brand']?.toString() ?? '',
      description: payload['notes']?.toString() ?? '',
      sourceBadge: 'USER_CUSTOM',
      confidenceScore: 0.5,
      dataClassification: 'user_custom',
      verified: false,
      defaultServingG: _asDouble(payload['serving_grams'], fallback: 100),
      servings: [
        FoodServingOption(
          id: 'custom-serving',
          name: payload['serving_name']?.toString() ?? '1 serving',
          grams: _asDouble(payload['serving_grams'], fallback: 100),
          isDefault: true,
        ),
      ],
      nutrients: const [],
      isFavorite: false,
    );
  }

  @override
  Future<List<FoodDetail>> customFoods() async {
    final foods = await myFoods();
    return Future.wait(foods.map((food) => foodDetail(food.id)));
  }

  @override
  Future<CustomFoodEstimate> estimateCustomFood(
    Map<String, dynamic> payload,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final grams = _asDouble(payload['serving_weight_g'], fallback: 100);
    final scale = grams / 100;
    return CustomFoodEstimate.fromJson({
      'normalized_food_name': payload['food_name'] ?? 'custom food',
      'suggested_nutrients': {
        'calories_kcal': 180 * scale,
        'protein_g': 12 * scale,
        'carbs_g': 22 * scale,
        'fat_g': 6 * scale,
        'fiber_g': 3 * scale,
        'sugar_g': 4 * scale,
        'sodium_mg': 140 * scale,
      },
      'estimated_range': {
        'calories_kcal': {
          'min': 160 * scale,
          'likely': 180 * scale,
          'max': 210 * scale,
        },
      },
      'reference_matches': [
        {
          'food_id': 'mock-reference',
          'name': 'Similar trusted food',
          'preparation_state': payload['preparation_method'] ?? 'prepared',
          'source': {
            'name': 'USDA FoodData Central',
            'source_type': 'USDA_FDC',
          },
          'source_badge': 'USDA_FDC',
          'name_match_score': 0.88,
        },
      ],
      'source_badges': ['USDA_FDC'],
      'confidence': 0.82,
      'warnings': <String>[],
      'can_estimate': true,
      'requires_review': true,
      'message': 'Review and edit every value before confirming.',
      'calculated_calories_from_macros': 190 * scale,
      'accuracy_notice':
          'This is a database-based estimate, not a laboratory measurement.',
      'estimation_method': 'database_matches',
    });
  }

  @override
  Future<FoodDetail> customFoodDetail(String foodId) async {
    try {
      return await foodDetail(foodId);
    } catch (_) {
      return createCustomFood({
        'name': 'Mock custom food',
        'serving_name': '1 serving',
        'serving_grams': 100,
      });
    }
  }

  @override
  Future<FoodDetail> updateCustomFood(
    String foodId,
    Map<String, dynamic> payload,
  ) {
    return customFoodDetail(foodId);
  }

  @override
  Future<CustomFoodEstimate> reEstimateCustomFood(
    String foodId,
    Map<String, dynamic> payload,
  ) {
    return estimateCustomFood({
      'food_name': payload['food_name'] ?? 'Mock custom food',
      'serving_weight_g': payload['serving_weight_g'] ?? 100,
      ...payload,
    });
  }

  @override
  Future<FoodDetail> confirmCustomFood(
    String foodId,
    Map<String, dynamic> payload,
  ) {
    return customFoodDetail(foodId);
  }

  @override
  Future<List<Map<String, dynamic>>> customFoodHistory(String foodId) async {
    return const [
      {'version': 1, 'event': 'created', 'status': 'confirmed'},
    ];
  }

  @override
  Future<void> logCustomFood(
    String foodId, {
    required String mealType,
    double quantity = 1,
    String unit = 'serving',
    double? totalGrams,
  }) async {}

  @override
  Future<void> archiveCustomFood(String foodId) async {}

  @override
  Future<Map<String, dynamic>> createRecipe(
      Map<String, dynamic> payload) async {
    return {
      'id': 'mock-recipe',
      'name': payload['name']?.toString() ?? 'Mock recipe',
    };
  }

  @override
  Future<Map<String, dynamic>> calculateRecipe(String recipeId) async {
    return {
      'recipe_id': recipeId,
      'per_serving': {
        'calories': 420,
        'protein_g': 31,
        'carbs_g': 42,
        'fat_g': 14,
      },
      'total_weight_g': 350,
      'ingredients': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<void> logRecipeAsMeal({
    required String recipeId,
    required String mealType,
  }) async {}

  @override
  Future<List<HabitGridItem>> todayHabits() async => (await dashboard()).habits;

  @override
  Future<List<HabitTemplateSummary>> habitTemplates() async {
    return const [
      HabitTemplateSummary(
        id: 'water-template',
        title: 'Drink 8 glasses water',
        description: 'Track your daily water intake.',
        category: 'water',
        defaultTargetCount: 8,
        unit: 'glasses',
        icon: 'droplets',
      ),
      HabitTemplateSummary(
        id: 'meals-template',
        title: 'Log all meals',
        description: 'Keep breakfast, lunch, dinner, and snacks complete.',
        category: 'nutrition',
        defaultTargetCount: 1,
        unit: 'checkbox',
        icon: 'utensils',
      ),
      HabitTemplateSummary(
        id: 'steps-template',
        title: 'Walk 8,000 steps',
        description: 'Build an active daily baseline.',
        category: 'workout',
        defaultTargetCount: 8000,
        unit: 'steps',
        icon: 'footprints',
      ),
      HabitTemplateSummary(
        id: 'workout-template',
        title: 'Workout',
        description: 'Complete your planned workout.',
        category: 'workout',
        defaultTargetCount: 1,
        unit: 'checkbox',
        icon: 'dumbbell',
      ),
    ];
  }

  @override
  Future<void> createHabitFromTemplate(String templateId) async {}

  @override
  Future<void> createHabit({
    required String title,
    required int targetCount,
    required String unit,
    required String category,
  }) async {}

  @override
  Future<void> checkHabit(
    String habitId,
    int completedCount, {
    bool isCompleted = true,
  }) async {}

  @override
  Future<void> uncheckHabit(String habitId) async {}

  @override
  Future<Map<String, dynamic>> monthHabitGrid(String month) async {
    return {'month': month, 'days': <Map<String, dynamic>>[], 'stats': {}};
  }

  @override
  Future<PhotoReview> uploadMealPhoto({
    required String fileName,
    required List<int> bytes,
  }) async {
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
          detectedName: 'boiled egg',
          matchedFoodName: 'Egg, whole, boiled',
          matchedFoodId: 'egg',
          quantity: 5,
          unit: 'egg',
          grams: 250,
          gramsPerUnit: 50,
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
  Future<PhotoReview> photoReview(String analysisId) =>
      uploadMealPhoto(fileName: 'mock-meal.jpg', bytes: const []);

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
          detectedName: 'boiled egg',
          matchedFoodName: 'Egg, whole, boiled',
          matchedFoodId: 'egg',
          quantity: 6,
          unit: 'egg',
          grams: 300,
          gramsPerUnit: 50,
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
      uploadMealPhoto(fileName: 'mock-meal.jpg', bytes: const []);

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
      uploadMealPhoto(fileName: 'mock-meal.jpg', bytes: const []);

  @override
  Future<PhotoReview> addManualPhotoFood({
    required String analysisId,
    required String foodId,
    double? quantity,
    String? unit,
    double? totalGrams,
  }) =>
      uploadMealPhoto(fileName: 'mock-meal.jpg', bytes: const []);

  @override
  Future<void> confirmPhotoMeal(String analysisId, String mealType) async {}
}

NutritionTargetPlan _mockNutritionTargetPlan({
  bool requiresConfirmation = false,
}) {
  return NutritionTargetPlan(
    caloriesKcal: 2200,
    proteinG: 115,
    carbsG: 270,
    fatG: 70,
    fiberG: 30,
    waterMl: 2600,
    method: 'mifflin_st_jeor_wellness_estimate',
    disclaimer: 'Editable wellness estimates, not medical advice.',
    assumptions: const [
      'Activity and goal selections influence the calorie estimate.',
    ],
    requiresConfirmation: requiresConfirmation,
  );
}
