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

  static const _units = [
    'serving',
    'gram',
    'egg',
    'piece',
    'slice',
    'bowl',
    'cup',
    'glass',
    'tablespoon',
    'teaspoon',
    'handful',
    'scoop',
    'packet',
  ];

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
          message: error.toString(),
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
              const SectionHeader(title: 'Log amount'),
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
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      onChanged: (_) => setState(() {}),
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
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Override total grams',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: NovaSpacing.lg),
        _NutritionPreview(preview: preview, grams: effectiveGrams),
        if (food.servings.isNotEmpty) ...[
          const SizedBox(height: NovaSpacing.lg),
          _ServingList(servings: food.servings),
        ],
        const SizedBox(height: NovaSpacing.lg),
        NovaButton.primary(
          label: _saving ? 'Saving...' : 'Save to meal',
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
                      const SnackBar(content: Text('Meal item saved')),
                    );
                    router.go('/meals');
                  } catch (error) {
                    if (!mounted) return;
                    setState(() => _saving = false);
                    messenger.showSnackBar(
                      SnackBar(content: Text(error.toString())),
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
    _unit = 'gram';
    final grams = food.defaultServingG <= 0 ? 100 : food.defaultServingG;
    _quantity.text = grams.toStringAsFixed(grams % 1 == 0 ? 0 : 1);
    _grams.clear();
  }

  String _unitLabel(String unit) {
    return unit
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
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
                '${grams.toStringAsFixed(0)}g total',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.lg),
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
                label: 'Sugar',
                value: '${preview.sugarG.toStringAsFixed(1)}g',
                icon: Icons.cookie_outlined,
                color: NovaColors.gold,
              ),
              NutritionMetricItem(
                label: 'Sodium',
                value: '${preview.sodiumMg.toStringAsFixed(0)}mg',
                icon: Icons.science_outlined,
                color: NovaColors.blue,
              ),
              NutritionMetricItem(
                label: 'Sat fat',
                value: '${preview.saturatedFatG.toStringAsFixed(1)}g',
                icon: Icons.water_drop_outlined,
                color: NovaColors.violet,
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
