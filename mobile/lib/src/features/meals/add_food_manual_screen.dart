import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class AddFoodManualScreen extends ConsumerStatefulWidget {
  const AddFoodManualScreen({super.key, this.initialMealType = 'breakfast'});

  final String initialMealType;

  @override
  ConsumerState<AddFoodManualScreen> createState() =>
      _AddFoodManualScreenState();
}

class _AddFoodManualScreenState extends ConsumerState<AddFoodManualScreen> {
  final _query = TextEditingController();
  final _quantity = TextEditingController(text: '100');
  final _grams = TextEditingController();
  String _unit = 'gram';
  late String _mealType;
  FoodSummary? _selectedFood;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType;
  }

  @override
  void dispose() {
    _query.dispose();
    _quantity.dispose();
    _grams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(foodSearchProvider(_query.text));
    final quantity = double.tryParse(_quantity.text) ?? 1;
    final totalGrams = double.tryParse(_grams.text);
    final unitChoices = _unitChoicesFor(_selectedFood);
    final selectedChoice = _choiceForUnit(unitChoices, _unit);
    final effectiveGrams = _selectedFood == null
        ? 0.0
        : totalGrams ??
            _estimatedGrams(_selectedFood!, quantity, selectedChoice);
    final preview = _selectedFood == null
        ? null
        : _previewFor(_selectedFood!, effectiveGrams);

    return NovaScaffold(
      title: 'Manual add',
      actions: [
        IconButton(
          tooltip: 'Create custom food',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () =>
              context.push(_withMealType('/foods/custom', _mealType)),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.lg),
        children: [
          TextField(
            controller: _query,
            decoration: const InputDecoration(
              labelText: 'Search food database',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: NovaSpacing.md),
          const SectionHeader(title: 'Meal for this food'),
          const SizedBox(height: NovaSpacing.sm),
          MealTypeSelector(
            value: _mealType,
            onChanged: (value) => setState(() => _mealType = value),
          ),
          const SizedBox(height: NovaSpacing.md),
          SizedBox(
            height: 190,
            child: foods.when(
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    title: 'No foods found',
                    message:
                        'Try another search or create a private custom food.',
                    icon: Icons.search_off,
                  );
                }
                return ListView.separated(
                  itemBuilder: (_, index) {
                    final food = items[index];
                    final selected = _selectedFood?.id == food.id;
                    return ListTile(
                      selected: selected,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected ? NovaColors.mint : NovaColors.graphite,
                      ),
                      title: Text(food.name),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: NovaSpacing.xs),
                        child: SourceConfidenceBadges(
                          source: food.sourceBadge,
                          confidence: food.confidenceScore,
                          verified: food.verified,
                          classification: food.dataClassification,
                        ),
                      ),
                      trailing: Text(
                        '${food.preview.caloriesKcal.toStringAsFixed(0)} kcal',
                      ),
                      onTap: () => setState(() {
                        _selectedFood = food;
                        _unit =
                            food.defaultServingGrams > 0 ? 'serving' : 'gram';
                        _quantity.text = _unit == 'serving' ? '1' : '100';
                        _grams.clear();
                      }),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: items.length,
                );
              },
              error: (error, _) => Text(friendlyErrorMessage(error)),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
          const SizedBox(height: NovaSpacing.md),
          if (_selectedFood != null) ...[
            NovaCard(
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: NovaColors.mint),
                  const SizedBox(width: NovaSpacing.md),
                  Expanded(
                    child: Text(
                      _selectedFood!.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(
                      _withMealType('/foods/${_selectedFood!.id}', _mealType),
                    ),
                    child: const Text('Details'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NovaSpacing.md),
          ],
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
                    for (final choice in unitChoices)
                      DropdownMenuItem(
                        value: choice.unit,
                        child: Text(choice.label),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _unit = value ?? _unit;
                    _quantity.text = _unit == 'gram' ? '100' : '1';
                    _grams.clear();
                  }),
                ),
              ),
            ],
          ),
          if (_selectedFood != null) ...[
            const SizedBox(height: NovaSpacing.sm),
            _GramConversionLine(
              text: _amountLabel(
                quantity: quantity,
                choice: selectedChoice,
                grams: effectiveGrams,
                override: totalGrams,
              ),
            ),
          ],
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
          const SizedBox(height: NovaSpacing.lg),
          if (preview != null)
            _NutritionPreview(preview: preview, grams: effectiveGrams),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: _saving ? 'Saving...' : 'Add to ${_mealLabel(_mealType)}',
            icon: Icons.check,
            onPressed: _selectedFood == null || _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await ref.read(nutritionRepositoryProvider).addManualFood(
                            foodId: _selectedFood!.id,
                            quantity: quantity,
                            unit: _unit,
                            mealType: _mealType,
                            totalGrams: _totalGramsForSave(
                              override: totalGrams,
                            ),
                          );
                      ref.invalidate(dashboardProvider);
                      ref.invalidate(todayMealLogsProvider);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Added ${_selectedFood!.name} to ${_mealLabel(_mealType)}',
                          ),
                        ),
                      );
                      context.go('/meals');
                    } catch (error) {
                      if (!context.mounted) return;
                      setState(() => _saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(friendlyErrorMessage(error))),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }

  double? _totalGramsForSave({
    required double? override,
  }) {
    if (override != null && override > 0) return override;
    return null;
  }

  MacroPreview _previewFor(FoodSummary food, double effectiveGrams) {
    final scale = effectiveGrams / 100;
    return MacroPreview(
      caloriesKcal: food.preview.caloriesKcal * scale,
      proteinG: food.preview.proteinG * scale,
      carbsG: food.preview.carbsG * scale,
      fatG: food.preview.fatG * scale,
      fiberG: food.preview.fiberG * scale,
      sugarG: food.preview.sugarG * scale,
      sodiumMg: food.preview.sodiumMg * scale,
      calciumMg: food.preview.calciumMg * scale,
      ironMg: food.preview.ironMg * scale,
      potassiumMg: food.preview.potassiumMg * scale,
      cholesterolMg: food.preview.cholesterolMg * scale,
      saturatedFatG: food.preview.saturatedFatG * scale,
    );
  }

  double _estimatedGrams(
    FoodSummary food,
    double quantity,
    _UnitChoice selectedChoice,
  ) {
    if (_unit == 'gram') return quantity;
    return quantity * selectedChoice.grams;
  }
}

