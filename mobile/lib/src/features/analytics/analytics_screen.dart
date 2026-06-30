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
    final report = ref.watch(progressReportProvider);
    return NovaScaffold(
      title: 'Progress',
      body: report.when(
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(progressReportProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              NovaSpacing.lg,
              NovaSpacing.lg,
              NovaSpacing.lg,
              120,
            ),
            children: [
              _ProgressHeader(report: data),
              const SizedBox(height: NovaSpacing.lg),
              _WeeklySummary(report: data),
              const SizedBox(height: NovaSpacing.lg),
              _NutritionTrendCard(report: data),
              const SizedBox(height: NovaSpacing.lg),
              _MacroSplit(report: data),
              const SizedBox(height: NovaSpacing.lg),
              _HabitCompletion(report: data),
              const SizedBox(height: NovaSpacing.lg),
              _WeightTrend(trend: data.weightTrend),
              const SizedBox(height: NovaSpacing.lg),
              _InsightsCard(insights: data.insights),
            ],
          ),
        ),
        error: (error, _) => ErrorPanel(
          message: error.toString(),
          onRetry: () => ref.invalidate(progressReportProvider),
        ),
        loading: () => const LoadingList(),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    return PageIntro(
      title: 'Weekly report',
      subtitle:
          '${_shortDate(report.startDate)} - ${_shortDate(report.endDate)} - ${report.loggedDays}/${report.days.length} days logged',
      icon: Icons.insights_outlined,
    );
  }
}

class _WeeklySummary extends StatelessWidget {
  const _WeeklySummary({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    return NutritionMetricGrid(
      items: [
        NutritionMetricItem(
          label: 'Avg calories',
          value: report.averageCalories.toStringAsFixed(0),
          icon: Icons.local_fire_department,
          color: NovaColors.mint,
        ),
        NutritionMetricItem(
          label: 'Avg protein',
          value: '${report.averageProtein.toStringAsFixed(0)}g',
          icon: Icons.fitness_center,
          color: NovaColors.coral,
        ),
        NutritionMetricItem(
          label: 'Logged days',
          value: '${report.loggedDays}/${report.days.length}',
          icon: Icons.event_available_outlined,
          color: NovaColors.blue,
        ),
        NutritionMetricItem(
          label: 'Habit score',
          value: report.habitDays.any((day) => day.total > 0)
              ? '${(report.totalHabitCompletionRate * 100).toStringAsFixed(0)}%'
              : '--',
          icon: Icons.checklist_outlined,
          color: NovaColors.gold,
        ),
      ],
    );
  }
}

class _NutritionTrendCard extends StatelessWidget {
  const _NutritionTrendCard({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    if (report.days.every((day) => !day.hasLoggedNutrition)) {
      return const NovaCard(
        child: EmptyState(
          title: 'No nutrition trend yet',
          message:
              'Log meals for a few days to see calories and protein trends.',
          icon: Icons.show_chart,
        ),
      );
    }
    final caloriesSpots = <FlSpot>[
      for (var i = 0; i < report.days.length; i += 1)
        FlSpot(i.toDouble(), report.days[i].preview.caloriesKcal),
    ];
    final proteinSpots = <FlSpot>[
      for (var i = 0; i < report.days.length; i += 1)
        FlSpot(i.toDouble(), report.days[i].preview.proteinG),
    ];
    final maxCalories =
        report.highestCalories <= 0 ? 100.0 : report.highestCalories;
    final maxProtein = report.days.fold<double>(
      0,
      (highest, day) =>
          day.preview.proteinG > highest ? day.preview.proteinG : highest,
    );
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Calories and protein'),
          const SizedBox(height: NovaSpacing.lg),
          _TrendLineChart(
            label: 'Calories',
            value: '${report.averageCalories.toStringAsFixed(0)} kcal avg',
            spots: caloriesSpots,
            days: report.days,
            color: NovaColors.mint,
            maxY: maxCalories * 1.2,
          ),
          const SizedBox(height: NovaSpacing.lg),
          _TrendLineChart(
            label: 'Protein',
            value: '${report.averageProtein.toStringAsFixed(0)}g avg',
            spots: proteinSpots,
            days: report.days,
            color: NovaColors.coral,
            maxY: (maxProtein <= 0 ? 40 : maxProtein) * 1.25,
          ),
        ],
      ),
    );
  }
}

class _TrendLineChart extends StatelessWidget {
  const _TrendLineChart({
    required this.label,
    required this.value,
    required this.spots,
    required this.days,
    required this.color,
    required this.maxY,
  });

