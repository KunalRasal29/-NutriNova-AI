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
          final completedHabits =
              items.where((item) => item.isCompleted).length;
          final targetTotal = items.fold<int>(
            0,
            (sum, item) => sum + item.targetCount,
          );
          final completedTotal = items.fold<int>(
            0,
            (sum, item) => sum + item.completedCount,
          );
          final bestStreak = items.fold<int>(
            0,
            (best, item) =>
                item.currentStreak > best ? item.currentStreak : best,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              NovaSpacing.lg,
              NovaSpacing.lg,
              NovaSpacing.lg,
              120,
            ),
            children: [
              _ChecklistSummary(
                totalHabits: items.length,
                completedHabits: completedHabits,
                completedTotal: completedTotal,
                targetTotal: targetTotal,
                bestStreak: bestStreak,
                onAdd: () => _showCreateHabitSheet(context, ref),
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
                    onSetCount: (count) => _setHabitCount(
                      context,
                      ref,
                      item,
                      count,
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
          message: friendlyErrorMessage(error),
          onRetry: () => ref.invalidate(todayHabitsProvider),
        ),
        loading: () => const LoadingList(),
      ),
    );
  }

  Future<void> _setHabitCount(
    BuildContext context,
    WidgetRef ref,
    HabitGridItem item,
    int completedCount,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = ref.read(nutritionRepositoryProvider);
      final nextCount = completedCount.clamp(0, item.targetCount).toInt();
      if (nextCount > 0) {
        await repository.checkHabit(
          item.habitId,
          nextCount,
          isCompleted: nextCount >= item.targetCount,
        );
      } else {
        await repository.uncheckHabit(item.habitId);
      }
      _refreshChecklist(ref);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
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
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
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

class _ChecklistSummary extends StatelessWidget {
  const _ChecklistSummary({
    required this.totalHabits,
    required this.completedHabits,
    required this.completedTotal,
    required this.targetTotal,
    required this.bestStreak,
    required this.onAdd,
  });

  final int totalHabits;
  final int completedHabits;
  final int completedTotal;
  final int targetTotal;
  final int bestStreak;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final habitProgress =
        totalHabits == 0 ? 0.0 : completedHabits / totalHabits;
    final countProgress =
        targetTotal == 0 ? 0.0 : (completedTotal / targetTotal).clamp(0, 1);
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Today',
            action: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ),
          const SizedBox(height: NovaSpacing.sm),
          Text(
            totalHabits == 0
                ? 'No active habits yet'
                : '$completedHabits of $totalHabits habits complete',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: NovaSpacing.md),
          LinearProgressIndicator(value: habitProgress),
          const SizedBox(height: NovaSpacing.md),
          Wrap(
            spacing: NovaSpacing.sm,
            runSpacing: NovaSpacing.sm,
            children: [
              NovaBadge(
                label: targetTotal == 0
                    ? '0 tracked'
                    : '$completedTotal / $targetTotal total',
                icon: Icons.flag_outlined,
                color: NovaColors.blue,
              ),
              NovaBadge(
                label: '${(countProgress * 100).toStringAsFixed(0)}% today',
                icon: Icons.track_changes,
                color: countProgress >= 1 ? NovaColors.mint : NovaColors.gold,
              ),
              NovaBadge(
                label: '$bestStreak day best streak',
                icon: Icons.local_fire_department_outlined,
                color: NovaColors.coral,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.item, required this.onSetCount});

  final HabitGridItem item;
  final ValueChanged<int> onSetCount;

  @override
  Widget build(BuildContext context) {
    final progress =
        item.targetCount <= 0 ? 0.0 : item.completedCount / item.targetCount;
    final usesStepper = item.targetCount > 1 && item.targetCount <= 20;
    final usesCount = item.targetCount > 1;
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: item.isCompleted,
                onChanged: (checked) =>
                    onSetCount(checked == true ? item.targetCount : 0),
              ),
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
          if (usesCount) ...[
            const SizedBox(height: NovaSpacing.md),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            const SizedBox(height: NovaSpacing.md),
            if (usesStepper)
              Wrap(
                spacing: NovaSpacing.sm,
                runSpacing: NovaSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  QuantityStepper(
                    value: item.completedCount.toDouble(),
                    unit: _unitLabel(item.unit),
                    onDecrement: () => onSetCount(item.completedCount - 1),
                    onIncrement: () => onSetCount(item.completedCount + 1),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Set exact'),
                    onPressed: () => _showExactCountSheet(context),
                  ),
                ],
              )
            else
              Wrap(
                spacing: NovaSpacing.sm,
                runSpacing: NovaSpacing.sm,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Update count'),
                    onPressed: () => _showExactCountSheet(context),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.remove),
                    label: const Text('Reset'),
                    onPressed:
                        item.completedCount == 0 ? null : () => onSetCount(0),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Complete'),
                    onPressed: item.isCompleted
                        ? null
                        : () => onSetCount(item.targetCount),
                  ),
                ],
              ),
          ] else ...[
            const SizedBox(height: NovaSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: Icon(
                  item.isCompleted
                      ? Icons.undo_outlined
                      : Icons.check_circle_outline,
                ),
                label: Text(item.isCompleted ? 'Mark open' : 'Mark done'),
                onPressed: () =>
                    onSetCount(item.isCompleted ? 0 : item.targetCount),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showExactCountSheet(BuildContext context) async {
    final nextCount = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: NovaColors.panel,
      builder: (_) => _HabitCountSheet(item: item),
    );
    if (nextCount != null) onSetCount(nextCount);
  }
}

