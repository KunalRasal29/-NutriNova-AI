import 'package:flutter_test/flutter_test.dart';
import 'package:nutrinova_ai/src/core/models/app_models.dart';

void main() {
  test('progress report combines nutrition, habits, weight, and insights', () {
    final report = ProgressReport.fromJson(
      rangeSummary: {
        'start': '2026-06-24',
        'end': '2026-06-26',
        'days': const [
          {
            'date': '2026-06-24',
            'calories_kcal': '1800',
            'protein_g': '90',
            'carbs_g': '210',
            'fat_g': '55',
          },
          {
            'date': '2026-06-25',
            'calories_kcal': '0',
            'protein_g': '0',
            'carbs_g': '0',
            'fat_g': '0',
          },
          {
            'date': '2026-06-26',
            'calories_kcal': '2200',
            'protein_g': '120',
            'carbs_g': '245',
            'fat_g': '70',
          },
        ],
        'totals': const {
          'calories_kcal': '4000',
          'protein_g': '210',
          'carbs_g': '455',
          'fat_g': '125',
        },
        'averages': const {
          'calories_kcal': '1333.333',
          'protein_g': '70',
          'carbs_g': '151.667',
          'fat_g': '41.667',
        },
      },
      weightTrend: const BodyMetricTrend(
        weights: [74.5, 74.1, 73.8],
        latestWeightKg: 73.8,
        changeKg: -0.7,
      ),
      habitMonthGrid: {
        'month': '2026-06',
        'days': const [
          {
            'date': '2026-06-23',
            'items': [
              {'title': 'Before range', 'is_completed': true},
            ],
          },
          {
            'date': '2026-06-24',
            'items': [
              {'title': 'Drink water', 'is_completed': true},
              {'title': 'Walk', 'is_completed': false},
            ],
          },
          {
            'date': '2026-06-25',
            'items': [
              {'title': 'Drink water', 'is_completed': true},
              {'title': 'Walk', 'is_completed': true},
            ],
          },
          {
            'date': '2026-06-26',
            'items': [
              {'title': 'Drink water', 'is_completed': false},
              {'title': 'Walk', 'is_completed': false},
            ],
          },
        ],
      },
    );

    expect(report.startDate, '2026-06-24');
    expect(report.endDate, '2026-06-26');
    expect(report.days, hasLength(3));
    expect(report.loggedDays, 2);
    expect(report.averageCalories, closeTo(1333.333, 0.001));
    expect(report.averageProtein, 70);
    expect(report.highestCalories, 2200);
    expect(report.totals.proteinG, 210);
    expect(report.habitDays, hasLength(3));
    expect(report.totalHabitCompletionRate, closeTo(3 / 6, 0.001));
    expect(report.weightTrend.latestWeightKg, 73.8);
    expect(report.insights, isNotEmpty);
    expect(
      report.insights.join(' '),
      contains('You logged 2 of 3 days'),
    );
  });
}
