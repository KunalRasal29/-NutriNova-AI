import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    return NovaScaffold(
      title: 'Analytics',
      body: dashboard.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(NovaSpacing.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Calories today',
                    value: data.consumedCalories.toStringAsFixed(0),
                    icon: Icons.local_fire_department,
                    color: NovaColors.mint,
                    caption:
                        '${data.targetCalories.toStringAsFixed(0)} kcal target',
                  ),
                ),
                const SizedBox(width: NovaSpacing.md),
                Expanded(
                  child: MetricCard(
                    label: 'Protein today',
                    value: '${data.proteinG.toStringAsFixed(0)}g',
                    icon: Icons.fitness_center,
                    color: NovaColors.coral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: NovaSpacing.lg),
            _MacroSplit(snapshot: data),
            const SizedBox(height: NovaSpacing.lg),
            _HabitCompletion(habits: data.habits),
            const SizedBox(height: NovaSpacing.lg),
            _WeightTrendMini(values: data.weightTrend),
            const SizedBox(height: NovaSpacing.lg),
            NovaCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, color: NovaColors.mint),
                  const SizedBox(width: NovaSpacing.md),
                  Expanded(child: Text(data.insight)),
                ],
              ),
            ),
          ],
        ),
        error: (error, _) => ErrorPanel(
          message: error.toString(),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        loading: () => const LoadingList(),
      ),
    );
  }
}

class _MacroSplit extends StatelessWidget {
  const _MacroSplit({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final total = snapshot.proteinG + snapshot.carbsG + snapshot.fatG;
    if (total <= 0) {
      return const NovaCard(
        child: EmptyState(
          title: 'No macro data yet',
          message: 'Log meals today to see protein, carbs, and fat split.',
          icon: Icons.pie_chart_outline,
        ),
      );
    }
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Macro split'),
          const SizedBox(height: NovaSpacing.lg),
          SizedBox(
            height: 190,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 42,
                sections: [
                  PieChartSectionData(
                    value: snapshot.proteinG,
                    title: 'P',
                    color: NovaColors.coral,
                  ),
                  PieChartSectionData(
                    value: snapshot.carbsG,
                    title: 'C',
                    color: NovaColors.gold,
                  ),
                  PieChartSectionData(
                    value: snapshot.fatG,
                    title: 'F',
                    color: NovaColors.violet,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitCompletion extends StatelessWidget {
  const _HabitCompletion({required this.habits});

  final List<HabitGridItem> habits;

  @override
  Widget build(BuildContext context) {
    final completed = habits.where((habit) => habit.isCompleted).length;
    final percent = habits.isEmpty ? 0.0 : completed / habits.length;
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Habit completion'),
          const SizedBox(height: NovaSpacing.md),
          if (habits.isEmpty)
            const Text('Create habits to see checklist completion here.')
          else ...[
            LinearProgressIndicator(value: percent),
            const SizedBox(height: NovaSpacing.sm),
            Text('$completed of ${habits.length} complete today'),
          ],
        ],
      ),
    );
  }
}

class _WeightTrendMini extends StatelessWidget {
  const _WeightTrendMini({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Weight trend'),
          const SizedBox(height: NovaSpacing.md),
          if (values.length < 2)
            const Text('Log weight on two days to see progress.')
          else
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < values.length; i++)
                          FlSpot(i.toDouble(), values[i]),
                      ],
                      color: NovaColors.mint,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
