import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrinova_ai/src/core/models/app_models.dart';
import 'package:nutrinova_ai/src/core/repositories/nutrition_repository.dart';
import 'package:nutrinova_ai/src/core/repositories/providers.dart';
import 'package:nutrinova_ai/src/core/theme/nova_theme.dart';
import 'package:nutrinova_ai/src/features/foods/create_custom_food_screen.dart';

void main() {
  test('advanced food search request keeps filters and pagination separate',
      () {
    const request = FoodSearchRequest(
      query: 'boiled egg',
      page: 2,
      pageSize: 25,
      foodType: 'generic',
      source: 'USDA_FDC',
      preparationState: 'boiled',
      verified: true,
    );

    expect(request.queryParameters, {
      'q': 'boiled egg',
      'page': 2,
      'page_size': 25,
      'food_type': 'generic',
      'source': 'USDA_FDC',
      'preparation_state': 'boiled',
      'verified': true,
    });
    expect(request.cacheKey, contains('boiled egg'));
    expect(request.cacheKey, contains('USDA_FDC'));
  });

  test('custom estimate parser preserves ranges, references and uncertainty',
      () {
    final estimate = CustomFoodEstimate.fromJson({
      'normalized_food_name': 'boiled egg',
      'suggested_nutrients': {
        'calories_kcal': '77.5',
        'protein_g': '6.3',
      },
      'estimated_range': {
        'calories_kcal': {'min': '70', 'likely': '77.5', 'max': '85'},
      },
      'reference_matches': [
        {
          'food_id': 'egg-reference',
          'name': 'Egg, whole, boiled',
          'source': {
            'name': 'USDA FoodData Central',
            'source_type': 'USDA_FDC',
          },
          'nutrients_for_entered_serving': {'calories_kcal': '77.5'},
        },
      ],
      'source_badges': ['USDA_FDC'],
      'confidence': '0.91',
      'warnings': ['Review serving grams.'],
      'can_estimate': true,
      'requires_review': true,
      'estimation_method': 'database_matches',
    });

    expect(estimate.suggestedNutrients['calories_kcal'], 77.5);
    expect(estimate.ranges['calories_kcal']?.maximum, 85);
    expect(estimate.references.single.sourceBadge, 'USDA_FDC');
    expect(estimate.requiresReview, isTrue);
  });

  testWidgets(
      'custom food wizard reaches review without marking estimate verified',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const CreateCustomFoodScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nutritionRepositoryProvider.overrideWithValue(
            MockNutritionRepository(),
          ),
        ],
        child: MaterialApp.router(
          theme: NovaTheme.dark(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Homemade egg snack');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Define one serving'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Estimate macros'), findsWidgets);
    expect(find.textContaining('never verified nutrition'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Estimate macros'));
    await tester.pumpAndSettle();

    expect(find.text('Review the suggestion'), findsOneWidget);
    expect(
        find.text('Suggested estimate—review before saving.'), findsOneWidget);
    expect(find.text('Unverified'), findsOneWidget);
  });
}
