import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class MealLogScreen extends ConsumerWidget {
  const MealLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(todayMealLogsProvider);
    final dashboard = ref.watch(dashboardProvider).valueOrNull;
    return NovaScaffold(
      title: 'Diary',
      actions: [
        IconButton(
          tooltip: 'Search food',
          icon: const Icon(Icons.search),
          onPressed: () => context.go(_withMealType('/foods/search', 'lunch')),
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
              _CaloriesRemainingHeader(logs: logs, snapshot: dashboard),
              const SizedBox(height: NovaSpacing.lg),
              const _FastActions(mealType: 'lunch'),
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
  const _CaloriesRemainingHeader({required this.logs, required this.snapshot});

  final List<MealLogSummary> logs;
  final DashboardSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final totals = _DiaryTotals.fromLogs(logs);
    final foodCalories = snapshot?.consumedCalories ?? totals.calories;
    final goal = snapshot?.targetCalories ?? 2000;
    final protein = snapshot?.proteinG ?? totals.proteinG;
    final carbs = snapshot?.carbsG ?? totals.carbsG;
    final fat = snapshot?.fatG ?? totals.fatG;
    final fiber = snapshot?.fiberG ?? totals.fiberG;
    final sodium = snapshot?.sodiumMg ?? totals.sodiumMg;
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
                value: remaining.abs(),
                label: remaining < 0 ? 'Over' : 'Remaining',
                color: remaining < 0 ? NovaColors.coral : NovaColors.blue,
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.lg),
          NutritionMetricGrid(
            items: [
              NutritionMetricItem(
                label: 'Protein',
                value: '${protein.toStringAsFixed(0)}g',
                icon: Icons.fitness_center,
                color: NovaColors.coral,
              ),
              NutritionMetricItem(
                label: 'Carbs',
                value: '${carbs.toStringAsFixed(0)}g',
                icon: Icons.grain,
                color: NovaColors.gold,
              ),
              NutritionMetricItem(
                label: 'Fat',
                value: '${fat.toStringAsFixed(0)}g',
                icon: Icons.opacity,
                color: NovaColors.violet,
              ),
              NutritionMetricItem(
                label: 'Fiber',
                value: '${fiber.toStringAsFixed(0)}g',
                icon: Icons.grass_outlined,
                color: NovaColors.lime,
              ),
              NutritionMetricItem(
                label: 'Food',
                value: '${foodCalories.toStringAsFixed(0)} kcal',
                icon: Icons.restaurant,
                color: NovaColors.blue,
              ),
              NutritionMetricItem(
                label: 'Sodium',
                value: '${sodium.toStringAsFixed(0)}mg',
                icon: Icons.science_outlined,
                color: NovaColors.mint,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiaryTotals {
  const _DiaryTotals({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sodiumMg,
  });

  factory _DiaryTotals.fromLogs(List<MealLogSummary> logs) {
    var calories = 0.0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    var fiber = 0.0;
    var sodium = 0.0;
    for (final log in logs) {
      for (final item in log.items) {
        calories += item.caloriesKcal;
        protein += item.proteinG;
        carbs += item.carbsG;
        fat += item.fatG;
        fiber += item.fiberG;
        sodium += item.sodiumMg;
      }
    }
    return _DiaryTotals(
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      fiberG: fiber,
      sodiumMg: sodium,
    );
  }

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sodiumMg;
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
  const _FastActions({required this.mealType});

  final String mealType;

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
          onTap: () => context.go(_withMealType('/barcode', mealType)),
        ),
        _ActionTile(
          icon: Icons.flash_on_outlined,
          label: 'Text add',
          onTap: () => context.go(_withMealType('/meals/quick-add', mealType)),
        ),
        _ActionTile(
          icon: Icons.camera_alt_outlined,
          label: 'Meal scan',
          onTap: () => context.go(_withMealType('/photos/scan', mealType)),
        ),
        _ActionTile(
          icon: Icons.add_circle_outline,
          label: 'Custom',
          onTap: () => context.go(_withMealType('/foods/custom', mealType)),
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

class _MealSection extends ConsumerWidget {
  const _MealSection({
    required this.title,
    required this.mealType,
    required this.logs,
  });

  final String title;
  final String mealType;
  final List<MealLogSummary> logs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      for (final log in logs)
        if (log.mealType == mealType) ...log.items,
    ];
    final calories = items.fold<double>(
      0,
      (total, item) => total + item.caloriesKcal,
    );
    final protein =
        items.fold<double>(0, (total, item) => total + item.proteinG);
    final carbs = items.fold<double>(0, (total, item) => total + item.carbsG);
    final fat = items.fold<double>(0, (total, item) => total + item.fatG);
    return Padding(
      padding: const EdgeInsets.only(bottom: NovaSpacing.lg),
      child: NovaCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: NovaSpacing.xs),
                    Row(
                      children: [
                        _MealMacroBadge(
                          label: 'P',
                          value: protein,
                          color: NovaColors.coral,
                        ),
                        const SizedBox(width: NovaSpacing.sm),
                        _MealMacroBadge(
                          label: 'C',
                          value: carbs,
                          color: NovaColors.gold,
                        ),
                        const SizedBox(width: NovaSpacing.sm),
                        _MealMacroBadge(
                          label: 'F',
                          value: fat,
                          color: NovaColors.violet,
                        ),
                      ],
                    ),
                  ],
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
                onTap: () =>
                    context.go(_withMealType('/foods/search', mealType)),
              )
            else ...[
              for (final item in items)
                _MealItemTile(
                  item: item,
                  onEdit: () => _openEditSheet(context, ref, item),
                  onDelete: () => _confirmDelete(context, ref, item),
                ),
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
                onTap: () =>
                    context.go(_withMealType('/foods/search', mealType)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openEditSheet(
    BuildContext context,
    WidgetRef ref,
    MealItemSummary item,
  ) async {
    final result = await showModalBottomSheet<_MealItemEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: NovaColors.panel,
      builder: (_) => _MealItemEditSheet(item: item),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(nutritionRepositoryProvider).updateMealItem(
            itemId: item.id,
            foodId: item.foodId,
            quantity: result.quantity,
            unit: result.unit,
            totalGrams: result.totalGrams,
          );
      ref.invalidate(todayMealLogsProvider);
      ref.invalidate(dashboardProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.foodName} updated')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MealItemSummary item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete food?'),
        content: Text('${item.foodName} will be removed from $title.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NovaColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(nutritionRepositoryProvider).deleteMealItem(item.id);
      ref.invalidate(todayMealLogsProvider);
      ref.invalidate(dashboardProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.foodName} deleted')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}

class _MealMacroBadge extends StatelessWidget {
  const _MealMacroBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          '$label ${value.toStringAsFixed(0)}g',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MealItemTile extends StatelessWidget {
  const _MealItemTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final MealItemSummary item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final amount = item.grams > 0
        ? '${item.grams.toStringAsFixed(0)}g'
        : '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} ${item.unit}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(item.foodName),
      subtitle: Text(
        '$amount • P ${item.proteinG.toStringAsFixed(0)}g  '
        'C ${item.carbsG.toStringAsFixed(0)}g  '
        'F ${item.fatG.toStringAsFixed(0)}g',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.caloriesKcal.toStringAsFixed(0),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          PopupMenuButton<String>(
            tooltip: 'Food actions',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline, color: NovaColors.danger),
                  title: Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealItemEditResult {
  const _MealItemEditResult({
    required this.quantity,
    required this.unit,
    required this.totalGrams,
  });

  final double quantity;
  final String unit;
  final double? totalGrams;
}

class _MealItemEditSheet extends StatefulWidget {
  const _MealItemEditSheet({required this.item});

  final MealItemSummary item;

  @override
  State<_MealItemEditSheet> createState() => _MealItemEditSheetState();
}

class _MealItemEditSheetState extends State<_MealItemEditSheet> {
  late final TextEditingController _quantity;
  late final TextEditingController _grams;
  late String _unit;

  static const _units = [
    'grams',
    'serving',
    'piece',
    'cup',
    'tbsp',
    'tsp',
    'ml',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    _unit = _normalizedUnit(widget.item.unit);
    final quantity = widget.item.quantity > 0 ? widget.item.quantity : 1.0;
    _quantity = TextEditingController(text: _formatNumber(quantity));
    _grams = TextEditingController(
      text: widget.item.grams > 0 ? _formatNumber(widget.item.grams) : '',
    );
  }

  @override
  void dispose() {
    _quantity.dispose();
    _grams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: widget.item.foodName),
              const SizedBox(height: NovaSpacing.sm),
              Text(
                '${widget.item.caloriesKcal.toStringAsFixed(0)} kcal • '
                'P ${widget.item.proteinG.toStringAsFixed(0)}g  '
                'C ${widget.item.carbsG.toStringAsFixed(0)}g  '
                'F ${widget.item.fatG.toStringAsFixed(0)}g',
                style: const TextStyle(color: NovaColors.graphite),
              ),
              const SizedBox(height: NovaSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                  const SizedBox(width: NovaSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: [
                        for (final unit in _units)
                          DropdownMenuItem(
                            value: unit,
                            child: Text(_unitLabel(unit)),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _unit = value ?? _unit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NovaSpacing.md),
              TextField(
                controller: _grams,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Total grams',
                  prefixIcon: Icon(Icons.scale_outlined),
                  helperText: 'Choose grams for exact weight edits.',
                ),
              ),
              const SizedBox(height: NovaSpacing.lg),
              NovaButton.primary(
                label: 'Save changes',
                icon: Icons.check,
                onPressed: () {
                  final quantity = double.tryParse(_quantity.text.trim());
                  final grams = double.tryParse(_grams.text.trim());
                  if (quantity == null || quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a quantity greater than zero'),
                      ),
                    );
                    return;
                  }
                  if (_unit == 'custom' && (grams == null || grams <= 0)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Custom unit needs total grams'),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop(
                    _MealItemEditResult(
                      quantity: quantity,
                      unit: _unit,
                      totalGrams: grams != null && grams > 0 ? grams : null,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizedUnit(String unit) {
    if (unit == 'gram') return 'grams';
    if (_units.contains(unit)) return unit;
    return 'serving';
  }

  String _unitLabel(String unit) {
    return switch (unit) {
      'grams' => 'Grams',
      'tbsp' => 'Tablespoon',
      'tsp' => 'Teaspoon',
      'ml' => 'Milliliter',
      'custom' => 'Custom',
      _ => '${unit[0].toUpperCase()}${unit.substring(1)}',
    };
  }
}

String _formatNumber(double value) {
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
}

String _withMealType(String path, String mealType) {
  return Uri(path: path, queryParameters: {'meal_type': mealType}).toString();
}
