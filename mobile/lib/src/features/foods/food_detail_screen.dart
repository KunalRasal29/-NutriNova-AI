import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class FoodDetailScreen extends ConsumerStatefulWidget {
  const FoodDetailScreen({required this.foodId, super.key});

  final String foodId;

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  final _quantity = TextEditingController(text: '1');
  final _grams = TextEditingController();
  String _unit = 'serving';
  String _mealType = 'breakfast';
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
      padding: const EdgeInsets.all(NovaSpacing.lg),
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
          Text('${grams.toStringAsFixed(0)}g total'),
          const SizedBox(height: NovaSpacing.md),
          NutritionPreviewBar(
            caloriesKcal: preview.caloriesKcal,
            proteinG: preview.proteinG,
            carbsG: preview.carbsG,
            fatG: preview.fatG,
            compact: true,
          ),
        ],
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