String _withMealType(String path, String mealType) {
  return Uri(path: path, queryParameters: {'meal_type': mealType}).toString();
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

class _UnitChoice {
  const _UnitChoice({
    required this.unit,
    required this.label,
    required this.grams,
  });

  final String unit;
  final String label;
  final double grams;
}

List<_UnitChoice> _unitChoicesFor(FoodSummary? food) {
  if (food == null) {
    return const [
      _UnitChoice(unit: 'gram', label: 'Grams', grams: 1),
      _UnitChoice(unit: 'serving', label: 'Serving', grams: 100),
    ];
  }
  final name = food.name.toLowerCase();
  final serving = food.servingSummary.toLowerCase();
  final defaultGrams =
      food.defaultServingGrams > 0 ? food.defaultServingGrams : 100.0;
  final choices = <_UnitChoice>[
    const _UnitChoice(unit: 'gram', label: 'Grams', grams: 1),
    _UnitChoice(unit: 'serving', label: 'Serving', grams: defaultGrams),
  ];

  if (name.contains('chapati') ||
      name.contains('roti') ||
      name.contains('phulka')) {
    choices.add(
      _UnitChoice(
        unit: 'piece',
        label: 'Chapati / roti',
        grams: defaultGrams,
      ),
    );
  }
  if (name.contains('egg') || serving.contains('egg')) {
    choices.add(const _UnitChoice(unit: 'egg', label: 'Egg', grams: 50));
  }
  if (name.contains('banana') ||
      name.contains('apple') ||
      name.contains('orange') ||
      name.contains('tomato') ||
      serving.contains('piece')) {
    choices
        .add(_UnitChoice(unit: 'piece', label: 'Piece', grams: defaultGrams));
  }
  if (serving.contains('slice') ||
      name.contains('bread') ||
      name.contains('cheese')) {
    choices
        .add(_UnitChoice(unit: 'slice', label: 'Slice', grams: defaultGrams));
  }
  if (serving.contains('bowl') ||
      serving.contains('katori') ||
      name.contains('dal') ||
      name.contains('curry')) {
    choices.add(_UnitChoice(unit: 'bowl', label: 'Bowl', grams: defaultGrams));
  }
  if (serving.contains('cup') ||
      name.contains('rice') ||
      name.contains('oats') ||
      name.contains('curd')) {
    choices.add(const _UnitChoice(unit: 'cup', label: 'Cup', grams: 240));
  }
  if (name.contains('whey') ||
      name.contains('protein powder') ||
      serving.contains('scoop')) {
    choices.add(
      _UnitChoice(
        unit: 'scoop',
        label: 'Scoop',
        grams: defaultGrams > 0 ? defaultGrams : 30,
      ),
    );
  }
  if (name.contains('milk') ||
      name.contains('juice') ||
      name.contains('water') ||
      name.contains('drink') ||
      name.contains('soup')) {
    choices.add(const _UnitChoice(unit: 'ml', label: 'Millilitres', grams: 1));
    choices.add(const _UnitChoice(unit: 'glass', label: 'Glass', grams: 240));
  }
  if (name.contains('oil') ||
      name.contains('ghee') ||
      name.contains('sauce') ||
      serving.contains('tablespoon')) {
    choices.add(
      const _UnitChoice(
        unit: 'tablespoon',
        label: 'Tablespoon',
        grams: 15,
      ),
    );
    choices.add(
      const _UnitChoice(unit: 'teaspoon', label: 'Teaspoon', grams: 5),
    );
  }
  if (food.brand.isNotEmpty || food.preparationState == 'as_sold') {
    choices.add(
      _UnitChoice(unit: 'packet', label: 'Packet', grams: defaultGrams),
    );
  }

  final seen = <String>{};
  return [
    for (final choice in choices)
      if (seen.add(choice.unit))
        _UnitChoice(
          unit: choice.unit,
          label: food.personalPortionGrams.containsKey(choice.unit)
              ? '${choice.label} (your usual)'
              : choice.label,
          grams: food.personalPortionGrams[choice.unit] ?? choice.grams,
        ),
  ];
}

_UnitChoice _choiceForUnit(List<_UnitChoice> choices, String unit) {
  return choices.firstWhere(
    (choice) => choice.unit == unit,
    orElse: () => choices.first,
  );
}

String _amountLabel({
  required double quantity,
  required _UnitChoice choice,
  required double grams,
  required double? override,
}) {
  final quantityText = _formatAmount(quantity);
  final gramsText = _formatAmount(grams);
  if (override != null && override > 0) {
    return '$quantityText ${choice.label.toLowerCase()} = ${gramsText}g exact';
  }
  if (choice.unit == 'gram') return '${gramsText}g total';
  final perUnit = _formatAmount(choice.grams);
  final estimated = {
    'bowl',
    'cup',
    'glass',
    'tablespoon',
    'teaspoon',
  }.contains(choice.unit);
  final suffix = estimated ? ' estimate — confirm grams if possible' : '';
  return '$quantityText ${choice.label.toLowerCase()} x ${perUnit}g = '
      '${gramsText}g$suffix';
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

class _NutritionPreview extends StatelessWidget {
  const _NutritionPreview({required this.preview, required this.grams});

  final MacroPreview preview;
  final double grams;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Nutrition preview'),
          const SizedBox(height: NovaSpacing.md),
          Row(
            children: [
              const Icon(Icons.scale_outlined, color: NovaColors.graphite),
              const SizedBox(width: NovaSpacing.sm),
              Text(
                '${_formatAmount(grams)}g selected',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                '${preview.caloriesKcal.toStringAsFixed(0)} kcal',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.md),
          NutritionMetricGrid(
            items: [
              NutritionMetricItem(
                label: 'Protein',
                value: '${preview.proteinG.toStringAsFixed(1)}g',
                icon: Icons.fitness_center,
                color: NovaColors.coral,
              ),
              NutritionMetricItem(
                label: 'Carbs',
                value: '${preview.carbsG.toStringAsFixed(1)}g',
                icon: Icons.grain,
                color: NovaColors.gold,
              ),
              NutritionMetricItem(
                label: 'Fat',
                value: '${preview.fatG.toStringAsFixed(1)}g',
                icon: Icons.opacity,
                color: NovaColors.violet,
              ),
              NutritionMetricItem(
                label: 'Fiber',
                value: '${preview.fiberG.toStringAsFixed(1)}g',
                icon: Icons.grass_outlined,
                color: NovaColors.lime,
              ),
              NutritionMetricItem(
                label: 'Sodium',
                value: '${preview.sodiumMg.toStringAsFixed(0)}mg',
                icon: Icons.science_outlined,
                color: NovaColors.blue,
              ),
              NutritionMetricItem(
                label: 'Sugar',
                value: '${preview.sugarG.toStringAsFixed(1)}g',
                icon: Icons.cookie_outlined,
                color: NovaColors.gold,
              ),
              if (preview.calciumMg > 0)
                NutritionMetricItem(
                  label: 'Calcium',
                  value: '${preview.calciumMg.toStringAsFixed(0)}mg',
                  icon: Icons.health_and_safety_outlined,
                  color: NovaColors.mint,
                ),
              if (preview.ironMg > 0)
                NutritionMetricItem(
                  label: 'Iron',
                  value: '${preview.ironMg.toStringAsFixed(1)}mg',
                  icon: Icons.bloodtype_outlined,
                  color: NovaColors.coral,
                ),
              if (preview.potassiumMg > 0)
                NutritionMetricItem(
                  label: 'Potassium',
                  value: '${preview.potassiumMg.toStringAsFixed(0)}mg',
                  icon: Icons.bolt_outlined,
                  color: NovaColors.lime,
                ),
            ],
          ),
          if (preview.carbsG == 0 &&
              (preview.proteinG > 0 || preview.fatG > 0)) ...[
            const SizedBox(height: NovaSpacing.md),
            const _NutritionNote(
              text:
                  '0g carbs can be correct for plain meat, fish, eggs, or oils. Add sauces, breading, or sides separately if they were part of the meal.',
            ),
          ],
        ],
      ),
    );
  }
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
