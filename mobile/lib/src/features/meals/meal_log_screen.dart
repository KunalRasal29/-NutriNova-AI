import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class MealLogScreen extends ConsumerWidget {
  const MealLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(todayMealLogsProvider);
    return NovaScaffold(
      title: 'Diary',
      actions: [
        IconButton(
          tooltip: 'Search food',
          icon: const Icon(Icons.search),
          onPressed: () => context.go('/foods/search'),
        ),
      ],
      body: meals.when(
        data: (logs) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todayMealLogsProvider);
            ref.invalidate(dashboardProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              NovaSpacing.lg,
              NovaSpacing.lg,
              NovaSpacing.lg,
              110,
            ),
            children: [
              _CaloriesRemainingHeader(logs: logs),
              const SizedBox(height: NovaSpacing.lg),
              _FastActions(),
              const SizedBox(height: NovaSpacing.lg),
              _MealSection(
                title: 'Breakfast',
                mealType: 'breakfast',
                logs: logs,
              ),
              _MealSection(title: 'Lunch', mealType: 'lunch', logs: logs),
              _MealSection(title: 'Dinner', mealType: 'dinner', logs: logs),
              _MealSection(title: 'Snacks', mealType: 'snack', logs: logs),
            ],
          ),
        ),
        error: (error, _) => ErrorPanel(
          message: error.toString(),
          onRetry: () => ref.invalidate(todayMealLogsProvider),
        ),
        loading: () => const LoadingList(),
      ),
    );
  }
}

class _CaloriesRemainingHeader extends StatelessWidget {
  const _CaloriesRemainingHeader({required this.logs});

  final List<MealLogSummary> logs;

  @override
  Widget build(BuildContext context) {
    final foodCalories = logs.fold<double>(
      0,
      (total, log) => total + log.totalCalories,
    );
    const goal = 2200.0;
    final remaining = goal - foodCalories;
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calories Remaining',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: NovaSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MathPart(value: goal, label: 'Goal'),
              const _MathSymbol('-'),
              _MathPart(value: foodCalories, label: 'Food'),
              const _MathSymbol('+'),
              const _MathPart(value: 0, label: 'Exercise'),
              const _MathSymbol('='),
              _MathPart(
                value: remaining.clamp(0, 9999).toDouble(),
                label: 'Remaining',
                color: NovaColors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MathPart extends StatelessWidget {
  const _MathPart({
    required this.value,
    required this.label,
    this.color = Colors.white,
  });

  final double value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toStringAsFixed(0),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: NovaColors.graphite,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MathSymbol extends StatelessWidget {
  const _MathSymbol(this.symbol);

  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        symbol,
        style: const TextStyle(
          color: NovaColors.graphite,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FastActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: NovaSpacing.sm,
      crossAxisSpacing: NovaSpacing.sm,
      childAspectRatio: 0.95,
      children: [
        _ActionTile(
          icon: Icons.qr_code_scanner,
          label: 'Barcode',
          onTap: () => context.go('/barcode'),
        ),
        _ActionTile(
          icon: Icons.mic_none_outlined,
          label: 'Voice log',
          onTap: () => context.go('/meals/quick-add'),
        ),
        _ActionTile(
          icon: Icons.camera_alt_outlined,
          label: 'Meal scan',
          onTap: () => context.go('/photos/scan'),
        ),
        _ActionTile(
          icon: Icons.flash_on_outlined,
          label: 'Quick add',
          onTap: () => context.go('/meals/quick-add'),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: NovaColors.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NovaColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: NovaColors.blue),
            const SizedBox(height: NovaSpacing.sm),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NovaColors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.title,
    required this.mealType,
    required this.logs,
  });

  final String title;
  final String mealType;
  final List<MealLogSummary> logs;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final log in logs)
        if (log.mealType == mealType) ...log.items,
    ];
    final calories = items.fold<double>(
      0,
      (total, item) => total + item.caloriesKcal,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: NovaSpacing.lg),
      child: NovaCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    calories.toStringAsFixed(0),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              ListTile(
                title: Text(
                  'Add food',
                  style: TextStyle(
                    color: NovaColors.blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                trailing: const Icon(Icons.add, color: NovaColors.blue),
                onTap: () => context.go('/foods/search'),
              )
            else ...[
              for (final item in items) _MealItemTile(item: item),
              ListTile(
                dense: true,
                title: const Text(
                  'Add food',
                  style: TextStyle(
                    color: NovaColors.blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                trailing: const Icon(Icons.add, color: NovaColors.blue),
                onTap: () => context.go('/foods/search'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MealItemTile extends StatelessWidget {
  const _MealItemTile({required this.item});

  final MealItemSummary item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(item.foodName),
      subtitle: Text(
        '${item.quantity.toStringAsFixed(1)} ${item.unit} • '
        '${item.grams.toStringAsFixed(0)}g',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        item.caloriesKcal.toStringAsFixed(0),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}
