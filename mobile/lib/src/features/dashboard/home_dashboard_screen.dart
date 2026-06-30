import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../auth/auth_controller.dart';
import 'dashboard_controller.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final user = ref.watch(authControllerProvider).valueOrNull;
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
            padding: const EdgeInsets.fromLTRB(
              NovaSpacing.lg,
              NovaSpacing.lg,
              NovaSpacing.lg,
              110,
            ),
            children: [
              _GreetingHeader(displayName: user?.displayName ?? 'there'),
              const SizedBox(height: NovaSpacing.lg),
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
              const _ActionGrid(),
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

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 23,
          backgroundColor: NovaColors.violet,
          child: Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: NovaSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NutriNova AI',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: NovaColors.blue,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: NovaSpacing.xs),
              Text(
                '${_friendlyDate(now)} • Hi, $displayName',
                style: const TextStyle(color: NovaColors.graphite),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none),
          onPressed: () {},
        ),
      ],
    );
  }

  String _friendlyDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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
      color: NovaColors.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Calories',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const Spacer(),
              const NovaBadge(
                label: 'Today',
                icon: Icons.calendar_today_outlined,
                color: NovaColors.blue,
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.lg),
          Row(
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        strokeWidth: 12,
                        value: progress,
                        backgroundColor: NovaColors.ink,
                        valueColor:
                            const AlwaysStoppedAnimation(NovaColors.blue),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          remaining.clamp(0, 9999).toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'Remaining',
                          style: TextStyle(
                            color: NovaColors.graphite,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: NovaSpacing.xl),
              Expanded(
                child: Column(
                  children: [
                    _CalorieLine(
                      icon: Icons.flag_outlined,
                      label: 'Base Goal',
                      value: snapshot.targetCalories,
                    ),
                    const SizedBox(height: NovaSpacing.md),
                    _CalorieLine(
                      icon: Icons.restaurant,
                      label: 'Food',
                      value: snapshot.consumedCalories,
                      color: NovaColors.blue,
                    ),
                    const SizedBox(height: NovaSpacing.md),
                    const _CalorieLine(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Exercise',
                      value: 0,
                      color: NovaColors.gold,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalorieLine extends StatelessWidget {
  const _CalorieLine({
    required this.icon,
    required this.label,
    required this.value,
    this.color = NovaColors.graphite,
  });

  final IconData icon;
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: NovaSpacing.md),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: NovaColors.graphite,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          value.toStringAsFixed(0),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: NovaSpacing.md,
      crossAxisSpacing: NovaSpacing.md,
      childAspectRatio: 2.6,
      children: [
        NovaButton.primary(
          label: 'Log food',
          icon: Icons.add_circle_outline,
          onPressed: () => context.go('/meals/manual'),
        ),
        NovaButton.secondary(
          label: 'Scan meal',
          icon: Icons.camera_alt_outlined,
          onPressed: () => context.go('/photos/scan'),
        ),
        NovaButton.secondary(
          label: 'Quick add',
          icon: Icons.flash_on_outlined,
          onPressed: () => context.go('/meals/quick-add'),
        ),
        NovaButton.secondary(
          label: 'Barcode',
          icon: Icons.qr_code_scanner,
          onPressed: () => context.go('/barcode'),
        ),
        NovaButton.secondary(
          label: 'Add habit',
          icon: Icons.check_box_outlined,
          onPressed: () => context.go('/habits'),
        ),
        NovaButton.secondary(
          label: 'Progress',
          icon: Icons.insights_outlined,
          onPressed: () => context.go('/analytics'),
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
          if (snapshot.waterTarget == 0)
            const Text('Create a water habit to track glasses here.')
          else
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
    final grouped = <String, List<MealItemSummary>>{};
    for (final meal in meals) {
      grouped.putIfAbsent(meal.mealType, () => []).add(meal);
    }
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No meals yet. Add food or scan a meal.'),
                const SizedBox(height: NovaSpacing.md),
                NovaButton.primary(
                  label: 'Log first food',
                  icon: Icons.add,
                  onPressed: () => context.go('/meals/manual'),
                ),
              ],
            )
          else
            for (final type in ['breakfast', 'lunch', 'dinner', 'snack'])
              if ((grouped[type] ?? const []).isNotEmpty)
                _MealGroup(mealType: type, items: grouped[type]!),
        ],
      ),
    );
  }
}

class _MealGroup extends StatelessWidget {
  const _MealGroup({required this.mealType, required this.items});

  final String mealType;
  final List<MealItemSummary> items;

  @override
  Widget build(BuildContext context) {
    final calories = items.fold<double>(
      0,
      (total, item) => total + item.caloriesKcal,
    );
    return Padding(
      padding: const EdgeInsets.only(top: NovaSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _mealLabel(mealType),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text('${calories.toStringAsFixed(0)} kcal'),
            ],
          ),
          for (final item in items.take(3))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restaurant_menu, size: 18),
              title: Text(item.foodName, overflow: TextOverflow.ellipsis),
              trailing: Text(item.caloriesKcal.toStringAsFixed(0)),
            ),
        ],
      ),
    );
  }

  String _mealLabel(String type) {
    return type[0].toUpperCase() + type.substring(1).replaceAll('_', ' ');
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No active habits yet.'),
                const SizedBox(height: NovaSpacing.md),
                NovaButton.secondary(
                  label: 'Open templates',
                  icon: Icons.add_task,
                  onPressed: () => context.go('/habits'),
                ),
              ],
            )
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
