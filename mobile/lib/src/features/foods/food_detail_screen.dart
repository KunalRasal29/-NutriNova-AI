import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class FoodDetailScreen extends ConsumerStatefulWidget {
  const FoodDetailScreen({
    required this.foodId,
    super.key,
    this.initialMealType = 'breakfast',
  });

  final String foodId;
  final String initialMealType;

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  final _quantity = TextEditingController(text: '100');
  final _grams = TextEditingController();
  String _unit = 'gram';
  late String _mealType;
  String? _initializedFoodId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _grams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foodState = ref.watch(foodDetailProvider(widget.foodId));
    return NovaScaffold(
      title: 'Food detail',
      body: foodState.when(
        data: _buildFood,
        error: (error, _) => ErrorPanel(
          message: friendlyErrorMessage(error),
          onRetry: () => ref.invalidate(foodDetailProvider(widget.foodId)),
        ),
        loading: () => const LoadingList(),
      ),
    );
  }

  Widget _buildFood(FoodDetail food) {
    _hydrateDefaults(food);
    final quantity = double.tryParse(_quantity.text) ?? 1;
    final totalGrams = double.tryParse(_grams.text);
    final servingChoices = _servingChoicesFor(food);
    final selectedChoice = _choiceForUnit(servingChoices, _unit);
    final preview = food.previewFor(
      quantity: quantity,
      unit: _unit,
      totalGrams: totalGrams,
    );
    final effectiveGrams = food.effectiveGrams(
      quantity: quantity,
      unit: _unit,
      totalGrams: totalGrams,
    );
    final per100g = food.per100gPreview;
    final amountLabel = _amountLabel(
      quantity: quantity,
      unit: _unit,
      grams: effectiveGrams,
      choice: selectedChoice,
      override: totalGrams,
    );

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
              Text(
                food.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (food.brand.isNotEmpty) ...[
                const SizedBox(height: NovaSpacing.xs),
                Text(food.brand,
                    style: const TextStyle(color: NovaColors.graphite)),
              ],
              const SizedBox(height: NovaSpacing.md),
              SourceConfidenceBadges(
                source: food.sourceBadge,
                confidence: food.confidenceScore,
                verified: food.verified,
                classification: food.dataClassification,
              ),
              if (food.description.isNotEmpty) ...[
                const SizedBox(height: NovaSpacing.md),
                Text(food.description),
              ],
            ],
          ),
        ),
        const SizedBox(height: NovaSpacing.lg),
        NovaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Add to meal'),
              const SizedBox(height: NovaSpacing.md),
              MealTypeSelector(
                value: _mealType,
                onChanged: (value) => setState(() => _mealType = value),
              ),
              const SizedBox(height: NovaSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.numbers_outlined),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: NovaSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: [
                        for (final choice in servingChoices)
                          DropdownMenuItem(
                            value: choice.unit,
                            child: Text(choice.label),
                          ),
                      ],
                      onChanged: (value) => _changeUnit(value, food),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NovaSpacing.sm),
              _GramConversionLine(text: amountLabel),
              const SizedBox(height: NovaSpacing.md),
              TextField(
                controller: _grams,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Exact total grams',
                  helperText: 'Optional. Use this when you weighed the food.',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: NovaSpacing.lg),
        _NutritionPreview(
          preview: preview,
          per100g: per100g,
          grams: effectiveGrams,
          servingLabel: amountLabel,
        ),
        if (food.servings.isNotEmpty) ...[
          const SizedBox(height: NovaSpacing.lg),
          _ServingList(servings: food.servings),
        ],
        const SizedBox(height: NovaSpacing.lg),
        NovaButton.primary(
          label: _saving ? 'Saving...' : 'Add to ${_mealLabel(_mealType)}',
          icon: Icons.check,
          onPressed: _saving
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final router = GoRouter.of(context);
                  setState(() => _saving = true);
                  try {
                    await ref.read(nutritionRepositoryProvider).addManualFood(
                          foodId: food.id,
                          quantity: quantity,
                          unit: _unit,
                          mealType: _mealType,
                          totalGrams: totalGrams,
                        );
                    ref.invalidate(dashboardProvider);
                    ref.invalidate(todayMealLogsProvider);
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Added ${food.name} to ${_mealLabel(_mealType)}',
                        ),
                      ),
                    );
                    router.go('/meals');
                  } catch (error) {
                    if (!mounted) return;
                    setState(() => _saving = false);
                    messenger.showSnackBar(
                      SnackBar(content: Text(friendlyErrorMessage(error))),
                    );
                  }
                },
        ),
      ],
    );
  }

  void _hydrateDefaults(FoodDetail food) {
    if (_initializedFoodId == food.id) return;
    _initializedFoodId = food.id;
    final grams = food.defaultServingG <= 0 ? 100 : food.defaultServingG;
    _unit = grams > 0 ? 'serving' : 'gram';
    _quantity.text = _unit == 'serving'
        ? '1'
        : grams.toStringAsFixed(grams % 1 == 0 ? 0 : 1);
    _grams.clear();
  }

  void _changeUnit(String? value, FoodDetail food) {
    final next = value ?? _unit;
    setState(() {
      _unit = next;
      _grams.clear();
      if (next == 'gram') {
        final grams = food.defaultServingG <= 0 ? 100 : food.defaultServingG;
        _quantity.text = grams.toStringAsFixed(grams % 1 == 0 ? 0 : 1);
      } else {
        _quantity.text = '1';
      }
    });
  }
}

