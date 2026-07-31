import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';

final dashboardProvider = FutureProvider<DashboardSnapshot>((ref) async {
  return ref.watch(nutritionRepositoryProvider).dashboard();
});

final progressReportProvider = FutureProvider<ProgressReport>((ref) async {
  return ref.watch(nutritionRepositoryProvider).progressReport();
});

final weeklyBetaReportProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(nutritionRepositoryProvider).weeklyBetaReport();
});

final nutritionTargetsProvider =
    FutureProvider<NutritionTargetPlan>((ref) async {
  return ref.watch(nutritionRepositoryProvider).nutritionTargets();
});

final foodSearchProvider =
    FutureProvider.family<List<FoodSummary>, String>((ref, query) async {
  if (query.trim().isEmpty) return const [];
  return ref.watch(nutritionRepositoryProvider).searchFoods(query.trim());
});

final recentFoodsProvider = FutureProvider<List<FoodSummary>>((ref) async {
  return ref.watch(nutritionRepositoryProvider).recentFoods();
});

final frequentFoodsProvider = FutureProvider<List<FoodSummary>>((ref) async {
  return ref.watch(nutritionRepositoryProvider).frequentFoods();
});

final usualFoodsProvider =
    FutureProvider.family<List<FoodSummary>, String>((ref, mealType) async {
  return ref.watch(nutritionRepositoryProvider).usualFoods(mealType);
});

final favoriteFoodsProvider = FutureProvider<List<FoodSummary>>((ref) async {
  return ref.watch(nutritionRepositoryProvider).favoriteFoods();
});

final myFoodsProvider = FutureProvider<List<FoodSummary>>((ref) async {
  return ref.watch(nutritionRepositoryProvider).myFoods();
});

final foodDetailProvider =
    FutureProvider.family<FoodDetail, String>((ref, foodId) async {
  return ref.watch(nutritionRepositoryProvider).foodDetail(foodId);
});

final todayMealLogsProvider = FutureProvider<List<MealLogSummary>>((ref) async {
  return ref.watch(nutritionRepositoryProvider).mealsForDate(todayDate());
});

final todayHabitsProvider = FutureProvider<List<HabitGridItem>>((ref) async {
  return ref.watch(nutritionRepositoryProvider).todayHabits();
});

final habitTemplatesProvider =
    FutureProvider<List<HabitTemplateSummary>>((ref) async {
  return ref.watch(nutritionRepositoryProvider).habitTemplates();
});

final habitMonthGridProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, month) async {
  return ref.watch(nutritionRepositoryProvider).monthHabitGrid(month);
});

DateTime todayDate() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String currentMonthKey() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  return '${now.year}-$month';
}
