import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
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
  FoodSearchTab _tab = FoodSearchTab.all;

  static const _suggestions = [
    'chicken breast',
    'tandoori chicken',
    'butter chicken',
    'boiled eggs',
    'egg bhurji',
    'rice',
    'chapati',
    'khichdi',
    'banana',
    'dal',
    'paneer',
    'besan chilla',
    'sprouts',
    'curd',
    'oats',
    'whey protein',
    'protein shake',
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
    final query = _query.text.trim();
    final foods = ref.watch(foodSearchProvider(query));
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
                _FoodSearchTabs(
                  value: _tab,
                  onChanged: (tab) => setState(() => _tab = tab),
                ),
                const SizedBox(height: NovaSpacing.md),
                _SearchShortcuts(mealType: _mealType),
              ],
            ),
          ),
          Expanded(
            child: _contentForTab(context, query, foods),
          ),
        ],
      ),
    );
  }

  Widget _contentForTab(
    BuildContext context,
    String query,
    AsyncValue<List<FoodSummary>> foods,
  ) {
    if (_tab == FoodSearchTab.all) {
      if (query.isEmpty) {
        return _FoodHomeList(
          recentState: ref.watch(recentFoodsProvider),
          frequentState: ref.watch(frequentFoodsProvider),
          suggestions: _suggestions,
          mealType: _mealType,
          onPick: (value) => setState(() => _query.text = value),
          onCreateCustom: () =>
              context.go(_withMealType('/foods/custom', _mealType)),
          onFoodChanged: _refreshFoodState,
        );
      }
      return foods.when(
        data: (items) => _FoodResults(
          items: items,
          query: query,
          mealType: _mealType,
          title: 'Best Match',
          showBestMatch: true,
          emptyTitle: 'No foods found',
          emptyMessage: 'Create it once and it will be available next time.',
          onCreateCustom: () =>
              context.go(_withMealType('/foods/custom', _mealType)),
          onFoodChanged: _refreshFoodState,
        ),
        error: (error, _) => ErrorPanel(
          message: error.toString(),
          onRetry: () => ref.invalidate(foodSearchProvider(query)),
        ),
        loading: () => const LoadingList(),
      );
    }

    final tabState = switch (_tab) {
      FoodSearchTab.recent => ref.watch(recentFoodsProvider),
      FoodSearchTab.frequent => ref.watch(frequentFoodsProvider),
      FoodSearchTab.favorites => ref.watch(favoriteFoodsProvider),
      FoodSearchTab.myFoods => ref.watch(myFoodsProvider),
      FoodSearchTab.all => foods,
    };
    return _FoodAsyncResults(
      state: tabState,
      query: query,
      mealType: _mealType,
      title: _tab.title,
      emptyTitle: _tab.emptyTitle,
      emptyMessage: _tab.emptyMessage,
      onCreateCustom: () =>
          context.go(_withMealType('/foods/custom', _mealType)),
      onFoodChanged: _refreshFoodState,
    );
  }

  void _refreshFoodState() {
    ref.invalidate(dashboardProvider);
    ref.invalidate(todayMealLogsProvider);
    ref.invalidate(recentFoodsProvider);
    ref.invalidate(frequentFoodsProvider);
    ref.invalidate(favoriteFoodsProvider);
    ref.invalidate(myFoodsProvider);
    final query = _query.text.trim();
    if (query.isNotEmpty) {
      ref.invalidate(foodSearchProvider(query));
    }
  }
}

enum FoodSearchTab {
  all,
  recent,
  frequent,
  favorites,
  myFoods;

  String get title => switch (this) {
        FoodSearchTab.all => 'All',
        FoodSearchTab.recent => 'Recent',
        FoodSearchTab.frequent => 'Frequent',
        FoodSearchTab.favorites => 'Favorites',
        FoodSearchTab.myFoods => 'My Foods',
      };

  String get emptyTitle => switch (this) {
        FoodSearchTab.all => 'No foods found',
        FoodSearchTab.recent => 'No recent foods',
        FoodSearchTab.frequent => 'No frequent foods',
        FoodSearchTab.favorites => 'No favorites yet',
        FoodSearchTab.myFoods => 'No custom foods yet',
      };

  String get emptyMessage => switch (this) {
        FoodSearchTab.all =>
          'Create it once and it will be available next time.',
        FoodSearchTab.recent => 'Foods appear here after you log them.',
        FoodSearchTab.frequent => 'Foods you log often will appear here.',
        FoodSearchTab.favorites => 'Tap the star on any food to save it here.',
        FoodSearchTab.myFoods =>
          'Create custom foods for private recipes or labels.',
      };
}

