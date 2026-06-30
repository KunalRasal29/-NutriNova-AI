import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key, this.initialMealType = 'lunch'});

  final String initialMealType;

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _query = TextEditingController();
  late String _mealType;

  static const _suggestions = [
    'chicken breast',
    'boiled eggs',
    'rice',
    'chapati',
    'banana',
    'dal',
    'paneer',
    'curd',
    'oats',
    'whey protein',
  ];

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(foodSearchProvider(_query.text));
    final recentFoods = _recentFoodNames(
      ref.watch(todayMealLogsProvider).valueOrNull ?? const [],
    );
    return NovaScaffold(
      title: 'Add Food',
      actions: [
        IconButton(
          tooltip: 'Create custom food',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () =>
              context.go(_withMealType('/foods/custom', _mealType)),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(NovaSpacing.lg),
            child: Column(
              children: [
                MealTypeSelector(
                  value: _mealType,
                  onChanged: (value) => setState(() => _mealType = value),
                ),
                const SizedBox(height: NovaSpacing.md),
                TextField(
                  controller: _query,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search foods, brands, meals...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: NovaSpacing.md),
                const _FoodSearchTabs(),
                const SizedBox(height: NovaSpacing.md),
                _SearchShortcuts(mealType: _mealType),
              ],
            ),
          ),
          Expanded(
            child: _query.text.trim().isEmpty
                ? _SuggestionList(
                    recentFoods: recentFoods,
                    suggestions: _suggestions,
                    onPick: (value) => setState(() => _query.text = value),
                  )
                : foods.when(
                    data: (items) => _FoodResults(
                      items: items,
                      query: _query.text,
                      mealType: _mealType,
                      onCreateCustom: () =>
                          context.go(_withMealType('/foods/custom', _mealType)),
                    ),
                    error: (error, _) => ErrorPanel(
                      message: error.toString(),
                      onRetry: () =>
                          ref.invalidate(foodSearchProvider(_query.text)),
                    ),
                    loading: () => const LoadingList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FoodSearchTabs extends StatelessWidget {
  const _FoodSearchTabs();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _TabLabel(label: 'All', selected: true),
        _TabLabel(label: 'My Meals'),
        _TabLabel(label: 'My Recipes'),
        _TabLabel(label: 'My Foods'),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: NovaSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : NovaColors.graphite,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 3,
            width: selected ? 28 : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchShortcuts extends StatelessWidget {
  const _SearchShortcuts({required this.mealType});

  final String mealType;

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      (Icons.qr_code_scanner, 'Barcode', '/barcode'),
      (Icons.mic_none_outlined, 'Voice log', '/meals/quick-add'),
      (Icons.camera_alt_outlined, 'Meal scan', '/photos/scan'),
      (Icons.flash_on_outlined, 'Quick add', '/meals/quick-add'),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: NovaSpacing.sm,
      mainAxisSpacing: NovaSpacing.sm,
      childAspectRatio: 1.05,
      children: [
        for (final shortcut in shortcuts)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.go(_withMealType(shortcut.$3, mealType)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: NovaColors.panel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NovaColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(shortcut.$1, color: NovaColors.blue),
                  const SizedBox(height: NovaSpacing.xs),
                  Text(
                    shortcut.$2,
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
          ),
      ],
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.recentFoods,
    required this.suggestions,
    required this.onPick,
  });

  final List<String> recentFoods;
  final List<String> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
      children: [
        if (recentFoods.isNotEmpty) ...[
          const Text(
            'Recently Logged',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: NovaSpacing.md),
          for (final food in recentFoods)
            _SuggestionTile(
              label: food,
              icon: Icons.history,
              onTap: () => onPick(food),
            ),
          const SizedBox(height: NovaSpacing.xl),
        ],
        const Text(
          'Suggested Searches',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: NovaSpacing.md),
        for (final suggestion in suggestions)
          _SuggestionTile(
            label: suggestion,
            icon: Icons.search,
            onTap: () => onPick(suggestion),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: NovaColors.blue,
            child: Icon(Icons.add, color: Colors.white),
          ),
          title: const Text(
            'Create a custom food',
            style:
                TextStyle(color: NovaColors.blue, fontWeight: FontWeight.w900),
          ),
          onTap: () => context.go('/foods/custom'),
        ),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: NovaColors.panel,
        child: Icon(icon, color: NovaColors.graphite),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      onTap: onTap,
    );
  }
}

class _FoodResults extends StatelessWidget {
  const _FoodResults({
    required this.items,
    required this.query,
    required this.mealType,
    required this.onCreateCustom,
  });

  final List<FoodSummary> items;
  final String query;
  final String mealType;
  final VoidCallback onCreateCustom;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
        children: [
          NovaCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyState(
                  title: 'No foods found',
                  message: 'Create it once and it will be available next time.',
                  icon: Icons.search_off,
                ),
                NovaButton.primary(
                  label: 'Create custom',
                  icon: Icons.add,
                  onPressed: onCreateCustom,
                ),
              ],
            ),
          ),
        ],
      );
    }
    final best = items.first;
    final rest = items.skip(1).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
      children: [
        const Text(
          'Best Match',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: NovaSpacing.md),
        _FoodResultTile(food: best, mealType: mealType, highlighted: true),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: NovaSpacing.xl),
          const Text(
            'More Results',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: NovaSpacing.md),
          for (final food in rest) ...[
            _FoodResultTile(food: food, mealType: mealType),
            const SizedBox(height: NovaSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _FoodResultTile extends StatelessWidget {
  const _FoodResultTile({
    required this.food,
    required this.mealType,
    this.highlighted = false,
  });

  final FoodSummary food;
  final String mealType;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      color: highlighted ? NovaColors.panelRaised : NovaColors.panel,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.go(
                _withMealType('/foods/${food.id}', mealType),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          food.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (food.verified) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified,
                          color: NovaColors.mint,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${food.preview.caloriesKcal.toStringAsFixed(0)} cal, '
                    '${food.brand.isEmpty ? '100 g' : food.brand}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NovaColors.graphite,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: NovaSpacing.sm),
                  Wrap(
                    spacing: NovaSpacing.xs,
                    runSpacing: NovaSpacing.xs,
                    children: [
                      NovaBadge(
                        label: 'P ${food.preview.proteinG.toStringAsFixed(0)}g',
                        color: NovaColors.coral,
                      ),
                      NovaBadge(
                        label: 'C ${food.preview.carbsG.toStringAsFixed(0)}g',
                        color: NovaColors.gold,
                      ),
                      NovaBadge(
                        label: 'F ${food.preview.fatG.toStringAsFixed(0)}g',
                        color: NovaColors.violet,
                      ),
                      if (food.preview.fiberG > 0)
                        NovaBadge(
                          label:
                              'Fiber ${food.preview.fiberG.toStringAsFixed(0)}g',
                          color: NovaColors.lime,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: NovaSpacing.md),
          IconButton.filled(
            tooltip: 'Add food',
            icon: const Icon(Icons.add),
            onPressed: () => context.go(
              _withMealType('/foods/${food.id}', mealType),
            ),
          ),
        ],
      ),
    );
  }
}

String _withMealType(String path, String mealType) {
  return Uri(path: path, queryParameters: {'meal_type': mealType}).toString();
}

List<String> _recentFoodNames(List<MealLogSummary> logs) {
  final names = <String>[];
  final seen = <String>{};
  for (final log in logs.reversed) {
    for (final item in log.items.reversed) {
      final name = item.foodName.trim();
      final key = name.toLowerCase();
      if (name.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      names.add(name);
      if (names.length == 5) return names;
    }
  }
  return names;
}
