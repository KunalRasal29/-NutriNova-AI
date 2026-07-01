import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class CreateCustomFoodScreen extends ConsumerStatefulWidget {
  const CreateCustomFoodScreen({
    this.initialBarcode = '',
    this.initialMealType = 'breakfast',
    super.key,
  });

  final String initialBarcode;
  final String initialMealType;

  @override
  ConsumerState<CreateCustomFoodScreen> createState() =>
      _CreateCustomFoodScreenState();
}

class _CreateCustomFoodScreenState
    extends ConsumerState<CreateCustomFoodScreen> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _serving = TextEditingController(text: '1 serving');
  final _grams = TextEditingController(text: '100');
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _sugar = TextEditingController();
  final _sodium = TextEditingController();
  late final TextEditingController _barcode;
  final _notes = TextEditingController();
  late String _mealType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _barcode = TextEditingController(text: widget.initialBarcode);
    _mealType = widget.initialMealType;
    for (final controller in [
      _calories,
      _protein,
      _carbs,
      _fat,
      _fiber,
      _sugar,
      _sodium,
      _grams,
    ]) {
      controller.addListener(_refreshPreview);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _brand,
      _serving,
      _grams,
      _calories,
      _protein,
      _carbs,
      _fat,
      _fiber,
      _sugar,
      _sodium,
      _barcode,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview();
    return NovaScaffold(
      title: 'Custom food',
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.lg),
        children: [
          const PageIntro(
            title: 'Create custom food',
            subtitle:
                'Add your own food when search or barcode does not have it.',
            icon: Icons.add_circle_outline,
          ),
          const SizedBox(height: NovaSpacing.md),
          const Wrap(
            spacing: NovaSpacing.sm,
            runSpacing: NovaSpacing.sm,
            children: [
              NovaBadge(
                label: 'Your custom food',
                icon: Icons.person_outline,
                color: NovaColors.mint,
              ),
              SourceConfidenceBadges(
                source: 'USER_CUSTOM',
                confidence: 0.5,
                verified: false,
                classification: 'user_custom',
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.lg),
          MealTypeSelector(
            value: _mealType,
            onChanged: (value) => setState(() => _mealType = value),
          ),
          const SizedBox(height: NovaSpacing.lg),
          if (widget.initialBarcode.isNotEmpty) ...[
            NovaCard(
              child: Row(
                children: [
                  const Icon(Icons.qr_code_2_outlined),
                  const SizedBox(width: NovaSpacing.md),
                  Expanded(
                    child:
                        Text('Creating from barcode ${widget.initialBarcode}'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NovaSpacing.md),
          ],
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Food name'),
          ),
          const SizedBox(height: NovaSpacing.md),
          TextField(
            controller: _brand,
            decoration: const InputDecoration(labelText: 'Brand optional'),
          ),
          const SizedBox(height: NovaSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serving,
                  decoration: const InputDecoration(labelText: 'Serving name'),
                ),
              ),
              const SizedBox(width: NovaSpacing.md),
              Expanded(
                child: TextField(
                  controller: _grams,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Serving grams'),
                ),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.md),
          Row(
            children: [
              Expanded(child: _numberField(_calories, 'Calories')),
              const SizedBox(width: NovaSpacing.md),
              Expanded(child: _numberField(_protein, 'Protein g')),
            ],
          ),
          const SizedBox(height: NovaSpacing.md),
          Row(
            children: [
              Expanded(child: _numberField(_carbs, 'Carbs g')),
              const SizedBox(width: NovaSpacing.md),
              Expanded(child: _numberField(_fat, 'Fat g')),
            ],
          ),
          const SizedBox(height: NovaSpacing.md),
          Row(
            children: [
              Expanded(child: _numberField(_fiber, 'Fiber g')),
              const SizedBox(width: NovaSpacing.md),
              Expanded(child: _numberField(_sugar, 'Sugar g')),
            ],
          ),
          const SizedBox(height: NovaSpacing.md),
          _numberField(_sodium, 'Sodium mg'),
          const SizedBox(height: NovaSpacing.md),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: NovaSpacing.md),
          TextField(
            controller: _barcode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Barcode optional',
              prefixIcon: Icon(Icons.qr_code_2_outlined),
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaCard(
            color: NovaColors.panelRaised,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Preview per serving'),
                const SizedBox(height: NovaSpacing.md),
                Text(
                  '${preview.caloriesKcal.toStringAsFixed(0)} kcal',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: NovaSpacing.sm),
                Text(
                  'P ${preview.proteinG.toStringAsFixed(1)}g  C ${preview.carbsG.toStringAsFixed(1)}g  F ${preview.fatG.toStringAsFixed(1)}g',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: NovaSpacing.xs),
                Text(
                  'Fiber ${preview.fiberG.toStringAsFixed(1)}g  Sugar ${preview.sugarG.toStringAsFixed(1)}g  Sodium ${preview.sodiumMg.toStringAsFixed(0)}mg',
                  style: const TextStyle(color: NovaColors.graphite),
                ),
              ],
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: _saving
                ? 'Saving...'
                : 'Save and add to ${_mealLabel(_mealType)}',
            icon: Icons.check,
            onPressed: _saving ? null : () => _saveCustomFood(addToMeal: true),
          ),
          const SizedBox(height: NovaSpacing.sm),
          NovaButton.secondary(
            label: 'Save only',
            icon: Icons.save_outlined,
            onPressed: _saving ? null : () => _saveCustomFood(addToMeal: false),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCustomFood({required bool addToMeal}) async {
    final messenger = ScaffoldMessenger.of(context);
    final validationMessage = _validationMessage();
    if (validationMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(nutritionRepositoryProvider);
      final food = await repo.createCustomFood(_payload());
      ref.invalidate(myFoodsProvider);
      ref.invalidate(foodSearchProvider(_name.text.trim()));

      if (addToMeal) {
        await repo.addManualFood(
          foodId: food.id,
          quantity: 1,
          unit: 'serving',
          mealType: _mealType,
        );
        ref.invalidate(dashboardProvider);
        ref.invalidate(todayMealLogsProvider);
        ref.invalidate(recentFoodsProvider);
        ref.invalidate(frequentFoodsProvider);
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Saved ${food.name} and added it to ${_mealLabel(_mealType)}',
            ),
          ),
        );
        context.go('/meals');
        return;
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Saved ${food.name} to My Foods')),
      );
      context.go(
        Uri(
          path: '/foods/${food.id}',
          queryParameters: {'meal_type': _mealType},
        ).toString(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
  }

  MacroPreview _preview() {
    return MacroPreview(
      caloriesKcal: _number(_calories),
      proteinG: _number(_protein),
      carbsG: _number(_carbs),
      fatG: _number(_fat),
      fiberG: _number(_fiber),
      sugarG: _number(_sugar),
      sodiumMg: _number(_sodium),
    );
  }

  double _number(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  Map<String, dynamic> _payload() {
    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'serving_name': _serving.text.trim(),
      'serving_grams': _grams.text.trim(),
    };
    void putIfPresent(String key, TextEditingController controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) payload[key] = value;
    }

    putIfPresent('brand', _brand);
    putIfPresent('calories_kcal', _calories);
    putIfPresent('protein_g', _protein);
    putIfPresent('carbs_g', _carbs);
    putIfPresent('fat_g', _fat);
    putIfPresent('fiber_g', _fiber);
    putIfPresent('sugar_g', _sugar);
    putIfPresent('sodium_mg', _sodium);
    putIfPresent('barcode', _barcode);
    putIfPresent('notes', _notes);
    return payload;
  }

  String? _validationMessage() {
    if (_name.text.trim().isEmpty) return 'Enter a food name.';
    if ((double.tryParse(_grams.text.trim()) ?? 0) <= 0) {
      return 'Enter serving grams greater than 0.';
    }
    final hasCalories = _calories.text.trim().isNotEmpty;
    final hasMacro = [
      _protein,
      _carbs,
      _fat,
      _fiber,
      _sugar,
      _sodium,
    ].any((controller) => controller.text.trim().isNotEmpty);
    if (!hasCalories && !hasMacro) {
      return 'Enter calories or at least one macro.';
    }
    return null;
  }
}

String _mealLabel(String mealType) {
  return mealType
      .replaceAll('_', ' ')
      .split(' ')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