class _FoodSearchTabs extends StatelessWidget {
  const _FoodSearchTabs({required this.value, required this.onChanged});

  final FoodSearchTab value;
  final ValueChanged<FoodSearchTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in FoodSearchTab.values)
            _TabLabel(
              label: tab.title,
              selected: tab == value,
              onTap: () => onChanged(tab),
            ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 3,
              width: selected ? 28 : 0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
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

class _FoodHomeList extends StatelessWidget {
  const _FoodHomeList({
    required this.recentState,
    required this.frequentState,
    required this.suggestions,
    required this.mealType,
    required this.onPick,
    required this.onCreateCustom,
    required this.onFoodChanged,
  });

  final AsyncValue<List<FoodSummary>> recentState;
  final AsyncValue<List<FoodSummary>> frequentState;
  final List<String> suggestions;
  final String mealType;
  final ValueChanged<String> onPick;
  final VoidCallback onCreateCustom;
  final VoidCallback onFoodChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
      children: [
        _FoodHomeSection(
          title: 'Recently Logged',
          emptyText: 'Log a food once and it will appear here.',
          state: recentState,
          mealType: mealType,
          onFoodChanged: onFoodChanged,
        ),
        const SizedBox(height: NovaSpacing.xl),
        _FoodHomeSection(
          title: 'Frequent Foods',
          emptyText: 'Foods you log often will show up here.',
          state: frequentState,
          mealType: mealType,
          onFoodChanged: onFoodChanged,
        ),
        const SizedBox(height: NovaSpacing.xl),
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
          onTap: onCreateCustom,
        ),
      ],
    );
  }
}

class _FoodHomeSection extends StatelessWidget {
  const _FoodHomeSection({
    required this.title,
    required this.emptyText,
    required this.state,
    required this.mealType,
    required this.onFoodChanged,
  });

