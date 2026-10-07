import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrinova_ai/src/core/models/app_models.dart';
import 'package:nutrinova_ai/src/core/repositories/nutrition_repository.dart';
import 'package:nutrinova_ai/src/core/repositories/providers.dart';
import 'package:nutrinova_ai/src/core/theme/nova_theme.dart';
import 'package:nutrinova_ai/src/features/habits/habit_grid_screen.dart';
import 'package:nutrinova_ai/src/features/meals/meal_log_screen.dart';
import 'package:nutrinova_ai/src/features/photos/photo_review_screen.dart';
import 'package:nutrinova_ai/src/features/foods/food_search_screen.dart';
import 'package:nutrinova_ai/src/features/foods/create_custom_food_screen.dart';
import 'package:nutrinova_ai/src/features/meals/quick_add_screen.dart';

const snapshot = DashboardSnapshot(
  consumedCalories: 600,
  targetCalories: 2000,
  proteinG: 30,
  carbsG: 60,
  fatG: 20,
  waterCompleted: 0,
  waterTarget: 8,
  meals: [],
  habits: [],
  weightTrend: [],
  latestWeightKg: null,
  weightChangeKg: null,
  insight: '',
  exerciseCalories: 250,
);

class StatefulTestRepository extends MockNutritionRepository {
  final habits = <Map<String, dynamic>>[];
  int dashboardCalls = 0;
  int photoCalls = 0;
  Map<String, dynamic>? loggedFood;
  Map<String, dynamic>? quickConfirmation;

  @override
  Future<FoodSearchPage> searchFoodsAdvanced(FoodSearchRequest request) async =>
      FoodSearchPage(items: [
        FoodSummary.fromJson({
          'id': 'egg',
          'name': 'Boiled egg',
          'default_serving': {'description': '1 egg', 'grams': 50},
          'nutrition_per_100g': {'calories': 155, 'protein_g': 12.6},
        })
      ], count: 1, page: 1, hasMore: false);

  @override
  Future<void> addManualFood(
      {required String foodId,
      required double quantity,
      required String unit,
      required String mealType,
      double? totalGrams}) async {
    loggedFood = {
      'id': foodId,
      'quantity': quantity,
      'unit': unit,
      'meal': mealType
    };
  }

  @override
  Future<void> confirmQuickAdd(Map<String, dynamic> payload) async {
    quickConfirmation = payload;
  }

  @override
  Future<DashboardSnapshot> dashboard() async {
    dashboardCalls += 1;
    return snapshot;
  }

  @override
  Future<List<MealLogSummary>> mealsForDate(DateTime date) async => [];

  @override
  Future<List<HabitGridItem>> todayHabits() async =>
      habits.map(HabitGridItem.fromJson).toList();

  @override
  Future<void> createHabit({
    required String title,
    required int targetCount,
    required String unit,
    required String category,
  }) async {
    habits.add({
      'habit_id': 'habit-${habits.length}',
      'title': title,
      'unit': unit,
      'target_count': targetCount,
      'completed_count': 0,
      'is_completed': false,
    });
  }

  @override
  Future<void> createHabitFromTemplate(String templateId) async {
    final template =
        (await habitTemplates()).singleWhere((item) => item.id == templateId);
    await createHabit(
      title: template.title,
      targetCount: template.defaultTargetCount,
      unit: template.unit,
      category: template.category,
    );
  }

  @override
  Future<void> checkHabit(String habitId, int completedCount,
      {bool isCompleted = true}) async {
    final habit = habits.singleWhere((item) => item['habit_id'] == habitId);
    habit['completed_count'] = completedCount;
    habit['is_completed'] = isCompleted;
  }

  @override
  Future<void> uncheckHabit(String habitId) =>
      checkHabit(habitId, 0, isCompleted: false);

  @override
  Future<PhotoReview> photoReview(String analysisId) async {
    photoCalls += 1;
    return PhotoReview(
      analysisId: analysisId,
      status: photoCalls == 1 ? 'processing' : 'needs_review',
      imageUrl: '',
      disclaimer: 'Review portions before saving.',
      items: const [],
      totalPreview:
          const MacroPreview(caloriesKcal: 0, proteinG: 0, carbsG: 0, fatG: 0),
      warnings: const [],
    );
  }
}