class _NutritionPreview extends StatelessWidget {
  const _NutritionPreview({
    required this.preview,
    required this.per100g,
    required this.grams,
    required this.servingLabel,
  });

  final MacroPreview preview;
  final MacroPreview per100g;
  final double grams;
  final String servingLabel;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Nutrition label'),
          const SizedBox(height: NovaSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: NovaColors.ink,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NovaColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(NovaSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selected serving',
                    style: TextStyle(
                      color: NovaColors.graphite,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: NovaSpacing.xs),
                  Text(
                    servingLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: NovaSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Text(
                          'Calories',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        preview.caloriesKcal.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          _NutritionLabelRows(preview: preview),
          const SizedBox(height: NovaSpacing.md),
          _Per100gSummary(preview: per100g),
          if (preview.carbsG == 0 &&
              (preview.proteinG > 0 || preview.fatG > 0)) ...[
            const SizedBox(height: NovaSpacing.md),
            const _NutritionNote(
              text:
                  '0g carbs is expected for plain meat, fish, eggs, and oils. It is not missing data unless the food has breading, sauce, or added ingredients.',
            ),
          ],
          if (preview.carbsG > 0 && preview.fiberG == 0) ...[
            const SizedBox(height: NovaSpacing.md),
            const _NutritionNote(
              text:
                  'Fiber can show as 0 when the source does not publish it. Calories and macros still come from the selected food record.',
            ),
          ],
        ],
      ),
    );
  }
}

class _GramConversionLine extends StatelessWidget {
  const _GramConversionLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.scale_outlined, color: NovaColors.graphite, size: 18),
        const SizedBox(width: NovaSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: NovaColors.graphite,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _NutritionLabelRows extends StatelessWidget {
  const _NutritionLabelRows({required this.preview});

  final MacroPreview preview;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _NutrientRowData('Protein', '${preview.proteinG.toStringAsFixed(1)}g'),
      _NutrientRowData('Total Carbs', '${preview.carbsG.toStringAsFixed(1)}g'),
      _NutrientRowData('Total Fat', '${preview.fatG.toStringAsFixed(1)}g'),
      _NutrientRowData('Fiber', '${preview.fiberG.toStringAsFixed(1)}g'),
      _NutrientRowData('Sugar', '${preview.sugarG.toStringAsFixed(1)}g'),
      _NutrientRowData('Sodium', '${preview.sodiumMg.toStringAsFixed(0)}mg'),
      if (preview.saturatedFatG > 0)
        _NutrientRowData(
          'Saturated Fat',
          '${preview.saturatedFatG.toStringAsFixed(1)}g',
        ),
      if (preview.calciumMg > 0)
        _NutrientRowData(
            'Calcium', '${preview.calciumMg.toStringAsFixed(0)}mg'),
      if (preview.ironMg > 0)
        _NutrientRowData('Iron', '${preview.ironMg.toStringAsFixed(1)}mg'),
      if (preview.potassiumMg > 0)
        _NutrientRowData(
          'Potassium',
          '${preview.potassiumMg.toStringAsFixed(0)}mg',
        ),
      if (preview.cholesterolMg > 0)
        _NutrientRowData(
          'Cholesterol',
          '${preview.cholesterolMg.toStringAsFixed(0)}mg',
        ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: NovaColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (final row in rows)
            _NutritionLabelRow(label: row.label, value: row.value),
        ],
      ),
    );
  }
}

