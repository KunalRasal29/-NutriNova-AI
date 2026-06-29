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
  final _query = TextEditingController(text: 'egg');
  final _quantity = TextEditingController(text: '2');
  final _grams = TextEditingController();
  String _unit = 'egg';
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
                      onTap: () => setState(() => _selectedFood = food),
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
          const SizedBox(height: NovaSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _mealType,
            decoration: const InputDecoration(labelText: 'Meal'),
            items: const [
              DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
              DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
              DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
              DropdownMenuItem(value: 'snack', child: Text('Snack')),
            ],
            onChanged: (value) =>
                setState(() => _mealType = value ?? _mealType),
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
    final effectiveGrams = grams ?? quantity * 50;
    final scale = effectiveGrams / 100;
    return MacroPreview(
      caloriesKcal: food.preview.caloriesKcal * scale,
      proteinG: food.preview.proteinG * scale,
      carbsG: food.preview.carbsG * scale,
      fatG: food.preview.fatG * scale,
    );
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
          Row(
            children: [
              CircleAvatar(
                backgroundColor: NovaColors.mint.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.local_fire_department,
                  color: NovaColors.mint,
                ),
              ),
              const SizedBox(width: NovaSpacing.md),
              Expanded(
                child: Text(
                  '${preview.caloriesKcal.toStringAsFixed(0)} kcal',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Wrap(
            spacing: NovaSpacing.sm,
            runSpacing: NovaSpacing.sm,
            children: [
              NovaBadge(
                label: 'Protein ${preview.proteinG.toStringAsFixed(1)}g',
                color: NovaColors.coral,
              ),
              NovaBadge(
                label: 'Carbs ${preview.carbsG.toStringAsFixed(1)}g',
                color: NovaColors.gold,
              ),
              NovaBadge(
                label: 'Fat ${preview.fatG.toStringAsFixed(1)}g',
                color: NovaColors.violet,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
