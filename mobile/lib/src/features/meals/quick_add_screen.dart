import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class QuickAddScreen extends ConsumerStatefulWidget {
  const QuickAddScreen({super.key, this.initialMealType = 'breakfast'});

  final String initialMealType;

  @override
  ConsumerState<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends ConsumerState<QuickAddScreen> {
  final _text = TextEditingController();
  late String _mealType;
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>> _reviewItems = [];
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final parsedItems = _reviewItems;
    final preview = result == null
        ? const <String, dynamic>{}
        : _reviewPreview(
            parsedItems,
            result['preview'] as Map<String, dynamic>? ?? const {},
          );
    final canConfirm = _canConfirmQuickAdd(parsedItems);
    final hasText = _text.text.trim().isNotEmpty;

    return NovaScaffold(
      title: 'Quick add',
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.lg),
        children: [
          TextField(
            controller: _text,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'What did you eat?',
              hintText: '2 eggs, 1 banana, 200g cooked rice, 2 chapati',
              prefixIcon: Icon(Icons.flash_on_outlined),
            ),
            onChanged: (_) => _clearParsedResult(),
          ),
          const SizedBox(height: NovaSpacing.md),
          Wrap(
            spacing: NovaSpacing.sm,
            runSpacing: NovaSpacing.sm,
            children: [
              for (final example in const [
                '2 eggs',
                '1 banana',
                '200g cooked rice',
                '2 chapati',
                '1 bowl dal',
                '1 scoop whey protein',
              ])
                ActionChip(
                  label: Text(example),
                  onPressed: () => _setExample(example),
                ),
            ],
          ),
          const SizedBox(height: NovaSpacing.md),
          MealTypeSelector(
            value: _mealType,
            onChanged: (value) => setState(() => _mealType = value),
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: _loading ? 'Parsing...' : 'Parse food',
            icon: Icons.auto_awesome,
            onPressed: _loading || !hasText
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _loading = true);
                    try {
                      final result = await ref
                          .read(nutritionRepositoryProvider)
                          .quickAdd(_text.text, _mealType);
                      if (mounted) {
                        setState(() {
                          _result = result;
                          _reviewItems =
                              (result['parsed_items'] as List<dynamic>? ??
                                      const [])
                                  .map(
                                    (item) => _withPreviewBaseGrams(
                                      Map<String, dynamic>.from(
                                        item as Map<String, dynamic>,
                                      ),
                                    ),
                                  )
                                  .toList();
                          _loading = false;
                        });
                      }
                    } catch (error) {
                      if (mounted) {
                        setState(() => _loading = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text(friendlyErrorMessage(error))),
                        );
                      }
                    }
                  },
          ),
          if (_result != null) ...[
            const SizedBox(height: NovaSpacing.lg),
            NovaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      NovaBadge(
                        label: _result!['requires_review'] == true
                            ? 'Review needed'
                            : 'Ready',
                        icon: _result!['requires_review'] == true
                            ? Icons.warning_amber
                            : Icons.check,
                        color: _result!['requires_review'] == true
                            ? NovaColors.gold
                            : NovaColors.mint,
                      ),
                      const Spacer(),
                      Text('Confidence ${_result!['confidence']}'),
                    ],
                  ),
                  const SizedBox(height: NovaSpacing.lg),
                  Text(
                    '${preview['calories_kcal'] ?? 0} kcal',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: NovaSpacing.sm),
                  Text(
                    'Protein ${preview['protein_g'] ?? 0}g • Carbs ${preview['carbs_g'] ?? 0}g • Fat ${preview['fat_g'] ?? 0}g',
                  ),
                  if (_result!['requires_review'] == true) ...[
                    const SizedBox(height: NovaSpacing.sm),
                    const Text(
                      'Tap edit on any uncertain item before confirming.',
                      style: TextStyle(
                        color: NovaColors.graphite,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const Divider(height: 28),
                  for (var i = 0; i < parsedItems.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _itemHasFood(parsedItems[i])
                            ? Icons.restaurant
                            : Icons.warning_amber,
                        color: _itemHasFood(parsedItems[i])
                            ? null
                            : NovaColors.gold,
                      ),
                      title: Text(
                          parsedItems[i]['food_name']?.toString() ?? 'Food'),
                      subtitle: Text(
                        '${parsedItems[i]['quantity_value']} ${parsedItems[i]['quantity_unit']}'
                        ' • ${parsedItems[i]['effective_total_grams']}g'
                        ' • ${_itemPreviewText(parsedItems[i])}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final edited =
                              await showModalBottomSheet<Map<String, dynamic>>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => _QuickAddItemEditSheet(
                              item: parsedItems[i],
                            ),
                          );
                          if (edited != null) {
                            setState(() => _reviewItems[i] = edited);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: NovaSpacing.lg),
            NovaButton.primary(
              label: _saving
                  ? 'Saving...'
                  : 'Confirm and save to ${_mealLabel(_mealType)}',
              icon: Icons.check,
              onPressed: _saving || !canConfirm
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await ref
                            .read(nutritionRepositoryProvider)
                            .confirmQuickAdd({
                          'text': _text.text,
                          'meal_type': _mealType,
                          'items': parsedItems,
                        });
                        ref.invalidate(dashboardProvider);
                        ref.invalidate(todayMealLogsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Quick add saved to ${_mealLabel(_mealType)}',
                              ),
                            ),
                          );
                          context.go('/meals');
                        }
                      } catch (error) {
                        if (context.mounted) {
                          setState(() => _saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(friendlyErrorMessage(error)),
                            ),
                          );
                        }
                      }
                    },
            ),
            if (!canConfirm) ...[
              const SizedBox(height: NovaSpacing.sm),
              const Text(
                'One or more items needs a food match. Tap edit and choose a match before saving.',
                style: TextStyle(
                  color: NovaColors.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: NovaSpacing.md),
              NovaButton.secondary(
                label: 'Create custom food for missing item',
                icon: Icons.add_circle_outline,
                onPressed: _createCustomForMissingItem,
              ),
            ],
          ],
        ],
      ),
    );
  }

  bool _canConfirmQuickAdd(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return false;
    return items.every(_itemHasFood);
  }

  bool _itemHasFood(Map<String, dynamic> item) {
    return item['food_id']?.toString().trim().isNotEmpty == true;
  }

  String _itemPreviewText(Map<String, dynamic> item) {
    final preview = _reviewPreview(
      [item],
      item['nutrition_preview'] as Map<String, dynamic>? ?? const {},
    );
    final calories = _asDouble(preview['calories_kcal']);
    final protein = _asDouble(preview['protein_g']);
    final carbs = _asDouble(preview['carbs_g']);
    final fat = _asDouble(preview['fat_g']);
    if (calories <= 0 && protein <= 0 && carbs <= 0 && fat <= 0) {
      return 'nutrition after save';
    }
    return '${calories.toStringAsFixed(0)} kcal'
        ' • P ${protein.toStringAsFixed(1)}g'
        ' C ${carbs.toStringAsFixed(1)}g'
        ' F ${fat.toStringAsFixed(1)}g';
  }

  void _setExample(String example) {
    setState(() {
      _text.text = example;
      _result = null;
      _reviewItems = [];
    });
  }

  void _clearParsedResult() {
    setState(() {
      _result = null;
      _reviewItems = [];
    });
  }

  Future<void> _createCustomForMissingItem() async {
    final index = _reviewItems.indexWhere((item) => !_itemHasFood(item));
    if (index < 0) return;
    final item = _reviewItems[index];
    final initialName = item['food_name']?.toString() ?? '';
    final food = await context.push<FoodDetail>(
      Uri(
        path: '/foods/custom',
        queryParameters: {
          'name': initialName,
          'meal_type': _mealType,
          'return_to': 'quick_add',
        },
      ).toString(),
    );
    if (!mounted || food == null) return;
    final grams = _asDouble(
      item['effective_total_grams'] ?? item['total_grams'],
      fallback: food.defaultServingG,
    );
    final preview = food.previewFor(
      quantity: grams > 0 ? grams : food.defaultServingG,
      unit: 'gram',
      totalGrams: grams > 0 ? grams : food.defaultServingG,
    );
    setState(() {
      _reviewItems[index] = {
        ...item,
        'food_id': food.id,
        'food_name': food.name,
        'matched_food_name': food.name,
        'effective_total_grams': grams > 0 ? grams : food.defaultServingG,
        '_preview_base_grams': grams > 0 ? grams : food.defaultServingG,
        'nutrition_preview': {
          'calories_kcal': preview.caloriesKcal,
          'protein_g': preview.proteinG,
          'carbs_g': preview.carbsG,
          'fat_g': preview.fatG,
        },
      };
    });
  }

  Map<String, dynamic> _withPreviewBaseGrams(Map<String, dynamic> item) {
    final nutritionPreview =
        item['nutrition_preview'] as Map<String, dynamic>? ?? const {};
    item['_preview_base_grams'] = nutritionPreview['effective_total_grams'] ??
        item['effective_total_grams'];
    return item;
  }

  Map<String, dynamic> _reviewPreview(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> fallback,
  ) {
    if (items.isEmpty) return fallback;
    final totals = {
      'calories_kcal': 0.0,
      'protein_g': 0.0,
      'carbs_g': 0.0,
      'fat_g': 0.0,
    };
    for (final item in items) {
      final preview =
          item['nutrition_preview'] as Map<String, dynamic>? ?? const {};
      final currentGrams = _asDouble(
        item['effective_total_grams'] ?? item['total_grams'],
        fallback: _asDouble(item['_preview_base_grams'], fallback: 0),
      );
      final baseGrams = _asDouble(
        item['_preview_base_grams'],
        fallback: currentGrams,
      );
      final scale =
          baseGrams > 0 && currentGrams > 0 ? currentGrams / baseGrams : 1.0;
      for (final key in totals.keys) {
        totals[key] = totals[key]! + _asDouble(preview[key]) * scale;
      }
    }
    return totals;
  }
}

