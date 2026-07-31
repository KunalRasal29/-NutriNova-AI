import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class RecipeBuilderScreen extends ConsumerStatefulWidget {
  const RecipeBuilderScreen({super.key});

  @override
  ConsumerState<RecipeBuilderScreen> createState() =>
      _RecipeBuilderScreenState();
}

class _RecipeBuilderScreenState extends ConsumerState<RecipeBuilderScreen> {
  final _name = TextEditingController(text: 'Paneer power bowl');
  final _servings = TextEditingController(text: '2');
  final _instructions = TextEditingController();
  final _search = TextEditingController(text: 'rice');
  final _ingredients = <_RecipeIngredientDraft>[];
  List<FoodSummary> _searchResults = [];
  Map<String, dynamic>? _calculation;
  String? _recipeId;
  String _mealType = 'lunch';
  bool _searching = false;
  bool _saving = false;
  bool _logging = false;

  static const _units = {
    'grams': 'Grams',
    'serving': 'Serving',
    'piece': 'Piece',
    'ml': 'Milliliter',
    'cup': 'Cup',
    'tbsp': 'Tablespoon',
    'tsp': 'Teaspoon',
  };

  @override
  void dispose() {
    _name.dispose();
    _servings.dispose();
    _instructions.dispose();
    _search.dispose();
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perServing =
        _calculation?['per_serving'] as Map<String, dynamic>? ?? const {};
    return NovaScaffold(
      title: 'Recipe builder',
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.lg),
        children: [
          const PageIntro(
            title: 'Build reusable meals',
            subtitle:
                'Create recipes from ingredients, calculate nutrition, then log the finished recipe as a meal.',
            icon: Icons.menu_book_outlined,
          ),
          const SizedBox(height: NovaSpacing.lg),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Recipe name'),
          ),
          const SizedBox(height: NovaSpacing.md),
          TextField(
            controller: _servings,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Servings'),
          ),
          const SizedBox(height: NovaSpacing.lg),
          _IngredientSearch(
            controller: _search,
            searching: _searching,
            results: _searchResults,
            onSearch: _searchFoods,
            onAdd: _addIngredient,
            onCreateCustom: () => context.push('/foods/custom'),
          ),
          const SizedBox(height: NovaSpacing.lg),
          _IngredientList(
            ingredients: _ingredients,
            units: _units,
            onChanged: () {
              setState(() {
                _calculation = null;
                _recipeId = null;
              });
            },
            onRemove: (ingredient) {
              setState(() {
                _ingredients.remove(ingredient);
                ingredient.dispose();
                _calculation = null;
                _recipeId = null;
              });
            },
          ),
          const SizedBox(height: NovaSpacing.lg),
          TextField(
            controller: _instructions,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Instructions'),
          ),
          const SizedBox(height: NovaSpacing.lg),
          _RecipePreview(perServing: perServing),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: _saving ? 'Saving...' : 'Save and calculate',
            icon: Icons.calculate_outlined,
            onPressed: _saving ? null : _saveAndCalculate,
          ),
          const SizedBox(height: NovaSpacing.md),
          MealTypeSelector(
            value: _mealType,
            onChanged: (value) => setState(() => _mealType = value),
          ),
          const SizedBox(height: NovaSpacing.md),
          NovaButton.secondary(
            label: _logging ? 'Logging...' : 'Log recipe as meal',
            icon: Icons.restaurant_menu,
            onPressed: _recipeId == null || _logging ? null : _logRecipeAsMeal,
          ),
        ],
      ),
    );
  }

  Future<void> _searchFoods() async {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final results =
          await ref.read(nutritionRepositoryProvider).searchFoods(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _searching = false);
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }

  void _addIngredient(FoodSummary food) {
    setState(() {
      _ingredients.add(_RecipeIngredientDraft(food));
      _calculation = null;
      _recipeId = null;
    });
  }

  Future<void> _saveAndCalculate() async {
    final messenger = ScaffoldMessenger.of(context);
    final validationMessage = _validationMessage();
    if (validationMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    setState(() => _saving = true);
    try {
      final recipe = await ref.read(nutritionRepositoryProvider).createRecipe({
        'name': _name.text.trim(),
        'servings': _servings.text.trim(),
        'visibility': 'private',
        'instructions': _instructions.text.trim(),
        'ingredients': [
          for (final ingredient in _ingredients)
            {
              'food': ingredient.food.id,
              'quantity': ingredient.quantity.text.trim(),
              'unit': ingredient.unit,
            },
        ],
      });
      final recipeId = recipe['id']?.toString() ?? '';
      if (recipeId.isEmpty) {
        throw Exception('Recipe saved without an id.');
      }
      final calculation =
          await ref.read(nutritionRepositoryProvider).calculateRecipe(recipeId);
      if (!mounted) return;
      setState(() {
        _recipeId = recipeId;
        _calculation = calculation;
        _saving = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Recipe saved and calculated')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }

  Future<void> _logRecipeAsMeal() async {
    final recipeId = _recipeId;
    if (recipeId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _logging = true);
    try {
      await ref.read(nutritionRepositoryProvider).logRecipeAsMeal(
            recipeId: recipeId,
            mealType: _mealType,
          );
      ref.invalidate(dashboardProvider);
      ref.invalidate(todayMealLogsProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Recipe logged as meal')),
      );
      context.go('/meals');
    } catch (error) {
      if (!mounted) return;
      setState(() => _logging = false);
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }

  String? _validationMessage() {
    if (_name.text.trim().isEmpty) return 'Enter a recipe name.';
    if ((double.tryParse(_servings.text.trim()) ?? 0) <= 0) {
      return 'Enter servings greater than 0.';
    }
    if (_ingredients.isEmpty) return 'Add at least one ingredient.';
    for (final ingredient in _ingredients) {
      if ((double.tryParse(ingredient.quantity.text.trim()) ?? 0) <= 0) {
        return 'Enter ingredient quantities greater than 0.';
      }
    }
    return null;
  }
}

class _IngredientSearch extends StatelessWidget {
  const _IngredientSearch({
    required this.controller,
    required this.searching,
    required this.results,
    required this.onSearch,
    required this.onAdd,
    required this.onCreateCustom,
  });

  final TextEditingController controller;
  final bool searching;
  final List<FoodSummary> results;
  final VoidCallback onSearch;
  final ValueChanged<FoodSummary> onAdd;
  final VoidCallback onCreateCustom;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Find ingredients'),
          const SizedBox(height: NovaSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Search foods',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: NovaSpacing.md),
              IconButton.filled(
                tooltip: 'Search foods',
                onPressed: searching ? null : onSearch,
                icon: searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.md),
          if (!searching && results.isEmpty)
            NovaButton.secondary(
              label: 'Create custom food',
              icon: Icons.add,
              onPressed: onCreateCustom,
            )
          else
            for (final food in results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(food.name),
                subtitle: food.brand.isEmpty
                    ? Text(
                        '${food.preview.caloriesKcal.toStringAsFixed(0)} kcal / 100g',
                      )
                    : Text(
                        '${food.brand} • ${food.preview.caloriesKcal.toStringAsFixed(0)} kcal / 100g',
                      ),
                trailing: IconButton(
                  tooltip: 'Add ingredient',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => onAdd(food),
                ),
              ),
        ],
      ),
    );
  }
}

class _IngredientList extends StatelessWidget {
  const _IngredientList({
    required this.ingredients,
    required this.units,
    required this.onChanged,
    required this.onRemove,
  });

  final List<_RecipeIngredientDraft> ingredients;
  final Map<String, String> units;
  final VoidCallback onChanged;
  final ValueChanged<_RecipeIngredientDraft> onRemove;

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) {
      return const NovaCard(
        child: EmptyState(
          title: 'No ingredients yet',
          message: 'Search for foods and add quantities to calculate a recipe.',
          icon: Icons.playlist_add,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Ingredients'),
        const SizedBox(height: NovaSpacing.sm),
        for (final ingredient in ingredients) ...[
          NovaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ingredient.food.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove ingredient',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onRemove(ingredient),
                    ),
                  ],
                ),
                if (ingredient.food.brand.isNotEmpty)
                  Text(
                    ingredient.food.brand,
                    style: const TextStyle(color: NovaColors.graphite),
                  ),
                const SizedBox(height: NovaSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ingredient.quantity,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Quantity'),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    const SizedBox(width: NovaSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: ingredient.unit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: [
                          for (final entry in units.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: (value) {
                          ingredient.unit = value ?? ingredient.unit;
                          onChanged();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: NovaSpacing.md),
        ],
      ],
    );
  }
}

