import 'package:flutter_test/flutter_test.dart';
import 'package:nutrinova_ai/src/core/models/app_models.dart';

void main() {
  test('photo review payload parses corrected quantity and totals', () {
    final review = PhotoReview.fromJson({
      'analysis_id': 'analysis-1',
      'status': 'needs_review',
      'image_url': 'https://example.test/photo.jpg',
      'disclaimer': 'Photo nutrition is an estimate.',
      'warnings': ['AI estimate needs review'],
      'total_preview': {
        'calories_kcal': '465.000',
        'protein_g': '37.800',
        'carbs_g': '3.300',
        'fat_g': '31.800',
      },
      'items': [
        {
          'id': 'detected-1',
          'detected_name': 'boiled egg',
          'matched_food': 'food-1',
          'matched_food_name': 'Egg, whole, boiled',
          'quantity_value': '5.000',
          'quantity_unit': 'egg',
          'user_quantity_value': '6.000',
          'effective_quantity_value': '6.000',
          'effective_quantity_unit': 'egg',
          'grams_per_unit_estimate': '50.000',
          'effective_total_grams': '300.000',
          'min_total_grams_estimate': '275.000',
          'max_total_grams_estimate': '325.000',
          'calories_kcal': '465.000',
          'protein_g': '37.800',
          'carbs_g': '3.300',
          'fat_g': '31.800',
          'confidence_score': '0.8800',
          'source_badges': [
            {
              'source_type': 'IFCT_2017',
              'food_verified': true,
            }
          ],
          'warnings': [],
          'alternative_matches': [
            {
              'id': 'food-1',
              'name': 'Egg, whole, boiled',
              'brand': '',
              'source_badge': 'IFCT_2017',
              'verified': true,
              'nutrition_per_100g': {
                'calories': '155.000',
                'protein_g': '12.600',
                'carbs_g': '1.100',
                'fat_g': '10.600',
              },
            }
          ],
        }
      ],
    });

    expect(review.analysisId, 'analysis-1');
    expect(review.totalPreview.caloriesKcal, 465);
    expect(review.warnings, contains('AI estimate needs review'));
    expect(review.items.single.quantity, 6);
    expect(review.items.single.grams, 300);
    expect(review.items.single.gramsPerUnit, 50);
    expect(review.items.single.minGrams, 275);
    expect(review.items.single.maxGrams, 325);
    expect(review.items.single.portionLabel, '6 eggs');
    expect(review.items.single.gramsLabel, '300g');
    expect(review.items.single.detectedName, 'boiled egg');
    expect(review.items.single.matchedFoodName, 'Egg, whole, boiled');
    expect(review.items.single.sourceBadges.single, 'IFCT_2017 verified');
    expect(review.items.single.matchedFoodId, 'food-1');
    expect(review.items.single.alternatives.single.name, 'Egg, whole, boiled');
    expect(review.hasConfirmableItems, isTrue);
  });
}
