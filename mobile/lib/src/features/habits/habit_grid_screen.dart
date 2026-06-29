import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class HabitGridScreen extends ConsumerWidget {
  const HabitGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(todayHabitsProvider);
    return NovaScaffold(
      title: 'Checklist',
      body: habits.when(
        data: (items) => ListView(
          padding: const EdgeInsets.all(NovaSpacing.lg),
          children: [
            const SectionHeader(title: 'Today'),
            const SizedBox(height: NovaSpacing.md),
            if (items.isEmpty)
              const EmptyState(
                title: 'No active habits',
                message:
                    'Create habits from templates to build your daily grid.',
                icon: Icons.check_box_outline_blank,
              )
            else
              for (final item in items) ...[
                NovaCard(
                  child: Row(
                    children: [
                      Checkbox(
                        value: item.isCompleted,
                        onChanged: (checked) async {
                          final repository =
                              ref.read(nutritionRepositoryProvider);
                          if (checked == true) {
                            await repository.checkHabit(
                              item.habitId,
                              item.targetCount,
                            );
                          } else {
                            await repository.uncheckHabit(item.habitId);
                          }
                          ref.invalidate(todayHabitsProvider);
                          ref.invalidate(
                              habitMonthGridProvider(currentMonthKey()));
                          ref.invalidate(dashboardProvider);
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.completedCount}/${item.targetCount} ${item.unit} • ${item.currentStreak} day streak',
                              style:
                                  const TextStyle(color: NovaColors.graphite),
                            ),
                          ],
                        ),
                      ),
                      const NovaBadge(label: 'Grid', icon: Icons.grid_on),
                    ],
                  ),
                ),
                const SizedBox(height: NovaSpacing.md),
              ],
            const SizedBox(height: NovaSpacing.lg),
            const SectionHeader(title: 'Month grid'),
            const SizedBox(height: NovaSpacing.md),
            const _MonthGridPreview(),
          ],
        ),
        error: (error, _) => ErrorPanel(
          message: error.toString(),
          onRetry: () => ref.invalidate(todayHabitsProvider),
        ),
        loading: () => const LoadingList(),
      ),
    );
  }
}

class _MonthGridPreview extends ConsumerWidget {
  const _MonthGridPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = currentMonthKey();
    final grid = ref.watch(habitMonthGridProvider(month));
    return grid.when(
      data: (payload) {
        final days = payload['days'] as List<dynamic>? ?? const [];
        return NovaCard(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemBuilder: (_, index) {
              final day = days[index] as Map<String, dynamic>;
              final stats = day['stats'] as Map<String, dynamic>? ?? {};
              final total = stats['total'] as num? ?? 0;
              final percent = stats['percent_complete'] as num? ?? 0;
              final complete = total > 0 && percent >= 100;
              final partial = total > 0 && percent > 0 && percent < 100;
              final dateText = day['date']?.toString() ?? '';
              final label = dateText.length >= 10
                  ? int.tryParse(dateText.substring(8, 10))?.toString() ??
                      '${index + 1}'
                  : '${index + 1}';
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: complete
                      ? NovaColors.mint.withValues(alpha: 0.14)
                      : partial
                          ? NovaColors.gold.withValues(alpha: 0.14)
                          : NovaColors.border.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: complete
                        ? NovaColors.mint
                        : partial
                            ? NovaColors.gold
                            : NovaColors.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: complete
                          ? NovaColors.mint
                          : partial
                              ? NovaColors.gold
                              : NovaColors.graphite,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      error: (error, _) => ErrorPanel(
        message: error.toString(),
        onRetry: () => ref.invalidate(habitMonthGridProvider(month)),
      ),
      loading: () => const NovaCard(
        child: SizedBox(
          height: 120,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}