class _RecipePreview extends StatelessWidget {
  const _RecipePreview({required this.perServing});

  final Map<String, dynamic> perServing;

  @override
  Widget build(BuildContext context) {
    final calories = _nutrient(perServing, 'calories', 'calories_kcal');
    final protein = _nutrient(perServing, 'protein_g');
    final carbs = _nutrient(perServing, 'carbs_g');
    final fat = _nutrient(perServing, 'fat_g');

    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Per serving preview'),
          const SizedBox(height: NovaSpacing.md),
          if (perServing.isEmpty)
            const Text('Save the recipe to calculate per-serving nutrition.')
          else
            NutritionPreviewBar(
              caloriesKcal: calories,
              proteinG: protein,
              carbsG: carbs,
              fatG: fat,
              compact: true,
            ),
        ],
      ),
    );
  }
}

class _RecipeIngredientDraft {
  _RecipeIngredientDraft(this.food)
      : quantity = TextEditingController(text: '100');

  final FoodSummary food;
  final TextEditingController quantity;
  String unit = 'grams';

  void dispose() => quantity.dispose();
}

double _nutrient(
  Map<String, dynamic> values,
  String key, [
  String? fallbackKey,
]) {
  final value =
      values[key] ?? (fallbackKey == null ? null : values[fallbackKey]);
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
