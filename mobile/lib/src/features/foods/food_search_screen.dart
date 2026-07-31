import 'dart:async';

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
  Timer? _debounce;
  List<FoodSummary> _searchResults = const [];
  bool _searching = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _resultCount = 0;
  int _page = 1;
  int _searchGeneration = 0;
  String _debouncedQuery = '';
  String? _searchError;
  String _foodType = '';
  String _source = '';
  String _preparationState = '';
  bool? _verified;

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
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    return NovaScaffold(
      title: 'Add Food',
      actions: [
        IconButton(
          tooltip: 'Manage my custom foods',
          icon: const Icon(Icons.inventory_2_outlined),
          onPressed: () => context.push('/foods/custom/manage'),
        ),
        IconButton(
          tooltip: 'Create custom food',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => _openCustomFood(query),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(NovaSpacing.lg),
            child: NovaCard(
              color: NovaColors.glass,
              accentColor: NovaColors.electric,
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: NovaColors.premiumGradient,
                          borderRadius: BorderRadius.circular(NovaRadius.sm),
                          boxShadow: NovaShadows.glow(NovaColors.blue),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: NovaSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Find your next meal',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Trusted foods, your favourites and custom meals',
                              style: TextStyle(
                                color: NovaColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NovaSpacing.lg),
                  MealTypeSelector(
                    value: _mealType,
                    onChanged: (value) => setState(() => _mealType = value),
                  ),
                  const SizedBox(height: NovaSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _query,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search foods, brands, meals...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: _clearSearch,
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                          textInputAction: TextInputAction.search,
                          onChanged: _onQueryChanged,
                          onSubmitted: (_) => _runSearch(reset: true),
                        ),
                      ),
                      const SizedBox(width: NovaSpacing.sm),
                      Semantics(
                        button: true,
                        label: 'Food search filters',
                        child: IconButton.filledTonal(
                          tooltip: 'Filters',
                          onPressed: _showFilters,
                          icon: Badge(
                            isLabelVisible: _activeFilterCount > 0,
                            label: Text('$_activeFilterCount'),
                            child: const Icon(Icons.tune),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_activeFilterCount > 0) ...[
                    const SizedBox(height: NovaSpacing.sm),
                    _ActiveFilters(
                      foodType: _foodType,
                      source: _source,
                      preparationState: _preparationState,
                      verified: _verified,
                      onClear: _clearFilters,
                    ),
                  ],
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
          ),
          Expanded(
            child: _contentForTab(context, query),
          ),
        ],
      ),
    );
  }

  Widget _contentForTab(
    BuildContext context,
    String query,
  ) {
    if (_tab == FoodSearchTab.all) {
      if (query.isEmpty) {
        return _FoodHomeList(
          recentState: ref.watch(recentFoodsProvider),
          frequentState: ref.watch(frequentFoodsProvider),
          usualState: ref.watch(usualFoodsProvider(_mealType)),
          suggestions: _suggestions,
          mealType: _mealType,
          onPick: _pickSuggestion,
          onCreateCustom: () => _openCustomFood(query),
          onFoodChanged: _refreshFoodState,
        );
      }
      return _SearchResultList(
        items: _searchResults,
        query: _debouncedQuery,
        mealType: _mealType,
        loading: _searching,
        loadingMore: _loadingMore,
        hasMore: _hasMore,
        resultCount: _resultCount,
        error: _searchError,
        onRetry: () => _runSearch(reset: true),
        onLoadMore: _loadMore,
        onCreateCustom: () => _openCustomFood(query),
        onFoodChanged: _refreshFoodState,
      );
    }

    final tabState = switch (_tab) {
      FoodSearchTab.recent => ref.watch(recentFoodsProvider),
      FoodSearchTab.frequent => ref.watch(frequentFoodsProvider),
      FoodSearchTab.favorites => ref.watch(favoriteFoodsProvider),
      FoodSearchTab.myFoods => ref.watch(myFoodsProvider),
      FoodSearchTab.all => throw StateError('All foods use paged search.'),
    };
    return _FoodAsyncResults(
      state: tabState,
      query: query,
      mealType: _mealType,
      title: _tab.title,
      emptyTitle: _tab.emptyTitle,
      emptyMessage: _tab.emptyMessage,
      onCreateCustom: () => _openCustomFood(query),
      onFoodChanged: _refreshFoodState,
    );
  }

  void _refreshFoodState() {
    ref.invalidate(dashboardProvider);
    ref.invalidate(todayMealLogsProvider);
    ref.invalidate(recentFoodsProvider);
    ref.invalidate(frequentFoodsProvider);
    ref.invalidate(usualFoodsProvider(_mealType));
    ref.invalidate(favoriteFoodsProvider);
    ref.invalidate(myFoodsProvider);
    if (_query.text.trim().isNotEmpty) _runSearch(reset: true);
  }

  int get _activeFilterCount => [
        _foodType.isNotEmpty,
        _source.isNotEmpty,
        _preparationState.isNotEmpty,
        _verified != null,
      ].where((active) => active).length;

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _debouncedQuery = '';
        _searchResults = const [];
        _searchError = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(reset: true),
    );
  }

  void _clearSearch() {
    _debounce?.cancel();
    _query.clear();
    _onQueryChanged('');
  }

  void _pickSuggestion(String value) {
    _query.text = value;
    _query.selection = TextSelection.collapsed(offset: value.length);
    _onQueryChanged(value);
  }

  FoodSearchRequest _requestFor(int page) => FoodSearchRequest(
        query: _query.text.trim(),
        page: page,
        foodType: _foodType,
        source: _source,
        preparationState: _preparationState,
        verified: _verified,
      );

  Future<void> _runSearch({required bool reset}) async {
    final value = _query.text.trim();
    if (value.isEmpty) return;
    final generation = ++_searchGeneration;
    final nextPage = reset ? 1 : _page + 1;
    setState(() {
      _debouncedQuery = value;
      _searchError = null;
      if (reset) {
        _searching = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final page = await ref
          .read(nutritionRepositoryProvider)
          .searchFoodsAdvanced(_requestFor(nextPage));
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _page = page.page;
        _resultCount = page.count;
        _hasMore = page.hasMore;
        _searchResults =
            reset ? page.items : [..._searchResults, ...page.items];
      });
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _searchError = friendlyErrorMessage(error));
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _searching = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() => _runSearch(reset: false);

  Future<void> _openCustomFood(String initialName) async {
    final uri = Uri(
      path: '/foods/custom',
      queryParameters: {
        'meal_type': _mealType,
        if (initialName.trim().isNotEmpty) 'name': initialName.trim(),
        'return_to': 'search',
      },
    );
    final created = await context.push<FoodDetail>(uri.toString());
    if (!mounted || created == null) return;
    _query.text = created.name;
    _onQueryChanged(created.name);
    await context.push(
      _withMealType('/foods/${created.id}', _mealType),
    );
  }

  Future<void> _showFilters() async {
    final selection = await showModalBottomSheet<_FoodFilterSelection>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FoodFilterSheet(
        initial: _FoodFilterSelection(
          foodType: _foodType,
          source: _source,
          preparationState: _preparationState,
          verified: _verified,
        ),
      ),
    );
    if (selection == null || !mounted) return;
    setState(() {
      _foodType = selection.foodType;
      _source = selection.source;
      _preparationState = selection.preparationState;
      _verified = selection.verified;
    });
    if (_query.text.trim().isNotEmpty) _runSearch(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _foodType = '';
      _source = '';
      _preparationState = '';
      _verified = null;
    });
    if (_query.text.trim().isNotEmpty) _runSearch(reset: true);
  }
}

