import 'package:flutter_test/flutter_test.dart';
import 'package:nutrinova_ai/src/core/models/app_models.dart';

void main() {
  test('food detail reuses the current user portion preference', () {
    final food = FoodDetail.fromJson({
      'id': 'chapati',
      'canonical_name': 'Chapati',
      'source_badge': 'IFCT_2017',
      'confidence_score': 0.9,
      'preparation_state': 'prepared',
      'default_serving_g': 40,
      'servings': [
        {
          'id': 'one',
          'serving_name': '1 chapati',
          'grams': 40,
          'is_default': true,
        },
      ],
      'nutrients': const [],
      'personal_portion_preferences': [
        {
          'unit': 'piece',
          'grams_per_unit': 45,
          'times_used': 3,
        },
      ],
    });

    expect(food.preparationState, 'prepared');
    expect(
      food.effectiveGrams(quantity: 2, unit: 'piece'),
      90,
    );
  });

  test('personalized nutrition target response is parsed', () {
    final plan = NutritionTargetPlan.fromJson({
      'targets': {
        'calories_kcal': '2320.0',
        'protein_g': '117.0',
        'carbs_g': '280.0',
        'fat_g': '72.0',
        'fiber_g': '32.0',
        'water_ml': '2600.0',
      },
      'method': 'mifflin_st_jeor_wellness_estimate',
      'customized': false,
      'requires_confirmation': true,
      'assumptions': ['Age 30 was used.'],
      'disclaimer': 'Wellness estimate.',
    });

    expect(plan.caloriesKcal, 2320);
    expect(plan.proteinG, 117);
    expect(plan.waterMl, 2600);
    expect(plan.requiresConfirmation, isTrue);
  });
}
