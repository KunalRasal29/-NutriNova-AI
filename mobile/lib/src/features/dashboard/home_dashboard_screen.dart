import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import 'dashboard_controller.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    return NovaScaffold(
      title: 'Today',
      actions: [
        IconButton(
          tooltip: 'Profile',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.go('/profile'),
        ),
      ],
      body: dashboard.when(
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: ListView(
            padding: const EdgeInsets.all(NovaSpacing.lg),
            children: [
              _CaloriesHero(snapshot: data),
              const SizedBox(height: NovaSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Protein',
                      value: '${data.proteinG.toStringAsFixed(0)}g',
                      icon: Icons.fitness_center,
                      color: NovaColors.coral,
                    ),
                  ),
                  const SizedBox(width: NovaSpacing.md),
                  Expanded(
                    child: MetricCard(
                      label: 'Carbs',
                      value: '${data.carbsG.toStringAsFixed(0)}g',
                      icon: Icons.grain,
                      color: NovaColors.gold,
                    ),
                  ),
                  const SizedBox(width: NovaSpacing.md),
                  Expanded(
                    child: MetricCard(
                      label: 'Fat',
                      value: '${data.fatG.toStringAsFixed(0)}g',
                      icon: Icons.opacity,
                      color: NovaColors.violet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NovaSpacing.lg),
              _ActionGrid(),
              const SizedBox(height: NovaSpacing.lg),
              _WaterCard(snapshot: data),
              const SizedBox(height: NovaSpacing.lg),
              _MealsPreview(meals: data.meals),
              const SizedBox(height: NovaSpacing.lg),
              _ChecklistPreview(habits: data.habits),
              const SizedBox(height: NovaSpacing.lg),
              _WeightTrend(snapshot: data),
              const SizedBox(height: NovaSpacing.lg),
              NovaCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: NovaColors.mint),
                    const SizedBox(width: NovaSpacing.md),
                    Expanded(
                      child: Text(
                        data.insight,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

class _CaloriesHero extends StatelessWidget {
  const _CaloriesHero({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final progress = snapshot.targetCalories == 0
        ? 0.0
        : (snapshot.consumedCalories / snapshot.targetCalories).clamp(0.0, 1.0);
    final remaining = snapshot.targetCalories - snapshot.consumedCalories;
    return NovaCard(
      color: NovaColors.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NovaBadge(
            label: 'Daily energy',
            icon: Icons.local_fire_department,
            color: NovaColors.lime,
          ),
          const SizedBox(height: NovaSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                snapshot.consumedCalories.toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: NovaSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '/ ${snapshot.targetCalories.toStringAsFixed(0)} kcal',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(NovaColors.lime),
            ),
          ),
          const SizedBox(height: NovaSpacing.md),
          Text(
            '${remaining.clamp(0, 9999).toStringAsFixed(0)} kcal remaining',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: NovaButton.primary(
            label: 'AI scan',
            icon: Icons.camera_alt_outlined,
            onPressed: () => context.go('/photos/scan'),
          ),
        ),
        const SizedBox(width: NovaSpacing.md),
        Expanded(
          child: NovaButton.secondary(
            label: 'Log food',
            icon: Icons.add_circle_outline,
            onPressed: () => context.go('/meals/manual'),
          ),
        ),
      ],
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final total = snapshot.waterTarget == 0 ? 8 : snapshot.waterTarget;
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Water'),
          const SizedBox(height: NovaSpacing.md),
          Wrap(
            spacing: NovaSpacing.sm,
            runSpacing: NovaSpacing.sm,
            children: List.generate(total, (index) {
              final filled = index < snapshot.waterCompleted;
              return Icon(
                filled ? Icons.water_drop : Icons.water_drop_outlined,
                color: filled ? NovaColors.mint : NovaColors.border,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _MealsPreview extends StatelessWidget {
  const _MealsPreview({required this.meals});

  final List<MealItemSummary> meals;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Today’s meals',
            action: TextButton(
              onPressed: () => context.go('/meals'),
              child: const Text('View'),
            ),
          ),
          const SizedBox(height: NovaSpacing.sm),
          if (meals.isEmpty)
            const Text('No meals yet. Add food or scan a meal.')
          else
            ...meals.map(
              (meal) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restaurant_menu),
                title: Text(meal.foodName),
                subtitle: Text(meal.mealType),
                trailing: Text('${meal.caloriesKcal.toStringAsFixed(0)} kcal'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChecklistPreview extends ConsumerWidget {
  const _ChecklistPreview({required this.habits});

  final List<HabitGridItem> habits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Checklist',
            action: TextButton(
              onPressed: () => context.go('/habits'),
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: NovaSpacing.sm),
          if (habits.isEmpty)
            const Text('No active habits yet.')
          else
            ...habits.take(3).map(
                  (habit) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: habit.isCompleted,
                    onChanged: (checked) async {
                      final repository = ref.read(nutritionRepositoryProvider);
                      if (checked == true) {
                        await repository.checkHabit(
                          habit.habitId,
                          habit.targetCount,
                        );
                      } else {
                        await repository.uncheckHabit(habit.habitId);
                      }
                      ref.invalidate(dashboardProvider);
                      ref.invalidate(todayHabitsProvider);
                    },
                    title: Text(habit.title),
                    subtitle: Text(
                      '${habit.completedCount}/${habit.targetCount} ${habit.unit}',
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _WeightTrend extends StatelessWidget {
  const _WeightTrend({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final values = snapshot.weightTrend;
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Weight trend',
            action: TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const _LogWeightSheet(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Log'),
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          if (snapshot.latestWeightKg != null) ...[
            Text(
              '${snapshot.latestWeightKg!.toStringAsFixed(1)} kg',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            if (snapshot.weightChangeKg != null) ...[
              const SizedBox(height: NovaSpacing.xs),
              Text(
                '${snapshot.weightChangeKg! >= 0 ? '+' : ''}'
                '${snapshot.weightChangeKg!.toStringAsFixed(1)} kg in range',
                style: const TextStyle(color: NovaColors.graphite),
              ),
            ],
            const SizedBox(height: NovaSpacing.lg),
          ],
          if (values.length < 2)
            const Text('Log weight on two different days to see a trend.')
          else
            SizedBox(
              height: 130,
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
                      isCurved: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: NovaColors.mint.withValues(alpha: 0.12),
                      ),
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

class _LogWeightSheet extends ConsumerStatefulWidget {
  const _LogWeightSheet();

  @override
  ConsumerState<_LogWeightSheet> createState() => _LogWeightSheetState();
}

class _LogWeightSheetState extends ConsumerState<_LogWeightSheet> {
  final _weight = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Log weight'),
          const SizedBox(height: NovaSpacing.md),
          TextField(
            controller: _weight,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Weight kg',
              prefixIcon: Icon(Icons.monitor_weight_outlined),
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: _saving ? 'Saving...' : 'Save weight',
            icon: Icons.check,
            onPressed: _saving
                ? null
                : () async {
                    final value = double.tryParse(_weight.text);
                    if (value == null || value <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid weight.')),
                      );
                      return;
                    }
                    setState(() => _saving = true);
                    try {
                      await ref
                          .read(nutritionRepositoryProvider)
                          .logBodyMetric(weightKg: value);
                      ref.invalidate(dashboardProvider);
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (error) {
                      if (!context.mounted) return;
                      setState(() => _saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }
}