class _SearchResultList extends StatelessWidget {
  const _SearchResultList({
    required this.items,
    required this.query,
    required this.mealType,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.resultCount,
    required this.onRetry,
    required this.onLoadMore,
    required this.onCreateCustom,
    required this.onFoodChanged,
    this.error,
  });

  final List<FoodSummary> items;
  final String query;
  final String mealType;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final int resultCount;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final VoidCallback onCreateCustom;
  final VoidCallback onFoodChanged;

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) return const LoadingList();
    if (error != null && items.isEmpty) {
      return ErrorPanel(message: error!, onRetry: onRetry);
    }
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
        children: [
          NovaCard(
            child: Column(
              children: [
                EmptyState(
                  title: 'No foods found',
                  message:
                      'No match for “$query”. Try fewer words or create it privately.',
                  icon: Icons.search_off,
                ),
                NovaButton.primary(
                  label: 'Create custom food',
                  icon: Icons.add,
                  onPressed: onCreateCustom,
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
      itemCount: items.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: NovaSpacing.md),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Best matches',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '$resultCount found',
                  style: const TextStyle(
                    color: NovaColors.graphite,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }
        if (index <= items.length) {
          final food = items[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: NovaSpacing.sm),
            child: _FoodResultTile(
              food: food,
              mealType: mealType,
              highlighted: index == 1,
              onFoodChanged: onFoodChanged,
            ),
          );
        }
        if (error != null) {
          return ErrorPanel(message: error!, onRetry: onLoadMore);
        }
        if (!hasMore) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: NovaSpacing.lg),
            child: Center(
              child: Text(
                'That’s all the matching foods.',
                style: TextStyle(color: NovaColors.graphite),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: NovaSpacing.md),
          child: NovaButton.secondary(
            label: loadingMore ? 'Loading more…' : 'Load more results',
            icon: Icons.expand_more,
            onPressed: loadingMore ? null : onLoadMore,
          ),
        );
      },
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.foodType,
    required this.source,
    required this.preparationState,
    required this.verified,
    required this.onClear,
  });

  final String foodType;
  final String source;
  final String preparationState;
  final bool? verified;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: NovaSpacing.xs,
        runSpacing: NovaSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (foodType.isNotEmpty) Chip(label: Text(_foodTypeLabel(foodType))),
          if (source.isNotEmpty) Chip(label: Text(source.replaceAll('_', ' '))),
          if (preparationState.isNotEmpty)
            Chip(label: Text(_preparationLabel(preparationState))),
          if (verified != null)
            Chip(label: Text(verified! ? 'Verified only' : 'Unverified only')),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _FoodFilterSelection {
  const _FoodFilterSelection({
    required this.foodType,
    required this.source,
    required this.preparationState,
    required this.verified,
  });

  final String foodType;
  final String source;
  final String preparationState;
  final bool? verified;
}

