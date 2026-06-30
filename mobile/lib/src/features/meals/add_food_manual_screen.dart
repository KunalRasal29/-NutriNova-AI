import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class AddFoodManualScreen extends ConsumerStatefulWidget {
  const AddFoodManualScreen({super.key});

  @override
  ConsumerState<AddFoodManualScreen> createState() =>
      _AddFoodManualScreenState();
}

class _AddFoodManualScreenState extends ConsumerState<AddFoodManualScreen> {
  final _query = TextEditingController();
  final _quantity = TextEditingController(text: '100');
  final _grams = TextEditingController();
  String _unit = 'gram';
  String _mealType = 'breakfast';
  FoodSummary? _selectedFood;
  bool _saving = false;

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
    final preview = _selectedFood == null
        ? null
        : _previewFor(_selectedFood!, quantity, totalGrams);

    return NovaScaffold(
      title: 'Manual add',
      actions: [
        IconButton(
          tooltip: 'Create custom food',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => context.go('/foods/custom'),
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
          const SectionHeader(title: 'Meal'),
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
                        if (_unit == 'egg' &&
                            !food.name.toLowerCase().contains('egg')) {
                          _unit = 'gram';
                          _quantity.text = '100';
                        }
                      }),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: items.length,
                );
              },
              error: (error, _) => Text(error.toString()),
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
                    onPressed: () => context.go('/foods/${_selectedFood!.id}'),
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
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: NovaSpacing.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: const [
                    DropdownMenuItem(value: 'egg', child: Text('Egg')),
                    DropdownMenuItem(value: 'serving', child: Text('Serving')),
                    DropdownMenuItem(value: 'gram', child: Text('Gram')),
                    DropdownMenuItem(value: 'piece', child: Text('Piece')),
                    DropdownMenuItem(value: 'bowl', child: Text('Bowl')),
                    DropdownMenuItem(value: 'cup', child: Text('Cup')),
                    DropdownMenuItem(value: 'scoop', child: Text('Scoop')),
                  ],
                  onChanged: (value) => setState(() => _unit = value ?? _unit),
                ),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.md),
          TextField(
            controller: _grams,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Override grams',
              prefixIcon: Icon(Icons.scale_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: NovaSpacing.lg),
          if (preview != null) _NutritionPreview(preview: preview),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: _saving ? 'Saving...' : 'Save meal item',
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
                            totalGrams: totalGrams,
                          );
                      ref.invalidate(dashboardProvider);
                      ref.invalidate(todayMealLogsProvider);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Meal item saved')),
                      );
                      context.go('/meals');
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

  MacroPreview _previewFor(FoodSummary food, double quantity, double? grams) {
    final effectiveGrams = grams ?? _estimatedGrams(food, quantity);
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

  double _estimatedGrams(FoodSummary food, double quantity) {
    if (_unit == 'gram') return quantity;
    final name = food.name.toLowerCase();
    var perUnit = 100.0;
    if (_unit == 'egg') {
      perUnit = 50;
    } else if (_unit == 'piece' && name.contains('banana')) {
      perUnit = 118;
    } else if (_unit == 'piece' && name.contains('chapati')) {
      perUnit = 45;
    } else if (_unit == 'bowl') {
      perUnit = 240;
    } else if (_unit == 'cup') {
      perUnit = 150;
    } else if (_unit == 'scoop') {
      perUnit = 30;
    }
    return quantity * perUnit;
  }
}

class _NutritionPreview extends StatelessWidget {
  const _NutritionPreview({required this.preview});

  final MacroPreview preview;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Nutrition preview'),
          const SizedBox(height: NovaSpacing.md),
          NutritionMetricGrid(
            items: [
              NutritionMetricItem(
                label: 'Calories',
                value: '${preview.caloriesKcal.toStringAsFixed(0)} kcal',
                icon: Icons.local_fire_department,
                color: NovaColors.mint,
              ),
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