  final String title;
  final String emptyText;
  final AsyncValue<List<FoodSummary>> state;
  final String mealType;
  final VoidCallback onFoodChanged;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: NovaSpacing.md),
          if (items.isEmpty)
            NovaCard(
              padding: const EdgeInsets.all(NovaSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.history, color: NovaColors.graphite),
                  const SizedBox(width: NovaSpacing.md),
                  Expanded(
                    child: Text(
                      emptyText,
                      style: const TextStyle(
                        color: NovaColors.graphite,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final food in items.take(5)) ...[
              _FoodResultTile(
                food: food,
                mealType: mealType,
                onFoodChanged: onFoodChanged,
              ),
              const SizedBox(height: NovaSpacing.sm),
            ],
        ],
      ),
      error: (error, _) => ErrorPanel(
        message: error.toString(),
        onRetry: onFoodChanged,
      ),
      loading: () => const LinearProgressIndicator(minHeight: 3),
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
    required this.title,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onCreateCustom,
    required this.onFoodChanged,
    this.showBestMatch = false,
  });

  final List<FoodSummary> items;
  final String query;
  final String mealType;
  final String title;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback onCreateCustom;
  final VoidCallback onFoodChanged;
  final bool showBestMatch;

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
                EmptyState(
                  title: emptyTitle,
                  message: query.isEmpty
                      ? emptyMessage
                      : 'No matching foods in this tab.',
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
    final best = showBestMatch ? items.first : null;
    final rest = showBestMatch ? items.skip(1).toList() : items;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: NovaSpacing.md),
        if (best != null)
          _FoodResultTile(
            food: best,
            mealType: mealType,
            highlighted: true,
            onFoodChanged: onFoodChanged,
          ),
        if (rest.isNotEmpty) ...[
          if (best != null) ...[
            const SizedBox(height: NovaSpacing.xl),
            const Text(
              'More Results',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ],
          const SizedBox(height: NovaSpacing.md),
          for (final food in rest) ...[
            _FoodResultTile(
              food: food,
              mealType: mealType,
              onFoodChanged: onFoodChanged,
            ),
            const SizedBox(height: NovaSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _FoodAsyncResults extends StatelessWidget {
  const _FoodAsyncResults({
    required this.state,
    required this.query,
    required this.mealType,
    required this.title,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onCreateCustom,
    required this.onFoodChanged,
  });

  final AsyncValue<List<FoodSummary>> state;
  final String query;
  final String mealType;
  final String title;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback onCreateCustom;
  final VoidCallback onFoodChanged;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (items) => _FoodResults(
        items: _filterFoods(items, query),
        query: query,
        mealType: mealType,
        title: title,
        emptyTitle: emptyTitle,
        emptyMessage: emptyMessage,
        onCreateCustom: onCreateCustom,
        onFoodChanged: onFoodChanged,
      ),
      error: (error, _) => ErrorPanel(
        message: error.toString(),
        onRetry: onFoodChanged,
      ),
      loading: () => const LoadingList(),
    );
  }
}

List<FoodSummary> _filterFoods(List<FoodSummary> foods, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return foods;
  return foods
      .where(
        (food) =>
            food.name.toLowerCase().contains(normalized) ||
            food.brand.toLowerCase().contains(normalized) ||
            food.servingSummary.toLowerCase().contains(normalized),
      )
      .toList();
}

class _FoodResultTile extends ConsumerStatefulWidget {
  const _FoodResultTile({
    required this.food,
    required this.mealType,
    required this.onFoodChanged,
    this.highlighted = false,
  });

  final FoodSummary food;
  final String mealType;
  final VoidCallback onFoodChanged;
  final bool highlighted;

  @override
  ConsumerState<_FoodResultTile> createState() => _FoodResultTileState();
}

class _FoodResultTileState extends ConsumerState<_FoodResultTile> {
  bool _adding = false;
  bool _savingFavorite = false;

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final servingText = food.servingSummary;
    final sourceText =
        food.brand.isEmpty ? servingText : '${food.brand} • $servingText';
    return NovaCard(
      color: widget.highlighted ? NovaColors.panelRaised : NovaColors.panel,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.go(
                _withMealType('/foods/${food.id}', widget.mealType),
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
                    '${food.preview.caloriesKcal.toStringAsFixed(0)} kcal / 100g'
                    ' • $sourceText',
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
                      if (food.preview.sugarG > 0)
                        NovaBadge(
                          label:
                              'Sugar ${food.preview.sugarG.toStringAsFixed(0)}g',
                          color: NovaColors.gold,
                        ),
                      if (food.preview.sodiumMg > 0)
                        NovaBadge(
                          label:
                              'Na ${food.preview.sodiumMg.toStringAsFixed(0)}mg',
                          color: NovaColors.blue,
                        ),
                      if (food.preview.calciumMg > 0)
                        NovaBadge(
                          label:
                              'Ca ${food.preview.calciumMg.toStringAsFixed(0)}mg',
                          color: NovaColors.mint,
                        ),
                      if (food.preview.ironMg > 0)
                        NovaBadge(
                          label:
                              'Iron ${food.preview.ironMg.toStringAsFixed(1)}mg',
                          color: NovaColors.coral,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: NovaSpacing.md),
          Column(
            children: [
              IconButton(
                tooltip: food.isFavorite ? 'Remove favorite' : 'Add favorite',
                icon: Icon(
                  food.isFavorite ? Icons.star : Icons.star_border,
                  color:
                      food.isFavorite ? NovaColors.gold : NovaColors.graphite,
                ),
                onPressed: _savingFavorite ? null : _toggleFavorite,
              ),
              IconButton.filled(
                tooltip: 'Add one serving',
                icon: _adding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                onPressed: _adding ? null : _oneTapAdd,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _oneTapAdd() async {
    final messenger = ScaffoldMessenger.of(context);
    final food = widget.food;
    final hasServing = food.defaultServingGrams > 0;
    setState(() => _adding = true);
    try {
      await ref.read(nutritionRepositoryProvider).addManualFood(
            foodId: food.id,
            quantity: hasServing ? 1 : 100,
            unit: hasServing ? 'serving' : 'gram',
            mealType: widget.mealType,
          );
      widget.onFoodChanged();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Added ${food.name} to ${_mealLabel(widget.mealType)}'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final messenger = ScaffoldMessenger.of(context);
    final food = widget.food;
    final nextFavorite = !food.isFavorite;
    setState(() => _savingFavorite = true);
    try {
      await ref.read(nutritionRepositoryProvider).setFoodFavorite(
            foodId: food.id,
            isFavorite: nextFavorite,
          );
      widget.onFoodChanged();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(nextFavorite ? 'Added favorite' : 'Removed favorite'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _savingFavorite = false);
    }
  }
}

String _withMealType(String path, String mealType) {
  return Uri(path: path, queryParameters: {'meal_type': mealType}).toString();
}

String _mealLabel(String mealType) {
  return mealType
      .replaceAll('_', ' ')
      .split(' ')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
