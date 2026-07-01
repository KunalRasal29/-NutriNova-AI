import 'package:flutter_test/flutter_test.dart';
import 'package:nutrinova_ai/src/core/models/app_models.dart';
import 'package:nutrinova_ai/src/core/widgets/nova_widgets.dart';

void main() {
  test('food detail preview scales selected servings and grams', () {
    const food = FoodDetail(
      id: 'whey',
      name: 'Whey protein powder',
      brand: '',
      description: '',
      sourceBadge: 'TRUSTED',
      confidenceScore: 0.9,
      dataClassification: 'trusted_seeded',
      verified: true,
      defaultServingG: 30,
      servings: [
        FoodServingOption(
          id: 'scoop',
          name: '1 scoop',
          grams: 30,
          isDefault: true,
        ),
      ],
      nutrients: [
        FoodNutrientValue(
          code: 'calories',
          name: 'Calories',
          unit: 'kcal',
          amountPer100g: 400,
        ),
        FoodNutrientValue(
          code: 'protein_g',
          name: 'Protein',
          unit: 'g',
          amountPer100g: 80,
        ),
        FoodNutrientValue(
          code: 'carbs_g',
          name: 'Carbs',
          unit: 'g',
          amountPer100g: 10,
        ),
        FoodNutrientValue(
          code: 'fat_g',
          name: 'Fat',
          unit: 'g',
          amountPer100g: 6,
        ),
      ],
      isFavorite: false,
    );

    final scoop = food.previewFor(quantity: 1, unit: 'scoop');
    expect(scoop.caloriesKcal, closeTo(120, 0.001));
    expect(scoop.proteinG, closeTo(24, 0.001));
    expect(scoop.carbsG, closeTo(3, 0.001));
    expect(scoop.fatG, closeTo(1.8, 0.001));

    final weighed = food.previewFor(quantity: 200, unit: 'gram');
    expect(weighed.caloriesKcal, closeTo(800, 0.001));
    expect(weighed.proteinG, closeTo(160, 0.001));
  });

  test('friendly error message hides technical browser network text', () {
    final message = friendlyErrorMessage(
      Exception('The connection errored: XMLHttpRequest onError callback'),
    );

    expect(message, contains('Could not reach the backend'));
    expect(message, isNot(contains('XMLHttpRequest')));
  });
}