Future<void> showScreen(WidgetTester tester, Widget screen,
    StatefulTestRepository repository) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => screen),
      GoRoute(path: '/meals', builder: (_, __) => const MealLogScreen()),
      GoRoute(
          path: '/foods/custom',
          builder: (_, state) => CreateCustomFoodScreen(
                initialMealType:
                    state.uri.queryParameters['meal_type'] ?? 'lunch',
              )),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [nutritionRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(
      theme: NovaTheme.dark(),
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('custom checklist can be created, checked and unchecked on phone',
      (tester) async {
    final repository = StatefulTestRepository();
    await showScreen(tester, const HabitGridScreen(), repository);
    expect(find.text('No active habits'), findsOneWidget);
    await tester.tap(find.byTooltip('Add habit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Read before bed');
    await tester.tap(find.text('Add to checklist'));
    await tester.pumpAndSettle();
    expect(repository.habits.single['title'], 'Read before bed');
    expect(find.text('Read before bed'), findsOneWidget);
    final checkbox = find.byType(Checkbox).first;
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(repository.habits.single['is_completed'], isTrue);
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(repository.habits.single['is_completed'], isFalse);
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a checklist template creates a usable habit', (tester) async {
    final repository = StatefulTestRepository();
    await showScreen(tester, const HabitGridScreen(), repository);
    await tester.scrollUntilVisible(find.text('Log all meals'), 200,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(find.text('Log all meals')),
        alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log all meals'));
    await tester.pumpAndSettle();
    expect(repository.habits.single['title'], 'Log all meals');
    expect(repository.habits.single['target_count'], 1);
    await tester.drag(find.byType(ListView).first, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one-tap add uses the selected meal and the food serving',
      (tester) async {
    final repository = StatefulTestRepository();
    await showScreen(
        tester, const FoodSearchScreen(initialMealType: 'dinner'), repository);
    await tester.enterText(find.byType(TextField).first, 'egg');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    final add = find.widgetWithText(FilledButton, 'Add').first;
    await Scrollable.ensureVisible(tester.element(add), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(repository.loggedFood,
        {'id': 'egg', 'quantity': 1.0, 'unit': 'serving', 'meal': 'dinner'});
    expect(find.text('Added 1 egg Boiled egg to Dinner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom food action opens the creation screen', (tester) async {
    await showScreen(tester, const FoodSearchScreen(initialMealType: 'dinner'),
        StatefulTestRepository());
    await tester.tap(find.byTooltip('Create custom food'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateCustomFoodScreen), findsOneWidget);
    final screen = tester
        .widget<CreateCustomFoodScreen>(find.byType(CreateCustomFoodScreen));
    expect(screen.initialMealType, 'dinner');
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick add reviews and saves to the selected meal',
      (tester) async {
    final repository = StatefulTestRepository();
    await showScreen(
        tester, const QuickAddScreen(initialMealType: 'dinner'), repository);
    await tester.enterText(find.byType(TextField).first, '2 eggs');
    await tester.pump();
    await tester.tap(find.text('Parse food'));
    await tester.pumpAndSettle();
    final confirm = find.text('Confirm and save to Dinner');
    await tester.scrollUntilVisible(confirm, 200,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(confirm), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(repository.quickConfirmation?['meal_type'], 'dinner');
    expect(repository.quickConfirmation?['items'], isNotEmpty);
    expect(find.byType(MealLogScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('diary remaining calories includes logged exercise',
      (tester) async {
    await showScreen(tester, const MealLogScreen(), StatefulTestRepository());
    expect(find.text('1650'), findsOneWidget);
    expect(find.text('250'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo review refreshes processing results without a button tap',
      (tester) async {
    final repository = StatefulTestRepository();
    // A processing indicator animates, so avoid pumpAndSettle until it finishes.
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const PhotoReviewScreen(analysisId: 'scan'),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [nutritionRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(theme: NovaTheme.dark(), routerConfig: router),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.photoCalls, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(repository.photoCalls, 2);
    expect(find.text('Needs review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