  final String label;
  final String value;
  final List<FlSpot> spots;
  final List<NutritionDaySummary> days;
  final Color color;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            NovaBadge(label: label, color: color),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: NovaColors.graphite,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: NovaSpacing.sm),
        SizedBox(
          height: 145,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: NovaColors.border,
                  strokeWidth: 1,
                ),
              ),
              titlesData: _bottomTitles(days),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: true),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  color: color,
                  barWidth: 3,
                  isCurved: true,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MacroSplit extends StatelessWidget {
  const _MacroSplit({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final total =
        report.totals.proteinG + report.totals.carbsG + report.totals.fatG;
    if (total <= 0) {
      return const NovaCard(
        child: EmptyState(
          title: 'No macro data yet',
          message: 'Log meals to see protein, carbs, and fat split.',
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
                centerSpaceRadius: 44,
                sections: [
                  _macroSection('P', report.totals.proteinG, NovaColors.coral),
                  _macroSection('C', report.totals.carbsG, NovaColors.gold),
                  _macroSection('F', report.totals.fatG, NovaColors.violet),
                ],
              ),
            ),
          ),
          const SizedBox(height: NovaSpacing.md),
          Wrap(
            spacing: NovaSpacing.sm,
            runSpacing: NovaSpacing.sm,
            children: [
              NovaBadge(
                label: 'P ${report.totals.proteinG.toStringAsFixed(0)}g',
                color: NovaColors.coral,
              ),
              NovaBadge(
                label: 'C ${report.totals.carbsG.toStringAsFixed(0)}g',
                color: NovaColors.gold,
              ),
              NovaBadge(
                label: 'F ${report.totals.fatG.toStringAsFixed(0)}g',
                color: NovaColors.violet,
              ),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _macroSection(String title, double value, Color color) {
    return PieChartSectionData(
      value: value,
      title: title,
      color: color,
      radius: 54,
      titleStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _HabitCompletion extends StatelessWidget {
  const _HabitCompletion({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final hasHabits = report.habitDays.any((day) => day.total > 0);
    if (!hasHabits) {
      return const NovaCard(
        child: EmptyState(
          title: 'No habit trend yet',
          message: 'Create or check habits to see completion patterns here.',
          icon: Icons.checklist_outlined,
        ),
      );
    }
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Habit completion',
            action: Text(
              '${(report.totalHabitCompletionRate * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: NovaColors.gold,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: 100,
                minY: 0,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: NovaColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: _habitTitles(report.habitDays),
                barGroups: [
                  for (var i = 0; i < report.habitDays.length; i += 1)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: report.habitDays[i].completionRate * 100,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                          color: NovaColors.gold,
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: 100,
                            color: NovaColors.panelSoft,
                          ),
                        ),
                      ],
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

class _WeightTrend extends StatelessWidget {
  const _WeightTrend({required this.trend});

  final BodyMetricTrend trend;

  @override
  Widget build(BuildContext context) {
    if (trend.weights.length < 2) {
      return const NovaCard(
        child: EmptyState(
          title: 'No weight trend yet',
          message: 'Log weight on two different days to see your trend.',
          icon: Icons.monitor_weight_outlined,
        ),
      );
    }
    final minWeight = trend.weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = trend.weights.reduce((a, b) => a > b ? a : b);
    final rangePadding =
        ((maxWeight - minWeight) * 0.2).clamp(0.5, 5.0).toDouble();
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Weight trend',
            action: trend.changeKg == null
                ? null
                : Text(
                    '${trend.changeKg! > 0 ? '+' : ''}${trend.changeKg!.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      color: trend.changeKg! <= 0
                          ? NovaColors.mint
                          : NovaColors.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: minWeight - rangePadding,
                maxY: maxWeight + rangePadding,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: NovaColors.border,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < trend.weights.length; i += 1)
                        FlSpot(i.toDouble(), trend.weights[i]),
                    ],
                    color: NovaColors.blue,
                    barWidth: 3,
                    isCurved: true,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: NovaSpacing.md),
          Text(
            'Latest ${trend.latestWeightKg?.toStringAsFixed(1) ?? '--'} kg',
            style: const TextStyle(
              color: NovaColors.graphite,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    final rows = insights.isEmpty
        ? const ['Log meals, habits, and weight to generate weekly insights.']
        : insights;
    return NovaCard(
      color: NovaColors.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Insights'),
          const SizedBox(height: NovaSpacing.md),
          for (final insight in rows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome,
                    color: NovaColors.mint, size: 20),
                const SizedBox(width: NovaSpacing.md),
                Expanded(
                  child: Text(
                    insight,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (insight != rows.last) const SizedBox(height: NovaSpacing.md),
          ],
        ],
      ),
    );
  }
}

FlTitlesData _bottomTitles(List<NutritionDaySummary> days) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: const AxisTitles(
      sideTitles: SideTitles(showTitles: true, reservedSize: 42),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        getTitlesWidget: (value, meta) {
          final index = value.toInt();
          if (index < 0 || index >= days.length) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _weekdayLabel(days[index].date),
              style: const TextStyle(
                color: NovaColors.graphite,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        },
      ),
    ),
  );
}

FlTitlesData _habitTitles(List<HabitCompletionDay> days) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        getTitlesWidget: (value, meta) {
          final index = value.toInt();
          if (index < 0 || index >= days.length) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _weekdayLabel(days[index].date),
              style: const TextStyle(
                color: NovaColors.graphite,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        },
      ),
    ),
  );
}

String _shortDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.day}/${date.month}';
}

String _weekdayLabel(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return '';
  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return labels[date.weekday - 1];
}