class _HabitCountSheet extends StatefulWidget {
  const _HabitCountSheet({required this.item});

  final HabitGridItem item;

  @override
  State<_HabitCountSheet> createState() => _HabitCountSheetState();
}

class _HabitCountSheetState extends State<_HabitCountSheet> {
  late final TextEditingController _count;

  @override
  void initState() {
    super.initState();
    _count = TextEditingController(text: '${widget.item.completedCount}');
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          NovaSpacing.lg,
          NovaSpacing.sm,
          NovaSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + NovaSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: NovaSpacing.xs),
            Text(
              'Target: ${widget.item.targetCount} ${_unitLabel(widget.item.unit)}',
              style: const TextStyle(color: NovaColors.graphite),
            ),
            const SizedBox(height: NovaSpacing.lg),
            TextField(
              controller: _count,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Completed ${_unitLabel(widget.item.unit)}',
                prefixIcon: const Icon(Icons.flag_outlined),
              ),
            ),
            const SizedBox(height: NovaSpacing.lg),
            NovaButton.primary(
              label: 'Save progress',
              icon: Icons.check,
              onPressed: () {
                final value = int.tryParse(_count.text.trim());
                if (value == null || value < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid count.')),
                  );
                  return;
                }
                Navigator.of(context).pop(value);
              },
            ),
          ],
        ),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final template in templates)
              Padding(
                padding: const EdgeInsets.only(bottom: NovaSpacing.sm),
                child: _TemplateTile(
                  template: template,
                  onTap: () => onPick(template),
                ),
              ),
          ],
        );
      },
      error: (error, _) => Text(
        friendlyErrorMessage(error),
        style: const TextStyle(color: NovaColors.coral),
      ),
      loading: () => const LinearProgressIndicator(),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.onTap});

  final HabitTemplateSummary template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: NovaColors.panelRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NovaColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(NovaSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: NovaColors.mint.withValues(alpha: 0.14),
                child: Icon(_iconForTemplate(template.icon)),
              ),
              const SizedBox(width: NovaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (template.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        template.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: NovaColors.graphite),
                      ),
                    ],
                    const SizedBox(height: NovaSpacing.xs),
                    Text(
                      '${template.defaultTargetCount} ${_unitLabel(template.unit)} daily',
                      style: const TextStyle(
                        color: NovaColors.blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline, color: NovaColors.blue),
            ],
          ),
        ),
      ),
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
                    onChanged: (value) => setState(() {
                      _unit = value ?? 'checkbox';
                      _target.text = '${_defaultTargetForUnit(_unit)}';
                    }),
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
                  value: 'mindfulness',
                  child: Text('Mindfulness'),
                ),
                DropdownMenuItem(value: 'medicine', child: Text('Medicine')),
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
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
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
        final stats = payload['stats'] as Map<String, dynamic>? ?? const {};
        final total = stats['total'] as num? ?? 0;
        final completed = stats['completed'] as num? ?? 0;
        final percent = stats['percent_complete'] as num? ?? 0;
        return NovaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: month,
                action: Text(
                  total == 0
                      ? 'No due habits yet'
                      : '${percent.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: NovaSpacing.sm),
              Text(
                total == 0
                    ? 'Add a habit to start filling this month.'
                    : '$completed of $total scheduled habit checks complete',
                style: const TextStyle(color: NovaColors.graphite),
              ),
              const SizedBox(height: NovaSpacing.md),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.82,
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
                  return _MonthDayCell(
                    label: label,
                    total: total.toInt(),
                    percent: percent.toDouble(),
                    complete: complete,
                    partial: partial,
                  );
                },
              ),
              const SizedBox(height: NovaSpacing.md),
              const Wrap(
                spacing: NovaSpacing.sm,
                runSpacing: NovaSpacing.sm,
                children: [
                  NovaBadge(label: 'Done', color: NovaColors.mint),
                  NovaBadge(label: 'Partial', color: NovaColors.gold),
                  NovaBadge(label: 'Open', color: NovaColors.graphite),
                ],
              ),
            ],
          ),
        );
      },
      error: (error, _) => ErrorPanel(
        message: friendlyErrorMessage(error),
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

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.label,
    required this.total,
    required this.percent,
    required this.complete,
    required this.partial,
  });

  final String label;
  final int total;
  final double percent;
  final bool complete;
  final bool partial;

  @override
  Widget build(BuildContext context) {
    final color = complete
        ? NovaColors.mint
        : partial
            ? NovaColors.gold
            : total > 0
                ? NovaColors.graphite
                : NovaColors.border;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: total > 0 ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: total > 0 ? color : NovaColors.graphite,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              total == 0 ? '-' : '${percent.toStringAsFixed(0)}%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: total > 0 ? color : NovaColors.graphite,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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

IconData _iconForTemplate(String icon) {
  return switch (icon) {
    'droplets' => Icons.water_drop_outlined,
    'utensils' => Icons.restaurant_outlined,
    'footprints' => Icons.directions_walk,
    'dumbbell' => Icons.fitness_center,
    'moon' => Icons.bedtime_outlined,
    'book' => Icons.menu_book_outlined,
    'pill' => Icons.medication_outlined,
    'brain' => Icons.self_improvement,
    _ => Icons.check_circle_outline,
  };
}

int _defaultTargetForUnit(String unit) {
  return switch (unit) {
    'glasses' => 8,
    'minutes' => 10,
    'grams' => 100,
    'steps' => 8000,
    'pages' => 10,
    _ => 1,
  };
}