class _NutritionLabelRow extends StatelessWidget {
  const _NutritionLabelRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: NovaColors.border, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NovaSpacing.md,
          vertical: NovaSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _Per100gSummary extends StatelessWidget {
  const _Per100gSummary({required this.preview});

  final MacroPreview preview;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NovaColors.panelRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NovaColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Per 100g reference',
              style: TextStyle(
                color: NovaColors.graphite,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: NovaSpacing.sm),
            Wrap(
              spacing: NovaSpacing.xs,
              runSpacing: NovaSpacing.xs,
              children: [
                NovaBadge(
                  label: '${preview.caloriesKcal.toStringAsFixed(0)} kcal',
                  color: NovaColors.blue,
                ),
                NovaBadge(
                  label: 'P ${preview.proteinG.toStringAsFixed(1)}g',
                  color: NovaColors.coral,
                ),
                NovaBadge(
                  label: 'C ${preview.carbsG.toStringAsFixed(1)}g',
                  color: NovaColors.gold,
                ),
                NovaBadge(
                  label: 'F ${preview.fatG.toStringAsFixed(1)}g',
                  color: NovaColors.violet,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrientRowData {
  const _NutrientRowData(this.label, this.value);

  final String label;
  final String value;
}

class _NutritionNote extends StatelessWidget {
  const _NutritionNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NovaColors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NovaColors.blue.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: NovaColors.blue, size: 20),
            const SizedBox(width: NovaSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServingChoice {
  const _ServingChoice({
    required this.unit,
    required this.label,
    required this.grams,
  });

  final String unit;
  final String label;
  final double grams;
}

List<_ServingChoice> _servingChoicesFor(FoodDetail food) {
  final choices = <_ServingChoice>[
    const _ServingChoice(unit: 'gram', label: 'Grams', grams: 1),
  ];
  final defaultServing = _defaultServing(food);
  final defaultGrams = defaultServing?.grams ??
      (food.defaultServingG > 0 ? food.defaultServingG : 100.0);
  if (defaultGrams > 0) {
    choices.add(
      _ServingChoice(
        unit: 'serving',
        label: defaultServing?.name ?? 'Serving',
        grams: defaultGrams,
      ),
    );
  }

  final text = [
    food.name,
    food.brand,
    for (final serving in food.servings) serving.name,
    for (final serving in food.servings) serving.householdQuantity,
  ].join(' ').toLowerCase();

  void addFromServing(String unit, String label, Set<String> aliases) {
    final serving = _servingMatching(food, aliases);
    if (serving != null) {
      choices
          .add(_ServingChoice(unit: unit, label: label, grams: serving.grams));
    }
  }

  addFromServing('egg', 'Egg', {'egg', 'eggs'});
  addFromServing('piece', 'Piece', {'piece', 'pieces', 'pc'});
  addFromServing('slice', 'Slice', {'slice', 'slices'});
  addFromServing('bowl', 'Bowl', {'bowl', 'katori'});
  addFromServing('cup', 'Cup', {'cup', 'cups'});
  addFromServing('scoop', 'Scoop', {'scoop'});

  if (text.contains('egg')) {
    choices.add(const _ServingChoice(unit: 'egg', label: 'Egg', grams: 50));
  }
  if (text.contains('whey') || text.contains('protein powder')) {
    choices.add(
      _ServingChoice(
        unit: 'scoop',
        label: 'Scoop',
        grams: defaultGrams > 0 ? defaultGrams : 30,
      ),
    );
  }
  if (text.contains('bread') || text.contains('cheese')) {
    choices.add(
      _ServingChoice(unit: 'slice', label: 'Slice', grams: defaultGrams),
    );
  }
  if (text.contains('banana') ||
      text.contains('apple') ||
      text.contains('orange') ||
      text.contains('tomato')) {
    choices.add(
      _ServingChoice(unit: 'piece', label: 'Piece', grams: defaultGrams),
    );
  }
  if (text.contains('cup')) {
    choices.add(const _ServingChoice(unit: 'cup', label: 'Cup', grams: 240));
  }
  if (text.contains('bowl') || text.contains('dal') || text.contains('curry')) {
    choices.add(
      _ServingChoice(unit: 'bowl', label: 'Bowl', grams: defaultGrams),
    );
  }

  final seen = <String>{};
  return [
    for (final choice in choices)
      if (seen.add(choice.unit)) choice,
  ];
}

FoodServingOption? _defaultServing(FoodDetail food) {
  for (final serving in food.servings) {
    if (serving.isDefault) return serving;
  }
  return food.servings.isEmpty ? null : food.servings.first;
}

FoodServingOption? _servingMatching(FoodDetail food, Set<String> aliases) {
  for (final serving in food.servings) {
    final text = '${serving.name} ${serving.householdQuantity}'.toLowerCase();
    if (aliases.any(text.contains)) return serving;
  }
  return null;
}

_ServingChoice _choiceForUnit(List<_ServingChoice> choices, String unit) {
  return choices.firstWhere(
    (choice) => choice.unit == unit,
    orElse: () => choices.first,
  );
}

String _amountLabel({
  required double quantity,
  required String unit,
  required double grams,
  required _ServingChoice choice,
  required double? override,
}) {
  final quantityText = _formatAmount(quantity);
  final gramsText = _formatAmount(grams);
  if (override != null && override > 0) {
    return '$quantityText ${choice.label.toLowerCase()} = ${gramsText}g exact';
  }
  if (unit == 'gram') return '${gramsText}g total';
  final perUnit = _formatAmount(choice.grams);
  return '$quantityText ${choice.label.toLowerCase()} x ${perUnit}g = ${gramsText}g';
}

String _formatAmount(double value) {
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}

String _mealLabel(String mealType) {
  return mealType
      .replaceAll('_', ' ')
      .split(' ')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _ServingList extends StatelessWidget {
  const _ServingList({required this.servings});

  final List<FoodServingOption> servings;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Known servings'),
          const SizedBox(height: NovaSpacing.sm),
          for (final serving in servings)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(serving.name),
              subtitle: serving.householdQuantity.isEmpty
                  ? null
                  : Text(serving.householdQuantity),
              trailing: Text('${serving.grams.toStringAsFixed(0)}g'),
            ),
        ],
      ),
    );
  }
}