class _QuickAddItemEditSheet extends StatefulWidget {
  const _QuickAddItemEditSheet({required this.item});

  final Map<String, dynamic> item;

  @override
  State<_QuickAddItemEditSheet> createState() => _QuickAddItemEditSheetState();
}

class _QuickAddItemEditSheetState extends State<_QuickAddItemEditSheet> {
  late final TextEditingController _quantity;
  late final TextEditingController _grams;
  late final List<FoodSummary> _alternatives;
  late String _selectedFoodId;
  late String _selectedFoodName;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(
      text: widget.item['quantity_value']?.toString() ?? '1',
    );
    _grams = TextEditingController(
      text: widget.item['effective_total_grams']?.toString() ?? '',
    );
    _unit = widget.item['quantity_unit']?.toString() ?? 'serving';
    _selectedFoodId = widget.item['food_id']?.toString() ?? '';
    _selectedFoodName = widget.item['food_name']?.toString() ?? 'Food';
    _alternatives =
        (widget.item['alternative_matches'] as List<dynamic>? ?? const [])
            .map(
              (item) => FoodSummary.fromJson(
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
              ),
            )
            .toList();
  }

  @override
  void dispose() {
    _quantity.dispose();
    _grams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: _selectedFoodName),
            const SizedBox(height: NovaSpacing.md),
            if (_alternatives.isNotEmpty) ...[
              const Text(
                'Food match',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: NovaSpacing.sm),
              for (final food in _alternatives)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: food.id == _selectedFoodId,
                  title: Text(food.name),
                  subtitle: food.brand.isEmpty
                      ? Text(
                          '${food.preview.caloriesKcal.toStringAsFixed(0)} kcal / 100g')
                      : Text(
                          '${food.brand} • ${food.preview.caloriesKcal.toStringAsFixed(0)} kcal / 100g',
                        ),
                  trailing: food.id == _selectedFoodId
                      ? const Icon(Icons.check_circle_outline)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedFoodId = food.id;
                      _selectedFoodName = food.name;
                    });
                  },
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
                  ),
                ),
                const SizedBox(width: NovaSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: const [
                      DropdownMenuItem(value: 'egg', child: Text('Egg')),
                      DropdownMenuItem(
                          value: 'serving', child: Text('Serving')),
                      DropdownMenuItem(value: 'gram', child: Text('Gram')),
                      DropdownMenuItem(value: 'bowl', child: Text('Bowl')),
                      DropdownMenuItem(value: 'cup', child: Text('Cup')),
                      DropdownMenuItem(value: 'piece', child: Text('Piece')),
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
                labelText: 'Total grams',
                prefixIcon: Icon(Icons.scale_outlined),
              ),
            ),
            const SizedBox(height: NovaSpacing.lg),
            NovaButton.primary(
              label: 'Apply review',
              icon: Icons.check,
              onPressed: () {
                final updated = Map<String, dynamic>.from(widget.item);
                updated['food_id'] = _selectedFoodId;
                updated['food_name'] = _selectedFoodName;
                updated['quantity_value'] = _quantity.text.trim();
                updated['quantity_unit'] = _unit;
                updated['effective_total_grams'] = _grams.text.trim();
                updated['total_grams'] = _grams.text.trim();
                final selectedFood = _selectedFoodId.isEmpty
                    ? null
                    : _alternatives
                        .where((food) => food.id == _selectedFoodId)
                        .firstOrNull;
                if (selectedFood != null) {
                  final grams = _asDouble(_grams.text.trim(), fallback: 100);
                  final scale = grams <= 0 ? 1.0 : grams / 100;
                  updated['nutrition_preview'] = {
                    'calories_kcal': selectedFood.preview.caloriesKcal * scale,
                    'protein_g': selectedFood.preview.proteinG * scale,
                    'carbs_g': selectedFood.preview.carbsG * scale,
                    'fat_g': selectedFood.preview.fatG * scale,
                    'effective_total_grams': grams,
                  };
                  updated['_preview_base_grams'] = grams;
                }
                Navigator.of(context).pop(updated);
              },
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

String _mealLabel(String mealType) {
  return mealType
      .replaceAll('_', ' ')
      .split(' ')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
