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
      title: 'Meal log',
      actions: [
        IconButton(
          tooltip: 'Quick add',
          icon: const Icon(Icons.flash_on_outlined),
          onPressed: () => context.go('/meals/quick-add'),
        ),
      ],
      body: meals.when(
        data: (logs) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todayMealLogsProvider);
            ref.invalidate(dashboardProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(NovaSpacing.lg),
            children: [
              Row(
                children: [
                  Expanded(
                    child: NovaButton.primary(
                      label: 'Manual add',
                      icon: Icons.add,
                      onPressed: () => context.go('/meals/manual'),
                    ),
                  ),
                  const SizedBox(width: NovaSpacing.md),
                  Expanded(
                    child: NovaButton.secondary(
                      label: 'Search',
                      icon: Icons.search,
                      onPressed: () => context.go('/foods/search'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NovaSpacing.lg),
              if (logs.isEmpty)
                const _EmptyMealLog()
              else
                for (final log in logs) ...[
                  _MealLogCard(log: log),
                  const SizedBox(height: NovaSpacing.md),
                ],
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

class _EmptyMealLog extends StatelessWidget {
  const _EmptyMealLog();

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'No meals logged yet'),
          const SizedBox(height: NovaSpacing.sm),
          const Text(
            'Search foods, use quick add, or scan a meal photo to start today’s log.',
          ),
          const SizedBox(height: NovaSpacing.lg),
          Row(
            children: [
              Expanded(
                child: NovaButton.primary(
                  label: 'Search',
                  icon: Icons.search,
                  onPressed: () => context.go('/foods/search'),
                ),
              ),
              const SizedBox(width: NovaSpacing.md),
              Expanded(
                child: NovaButton.secondary(
                  label: 'AI scan',
                  icon: Icons.camera_alt_outlined,
                  onPressed: () => context.go('/photos/scan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealLogCard extends StatelessWidget {
  const _MealLogCard({required this.log});

  final MealLogSummary log;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: _mealTitle(log),
            action: Text(
              '${log.totalCalories.toStringAsFixed(0)} kcal',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (log.items.isEmpty) ...[
            const SizedBox(height: NovaSpacing.sm),
            const Text('No foods in this meal yet.'),
          ] else
            for (final item in log.items) _MealItemTile(item: item),
        ],
      ),
    );
  }

  String _mealTitle(MealLogSummary log) {
    if (log.name.isNotEmpty) return log.name;
    return log.mealType
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _MealItemTile extends StatelessWidget {
  const _MealItemTile({required this.item});

  final MealItemSummary item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.restaurant_menu),
      title: Text(item.foodName),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: NovaSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.quantity.toStringAsFixed(1)} ${item.unit} • '
              '${item.grams.toStringAsFixed(0)}g',
            ),
            const SizedBox(height: NovaSpacing.xs),
            SourceConfidenceBadges(
              source: item.source,
              confidence: item.confidence,
              verified: item.verified,
              classification: item.classification,
            ),
          ],
        ),
      ),
      trailing: Text(
        '${item.caloriesKcal.toStringAsFixed(0)} kcal',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}