class _FoodFilterSheet extends StatefulWidget {
  const _FoodFilterSheet({required this.initial});

  final _FoodFilterSelection initial;

  @override
  State<_FoodFilterSheet> createState() => _FoodFilterSheetState();
}

class _FoodFilterSheetState extends State<_FoodFilterSheet> {
  late String _foodType;
  late String _source;
  late String _preparationState;
  late bool? _verified;

  @override
  void initState() {
    super.initState();
    _foodType = widget.initial.foodType;
    _source = widget.initial.source;
    _preparationState = widget.initial.preparationState;
    _verified = widget.initial.verified;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          NovaSpacing.lg,
          NovaSpacing.lg,
          NovaSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + NovaSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Search filters'),
              const SizedBox(height: NovaSpacing.xs),
              const Text(
                'Narrow a large local food database.',
                style: TextStyle(color: NovaColors.graphite),
              ),
              const SizedBox(height: NovaSpacing.lg),
              _dropdown(
                label: 'Food type',
                value: _foodType,
                values: const {
                  '': 'All foods',
                  'generic': 'Generic',
                  'branded': 'Branded',
                  'user_custom': 'My custom foods',
                },
                onChanged: (value) => setState(() => _foodType = value),
              ),
              const SizedBox(height: NovaSpacing.md),
              _dropdown(
                label: 'Source',
                value: _source,
                values: const {
                  '': 'All sources',
                  'USDA_FDC': 'USDA FoodData Central',
                  'OPEN_FOOD_FACTS': 'Open Food Facts',
                  'IFCT_2017': 'IFCT 2017',
                  'INDB': 'Indian Nutrient Databank',
                  'USER_CUSTOM': 'User custom',
                },
                onChanged: (value) => setState(() => _source = value),
              ),
              const SizedBox(height: NovaSpacing.md),
              _dropdown(
                label: 'Preparation method',
                value: _preparationState,
                values: const {
                  '': 'Any preparation',
                  'raw': 'Raw',
                  'cooked': 'Cooked',
                  'boiled': 'Boiled',
                  'fried': 'Fried',
                  'baked': 'Baked',
                  'grilled': 'Grilled',
                  'roasted': 'Roasted',
                  'steamed': 'Steamed',
                  'prepared': 'Prepared dish',
                  'as_sold': 'As sold / packaged',
                },
                onChanged: (value) => setState(() => _preparationState = value),
              ),
              const SizedBox(height: NovaSpacing.lg),
              const Text(
                'Verification',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: NovaSpacing.sm),
              Wrap(
                spacing: NovaSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const Text('Any'),
                    selected: _verified == null,
                    onSelected: (_) => setState(() => _verified = null),
                  ),
                  ChoiceChip(
                    label: const Text('Verified'),
                    selected: _verified == true,
                    onSelected: (_) => setState(() => _verified = true),
                  ),
                  ChoiceChip(
                    label: const Text('Unverified'),
                    selected: _verified == false,
                    onSelected: (_) => setState(() => _verified = false),
                  ),
                ],
              ),
              const SizedBox(height: NovaSpacing.xl),
              NovaButton.primary(
                label: 'Apply filters',
                icon: Icons.check,
                onPressed: () => Navigator.pop(
                  context,
                  _FoodFilterSelection(
                    foodType: _foodType,
                    source: _source,
                    preparationState: _preparationState,
                    verified: _verified,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> values,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final entry in values.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (next) => onChanged(next ?? ''),
    );
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
      (Icons.flash_on_outlined, 'Text add', '/meals/quick-add'),
      (Icons.camera_alt_outlined, 'Meal scan', '/photos/scan'),
      (Icons.add_circle_outline, 'Custom', '/foods/custom'),
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
            onTap: () => context.push(_withMealType(shortcut.$3, mealType)),
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
    required this.usualState,
    required this.suggestions,
    required this.mealType,
    required this.onPick,
    required this.onCreateCustom,
    required this.onFoodChanged,
  });

  final AsyncValue<List<FoodSummary>> recentState;
  final AsyncValue<List<FoodSummary>> frequentState;
  final AsyncValue<List<FoodSummary>> usualState;
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
          title: 'Usual ${_mealLabel(mealType)}',
          emptyText: 'Foods you often log for this meal will appear here.',
          state: usualState,
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
        message: friendlyErrorMessage(error),
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
  });

  final List<FoodSummary> items;
  final String query;
  final String mealType;
  final String title;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback onCreateCustom;
  final VoidCallback onFoodChanged;

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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: NovaSpacing.md),
        if (items.isNotEmpty) ...[
          const SizedBox(height: NovaSpacing.md),
          for (final food in items) ...[
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
        message: friendlyErrorMessage(error),
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
              onTap: () => context.push(
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
                      SourceConfidenceBadges(
                        source: food.sourceBadge,
                        confidence: food.confidenceScore,
                        verified: food.verified,
                        classification: food.dataClassification,
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
                      if (food.preparationState != 'unspecified')
                        NovaBadge(
                          label: _preparationLabel(food.preparationState),
                          icon: Icons.soup_kitchen_outlined,
                          color: NovaColors.blue,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: NovaSpacing.md),
          SizedBox(
            width: 82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(78, 40),
                  ),
                  icon: _adding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add, size: 18),
                  label: Text(_adding ? 'Adding' : 'Add'),
                  onPressed: _adding ? null : _oneTapAdd,
                ),
              ],
            ),
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
      final serving = hasServing
          ? (food.defaultServingDescription.trim().isEmpty
              ? '1 serving'
              : food.defaultServingDescription.trim())
          : '100g';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Added $serving ${food.name} to ${_mealLabel(widget.mealType)}',
          ),
          action: SnackBarAction(
            label: 'Diary',
            onPressed: () {
              if (mounted) context.go('/meals');
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
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
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _savingFavorite = false);
    }
  }
}

String _preparationLabel(String state) {
  switch (state) {
    case 'raw':
      return 'Raw';
    case 'cooked':
      return 'Cooked';
    case 'boiled':
      return 'Boiled';
    case 'fried':
      return 'Fried';
    case 'baked':
      return 'Baked';
    case 'grilled':
      return 'Grilled';
    case 'roasted':
      return 'Roasted';
    case 'steamed':
      return 'Steamed';
    case 'prepared':
      return 'Prepared dish';
    case 'as_sold':
      return 'As sold';
    default:
      return 'Preparation not specified';
  }
}

String _foodTypeLabel(String foodType) {
  switch (foodType) {
    case 'generic':
      return 'Generic';
    case 'branded':
      return 'Branded';
    case 'user_custom':
      return 'My custom foods';
    default:
      return 'All types';
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
