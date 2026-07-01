import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class HabitGridScreen extends ConsumerWidget {
  const HabitGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(todayHabitsProvider);
    final templates = ref.watch(habitTemplatesProvider);
    return NovaScaffold(
      title: 'Checklist',
      actions: [
        IconButton(
          tooltip: 'Add habit',
          icon: const Icon(Icons.add_task_outlined),
          onPressed: () => _showCreateHabitSheet(context, ref),
        ),
      ],
      body: habits.when(
        data: (items) {
          final completed = items.where((item) => item.isCompleted).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              NovaSpacing.lg,
              NovaSpacing.lg,
              NovaSpacing.lg,
              120,
            ),
            children: [
              NovaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Today',
                      action: TextButton.icon(
                        onPressed: () => _showCreateHabitSheet(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ),
                    const SizedBox(height: NovaSpacing.sm),
                    Text('$completed of ${items.length} complete'),
                    const SizedBox(height: NovaSpacing.md),
                    LinearProgressIndicator(
                      value: items.isEmpty ? 0 : completed / items.length,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NovaSpacing.md),
              if (items.isEmpty)
                NovaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EmptyState(
                        title: 'No active habits',
                        message:
                            'Create your own checklist or start from a template.',
                        icon: Icons.check_box_outline_blank,
                      ),
                      NovaButton.primary(
                        label: 'Add custom habit',
                        icon: Icons.add,
                        onPressed: () => _showCreateHabitSheet(context, ref),
                      ),
                      const SizedBox(height: NovaSpacing.md),
                      _TemplatePicker(
                        state: templates,
                        onPick: (template) =>
                            _createFromTemplate(context, ref, template),
                      ),
                    ],
                  ),
                )
              else ...[
                for (final item in items) ...[
                  _HabitCard(
                    item: item,
                    onChanged: (checked) => _toggleHabit(
                      context,
                      ref,
                      item,
                      checked,
                    ),
                  ),
                  const SizedBox(height: NovaSpacing.md),
                ],
                NovaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Add another habit'),
                      const SizedBox(height: NovaSpacing.md),
                      NovaButton.primary(
                        label: 'Add custom habit',
                        icon: Icons.add,
                        onPressed: () => _showCreateHabitSheet(context, ref),
                      ),
                      const SizedBox(height: NovaSpacing.md),
                      _TemplatePicker(
                        state: templates,
                        onPick: (template) =>
                            _createFromTemplate(context, ref, template),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: NovaSpacing.lg),
              const SectionHeader(title: 'Month grid'),
              const SizedBox(height: NovaSpacing.md),
              const _MonthGridPreview(),
            ],
          );
        },
        error: (error, _) => ErrorPanel(
          message: error.toString(),
          onRetry: () => ref.invalidate(todayHabitsProvider),
        ),
        loading: () => const LoadingList(),
      ),
    );
  }

  Future<void> _toggleHabit(
    BuildContext context,
    WidgetRef ref,
    HabitGridItem item,
    bool? checked,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = ref.read(nutritionRepositoryProvider);
      if (checked == true) {
        await repository.checkHabit(item.habitId, item.targetCount);
      } else {
        await repository.uncheckHabit(item.habitId);
      }
      _refreshChecklist(ref);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _createFromTemplate(
    BuildContext context,
    WidgetRef ref,
    HabitTemplateSummary template,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(nutritionRepositoryProvider)
          .createHabitFromTemplate(template.id);
      _refreshChecklist(ref);
      messenger.showSnackBar(
        SnackBar(content: Text('${template.title} added to checklist')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _showCreateHabitSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: NovaColors.panel,
      builder: (_) => _CreateHabitSheet(onSaved: () => _refreshChecklist(ref)),
    );
  }

  void _refreshChecklist(WidgetRef ref) {
    ref.invalidate(todayHabitsProvider);
    ref.invalidate(habitTemplatesProvider);
    ref.invalidate(habitMonthGridProvider(currentMonthKey()));
    ref.invalidate(dashboardProvider);
    ref.invalidate(progressReportProvider);
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.item, required this.onChanged});

  final HabitGridItem item;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Row(
        children: [
          Checkbox(value: item.isCompleted, onChanged: onChanged),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.completedCount}/${item.targetCount} ${_unitLabel(item.unit)} - ${item.currentStreak} day streak',
                  style: const TextStyle(color: NovaColors.graphite),
                ),
              ],
            ),
          ),
          NovaBadge(
            label: item.isCompleted ? 'Done' : 'Open',
            icon: item.isCompleted ? Icons.check : Icons.schedule,
            color: item.isCompleted ? NovaColors.mint : NovaColors.gold,
          ),
        ],
      ),
    );
  }
}

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({required this.state, required this.onPick});

  final AsyncValue<List<HabitTemplateSummary>> state;
  final ValueChanged<HabitTemplateSummary> onPick;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (templates) {
        if (templates.isEmpty) {
          return const Text(
            'No templates loaded yet. Use custom habit instead.',
            style: TextStyle(color: NovaColors.graphite),
          );
        }
        return Wrap(
          spacing: NovaSpacing.sm,
          runSpacing: NovaSpacing.sm,
          children: [
            for (final template in templates)
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: Text(template.title),
                onPressed: () => onPick(template),
              ),
          ],
        );
      },
      error: (error, _) => Text(
        error.toString(),
        style: const TextStyle(color: NovaColors.coral),
      ),
      loading: () => const LinearProgressIndicator(),
    );
  }
}

class _CreateHabitSheet extends ConsumerStatefulWidget {
  const _CreateHabitSheet({required this.onSaved});

  final VoidCallback onSaved;

  @override
  ConsumerState<_CreateHabitSheet> createState() => _CreateHabitSheetState();
}

class _CreateHabitSheetState extends ConsumerState<_CreateHabitSheet> {
  final _title = TextEditingController();
  final _target = TextEditingController(text: '1');
  String _unit = 'checkbox';
  String _category = 'custom';
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: NovaSpacing.lg,
          right: NovaSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + NovaSpacing.lg,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Add checklist item',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: NovaSpacing.md),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'What do you want to track?',
                hintText: 'Example: 10k steps, read 20 pages, take vitamins',
                prefixIcon: Icon(Icons.checklist),
              ),
            ),
            const SizedBox(height: NovaSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _target,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Target',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: NovaSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: const [
                      DropdownMenuItem(value: 'checkbox', child: Text('Done')),
                      DropdownMenuItem(
                          value: 'glasses', child: Text('Glasses')),
                      DropdownMenuItem(
                          value: 'minutes', child: Text('Minutes')),
                      DropdownMenuItem(value: 'grams', child: Text('Grams')),
                      DropdownMenuItem(value: 'steps', child: Text('Steps')),
                      DropdownMenuItem(value: 'pages', child: Text('Pages')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom')),
                    ],
                    onChanged: (value) =>
                        setState(() => _unit = value ?? 'checkbox'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NovaSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'custom', child: Text('Custom')),
                DropdownMenuItem(value: 'nutrition', child: Text('Nutrition')),
                DropdownMenuItem(value: 'water', child: Text('Water')),
                DropdownMenuItem(value: 'workout', child: Text('Workout')),
                DropdownMenuItem(value: 'sleep', child: Text('Sleep')),
                DropdownMenuItem(value: 'study', child: Text('Study')),
                DropdownMenuItem(
                  value: 'productivity',
                  child: Text('Productivity'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? 'custom'),
            ),
            const SizedBox(height: NovaSpacing.lg),
            NovaButton.primary(
              label: _saving ? 'Adding...' : 'Add to checklist',
              icon: Icons.add_task,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final title = _title.text.trim();
    final target = int.tryParse(_target.text.trim()) ?? 0;
    if (title.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a checklist item name.')),
      );
      return;
    }
    if (target <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a target greater than 0.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(nutritionRepositoryProvider).createHabit(
            title: title,
            targetCount: target,
            unit: _unit,
            category: _category,
          );
      widget.onSaved();
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('$title added')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
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

String _unitLabel(String unit) {
  return switch (unit) {
    'checkbox' => 'done',
    'glasses' => 'glasses',
    'minutes' => 'min',
    'grams' => 'g',
    'steps' => 'steps',
    'pages' => 'pages',
    _ => unit,
  };
}
