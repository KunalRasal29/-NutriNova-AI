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
    this.initialName = '',
    this.foodId = '',
    this.duplicateFromId = '',
    this.returnTo = '',
    super.key,
  });

  final String initialBarcode;
  final String initialMealType;
  final String initialName;
  final String foodId;
  final String duplicateFromId;
  final String returnTo;

  bool get isEditing => foodId.isNotEmpty;

  @override
  ConsumerState<CreateCustomFoodScreen> createState() =>
      _CreateCustomFoodScreenState();
}

class _CreateCustomFoodScreenState
    extends ConsumerState<CreateCustomFoodScreen> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _servingName = TextEditingController(text: '1 serving');
  final _servingQuantity = TextEditingController(text: '1');
  final _grams = TextEditingController(text: '100');
  final _ingredients = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _sugar = TextEditingController();
  final _sodium = TextEditingController();
  final _notes = TextEditingController();
  late final TextEditingController _barcode;

  int _step = 0;
  bool _busy = false;
  bool _loading = false;
  bool _dirty = false;
  bool _completed = false;
  String? _error;
  String _mealType = 'breakfast';
  String _preparation = 'prepared';
  String _servingUnit = 'serving';
  String _workingFoodId = '';
  String _selectedReference = '';
  CustomFoodEstimate? _estimate;

  static const _titles = [
    'Food details',
    'Serving size',
    'Macro estimate',
    'Review estimate',
    'Confirm values',
    'Save custom food',
  ];

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName;
    _barcode = TextEditingController(text: widget.initialBarcode);
    _mealType = widget.initialMealType;
    for (final controller in _controllers) {
      controller.addListener(_markDirty);
    }
    final sourceId = widget.isEditing ? widget.foodId : widget.duplicateFromId;
    if (sourceId.isNotEmpty) _loadFood(sourceId);
  }

  List<TextEditingController> get _controllers => [
        _name,
        _brand,
        _servingName,
        _servingQuantity,
        _grams,
        _ingredients,
        _calories,
        _protein,
        _carbs,
        _fat,
        _fiber,
        _sugar,
        _sodium,
        _notes,
        _barcode,
      ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _completed,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmDiscard();
      },
      child: NovaScaffold(
        title: widget.isEditing ? 'Edit custom food' : 'Custom food wizard',
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    NovaSpacing.lg,
                    NovaSpacing.lg,
                    NovaSpacing.lg,
                    NovaSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  children: [
                    _WizardProgress(step: _step, titles: _titles),
                    const SizedBox(height: NovaSpacing.lg),
                    if (_error != null) ...[
                      _MessageCard(
                        icon: Icons.error_outline,
                        message: _error!,
                        color: NovaColors.coral,
                      ),
                      const SizedBox(height: NovaSpacing.md),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _stepBody(),
                      ),
                    ),
                    const SizedBox(height: NovaSpacing.xl),
                    _navigation(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _identityStep();
      case 1:
        return _servingStep();
      case 2:
        return _estimateStep();
      case 3:
        return _reviewStep();
      case 4:
        return _valuesStep();
      default:
        return _saveStep();
    }
  }

  Widget _identityStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageIntro(
            title: 'What is the food?',
            subtitle: 'Your custom foods are private to your account.',
            icon: Icons.restaurant_menu,
          ),
          const SizedBox(height: NovaSpacing.lg),
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Food name *',
              prefixIcon: Icon(Icons.restaurant_outlined),
            ),
          ),
          const SizedBox(height: NovaSpacing.md),
          TextField(
            controller: _brand,
            decoration: const InputDecoration(labelText: 'Brand optional'),
          ),
          const SizedBox(height: NovaSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _preparation,
            decoration: const InputDecoration(labelText: 'Preparation method'),
            items: _preparations
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(_label(value)),
                    ))
                .toList(),
            onChanged: (value) => setState(() {
              _preparation = value ?? _preparation;
              _dirty = true;
            }),
          ),
          const SizedBox(height: NovaSpacing.md),
          TextField(
            controller: _ingredients,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Ingredients optional',
              hintText: 'Useful context for the estimate',
            ),
          ),
        ],
      );

  Widget _servingStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageIntro(
            title: 'Define one serving',
            subtitle: 'Accurate grams make the estimate much more useful.',
            icon: Icons.scale_outlined,
          ),
          const SizedBox(height: NovaSpacing.lg),
          TextField(
            controller: _servingName,
            decoration: const InputDecoration(labelText: 'Serving name *'),
          ),
          const SizedBox(height: NovaSpacing.md),
          LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final quantity = _numberField(
              _servingQuantity,
              'Quantity',
              decimal: true,
            );
            final unit = DropdownButtonFormField<String>(
              initialValue: _servingUnit,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: _servingUnits
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(_label(value)),
                      ))
                  .toList(),
              onChanged: (value) => setState(() {
                _servingUnit = value ?? _servingUnit;
                _dirty = true;
              }),
            );
            return compact
                ? Column(children: [quantity, const SizedBox(height: 12), unit])
                : Row(children: [
                    Expanded(child: quantity),
                    const SizedBox(width: NovaSpacing.md),
                    Expanded(child: unit),
                  ]);
          }),
          const SizedBox(height: NovaSpacing.md),
          _numberField(_grams, 'Serving weight in grams *', decimal: true),
          const SizedBox(height: NovaSpacing.md),
          TextField(
            controller: _barcode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Barcode optional',
              prefixIcon: Icon(Icons.qr_code_2_outlined),
            ),
          ),
        ],
      );

  Widget _estimateStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageIntro(
            title: 'Estimate macros',
            subtitle: 'We compare trusted database foods for your serving.',
            icon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(height: NovaSpacing.lg),
          const _MessageCard(
            icon: Icons.info_outline,
            message:
                'Suggested estimate—review before saving. An estimate is never verified nutrition.',
            color: NovaColors.blue,
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _name.text.trim().isEmpty
                        ? 'Custom food'
                        : _name.text.trim(),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: NovaSpacing.sm),
                Text('${_grams.text.trim()}g • ${_label(_preparation)}',
                    style: const TextStyle(color: NovaColors.graphite)),
              ],
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: _busy ? 'Estimating…' : 'Estimate macros',
            icon: Icons.auto_awesome,
            onPressed: _busy ? null : _requestEstimate,
          ),
          const SizedBox(height: NovaSpacing.sm),
          NovaButton.secondary(
            label: 'Enter values manually',
            icon: Icons.edit_outlined,
            onPressed: _busy ? null : () => setState(() => _step = 4),
          ),
        ],
      );

  Widget _reviewStep() {
    final estimate = _estimate;
    if (estimate == null) return _estimateStep();
    final macros = _macroFrom(estimate.suggestedNutrients);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageIntro(
          title: 'Review the suggestion',
          subtitle: 'Suggested estimate—review before saving.',
          icon: Icons.fact_check_outlined,
        ),
        const SizedBox(height: NovaSpacing.md),
        SourceConfidenceBadges(
          source: estimate.sourceBadges.isEmpty
              ? 'REFERENCE FOODS'
              : estimate.sourceBadges.join(' + '),
          confidence: estimate.confidence,
          verified: false,
          classification: 'estimated',
        ),
        const SizedBox(height: NovaSpacing.md),
        _MacroCard(preview: macros, title: 'Likely values per serving'),
        if (estimate.ranges.isNotEmpty) ...[
          const SizedBox(height: NovaSpacing.md),
          _RangeCard(ranges: estimate.ranges),
        ],
        if (estimate.references.isNotEmpty) ...[
          const SizedBox(height: NovaSpacing.lg),
          const SectionHeader(title: 'Reference foods'),
          const SizedBox(height: NovaSpacing.sm),
          ...estimate.references.map(_referenceTile),
        ],
        if (estimate.warnings.isNotEmpty) ...[
          const SizedBox(height: NovaSpacing.md),
          ...estimate.warnings.map((warning) => Padding(
                padding: const EdgeInsets.only(bottom: NovaSpacing.sm),
                child: _MessageCard(
                  icon: Icons.warning_amber_rounded,
                  message: warning,
                  color: NovaColors.gold,
                ),
              )),
        ],
        if (!estimate.canEstimate) ...[
          const SizedBox(height: NovaSpacing.md),
          _MessageCard(
            icon: Icons.edit_note_outlined,
            message: estimate.message.isEmpty
                ? 'Unable to estimate reliably. Enter the values manually.'
                : estimate.message,
            color: NovaColors.coral,
          ),
        ],
        const SizedBox(height: NovaSpacing.lg),
        if (estimate.canEstimate)
          NovaButton.primary(
            label: 'Accept estimate',
            icon: Icons.check,
            onPressed: _acceptEstimate,
          ),
        const SizedBox(height: NovaSpacing.sm),
        NovaButton.secondary(
          label: 'Edit values',
          icon: Icons.edit_outlined,
          onPressed: () => setState(() => _step = 4),
        ),
      ],
    );
  }

  Widget _referenceTile(CustomFoodReference reference) {
    final selected = _selectedReference == reference.foodId;
    return Padding(
      padding: const EdgeInsets.only(bottom: NovaSpacing.sm),
      child: NovaCard(
        color: selected ? NovaColors.panelRaised : NovaColors.panel,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reference.name,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    [reference.brand, reference.sourceName]
                        .where((text) => text.isNotEmpty)
                        .join(' • '),
                    style: const TextStyle(color: NovaColors.graphite),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => _changeReference(reference),
              child: Text(selected ? 'Selected' : 'Change reference'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _valuesStep() {
    final preview = _preview();
    final calculated =
        preview.proteinG * 4 + preview.carbsG * 4 + preview.fatG * 9;
    final difference = (preview.caloriesKcal - calculated).abs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageIntro(
          title: 'Confirm final values',
          subtitle: 'You decide what is saved. All values are per serving.',
          icon: Icons.edit_note_outlined,
        ),
        const SizedBox(height: NovaSpacing.lg),
        _responsivePair(
          _numberField(_calories, 'Calories kcal *', decimal: true),
          _numberField(_protein, 'Protein g *', decimal: true),
        ),
        const SizedBox(height: NovaSpacing.md),
        _responsivePair(
          _numberField(_carbs, 'Carbohydrates g *', decimal: true),
          _numberField(_fat, 'Fat g *', decimal: true),
        ),
        const SizedBox(height: NovaSpacing.md),
        _responsivePair(
          _numberField(_fiber, 'Fibre g', decimal: true),
          _numberField(_sugar, 'Sugar g', decimal: true),
        ),
        const SizedBox(height: NovaSpacing.md),
        _numberField(_sodium, 'Sodium mg', decimal: true),
        const SizedBox(height: NovaSpacing.lg),
        _MacroCard(preview: preview, title: 'Final preview per serving'),
        const SizedBox(height: NovaSpacing.md),
        _MessageCard(
          icon: difference > 50
              ? Icons.warning_amber_rounded
              : Icons.calculate_outlined,
          message:
              'Calories calculated from macros: ${calculated.toStringAsFixed(0)} kcal. '
              '${difference > 50 ? 'This differs noticeably; review both values.' : 'Small label differences can come from fibre and rounding.'}',
          color: difference > 50 ? NovaColors.gold : NovaColors.blue,
        ),
        if (_estimate != null) ...[
          const SizedBox(height: NovaSpacing.sm),
          TextButton.icon(
            onPressed: _resetEstimate,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset to estimate'),
          ),
        ],
      ],
    );
  }

  Widget _saveStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageIntro(
            title: 'Ready to save',
            subtitle: 'Final values are confirmed by you, not marked verified.',
            icon: Icons.save_outlined,
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name.text.trim(),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: NovaSpacing.sm),
                Text('${_servingName.text.trim()} • ${_grams.text.trim()}g'),
                const SizedBox(height: NovaSpacing.md),
                _MacroLine(preview: _preview()),
                const SizedBox(height: NovaSpacing.md),
                const SourceConfidenceBadges(
                  source: 'USER CUSTOM',
                  confidence: 0.5,
                  verified: false,
                  classification: 'user_custom',
                ),
              ],
            ),
          ),
          const SizedBox(height: NovaSpacing.md),
          MealTypeSelector(
            value: _mealType,
            onChanged: (value) => setState(() => _mealType = value),
          ),
          const SizedBox(height: NovaSpacing.md),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes optional'),
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: _busy
                ? 'Saving…'
                : widget.returnTo.isNotEmpty
                    ? 'Save and return'
                    : 'Save and log',
            icon: widget.returnTo.isNotEmpty ? Icons.check : Icons.add_task,
            onPressed:
                _busy ? null : () => _save(addToMeal: widget.returnTo.isEmpty),
          ),
          const SizedBox(height: NovaSpacing.sm),
          NovaButton.secondary(
            label: widget.returnTo.isNotEmpty
                ? 'Save and log now'
                : 'Save final food',
            icon: widget.returnTo.isNotEmpty
                ? Icons.add_task
                : Icons.save_outlined,
            onPressed: _busy
                ? null
                : () => _save(addToMeal: widget.returnTo.isNotEmpty),
          ),
        ],
      );

  Widget _navigation() {
    if (_step == 2 || _step == 3 || _step == 5) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _busy ? null : () => setState(() => _step--),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back'),
        ),
      );
    }
    return Row(
      children: [
        if (_step > 0)
          Expanded(
            child: NovaButton.secondary(
              label: 'Back',
              icon: Icons.arrow_back,
              onPressed: _busy ? null : () => setState(() => _step--),
            ),
          ),
        if (_step > 0) const SizedBox(width: NovaSpacing.md),
        Expanded(
          child: NovaButton.primary(
            label: _step == 4 ? 'Review final food' : 'Continue',
            icon: Icons.arrow_forward,
            onPressed: _busy ? null : _continue,
          ),
        ),
      ],
    );
  }

  Future<void> _loadFood(String id) async {
    setState(() => _loading = true);
    try {
      final food =
          await ref.read(nutritionRepositoryProvider).customFoodDetail(id);
      if (!mounted) return;
      final review = food.customFood;
      _name.text =
          widget.duplicateFromId.isNotEmpty ? '${food.name} copy' : food.name;
      _brand.text = food.brand;
      _preparation = food.preparationState;
      _servingName.text =
          food.servings.isEmpty ? '1 serving' : food.servings.first.name;
      _grams.text = _format(review?.servingWeightG ?? food.defaultServingG);
      _servingQuantity.text = _format(review?.servingQuantity ?? 1);
      _servingUnit = review?.servingUnit ?? 'serving';
      _ingredients.text = food.ingredientsText;
      if (widget.isEditing) _workingFoodId = food.id;
      _fillNutrients(review?.effectiveNutrients ?? _servingValues(food));
      _dirty = false;
    } catch (error) {
      if (mounted) _error = friendlyErrorMessage(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestEstimate({String referenceId = ''}) async {
    final error = _identityError() ?? _servingError();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(nutritionRepositoryProvider);
      final payload = _estimatePayload(referenceId: referenceId);
      final estimate = _workingFoodId.isEmpty
          ? await repo.estimateCustomFood(payload)
          : await repo.reEstimateCustomFood(_workingFoodId, payload);
      if (!mounted) return;
      setState(() {
        _estimate = estimate;
        _selectedReference = referenceId;
        if (estimate.canEstimate) _fillNutrients(estimate.suggestedNutrients);
        _step = 3;
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeReference(CustomFoodReference reference) async {
    await _requestEstimate(referenceId: reference.foodId);
  }

  void _acceptEstimate() {
    final estimate = _estimate;
    if (estimate == null) return;
    _fillNutrients(estimate.suggestedNutrients);
    setState(() => _step = 4);
  }

  void _resetEstimate() {
    final estimate = _estimate;
    if (estimate == null) return;
    _fillNutrients(estimate.suggestedNutrients);
    setState(() {});
  }

  Future<void> _save({required bool addToMeal}) async {
    final validation = _valuesError();
    if (validation != null) {
      setState(() {
        _error = validation;
        _step = 4;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(nutritionRepositoryProvider);
      FoodDetail food;
      if (_workingFoodId.isEmpty) {
        food = await repo.createCustomFood(_createPayload());
        _workingFoodId = food.id;
      } else {
        await repo.updateCustomFood(_workingFoodId, _updatePayload());
        food = await repo.confirmCustomFood(
          _workingFoodId,
          {'final_nutrients': _nutrientPayload()},
        );
      }
      if (food.customFood?.status != 'confirmed') {
        food = await repo.confirmCustomFood(
          food.id,
          {'final_nutrients': _nutrientPayload()},
        );
      }
      if (addToMeal) {
        await repo.logCustomFood(food.id, mealType: _mealType);
      }
      ref.invalidate(myFoodsProvider);
      ref.invalidate(recentFoodsProvider);
      ref.invalidate(frequentFoodsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(todayMealLogsProvider);
      setState(() {
        _completed = true;
        _dirty = false;
      });
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(addToMeal
                ? 'Saved and logged ${food.name}'
                : 'Saved ${food.name}')),
      );
      if (widget.returnTo.isNotEmpty && context.canPop()) {
        context.pop(food);
      } else if (addToMeal) {
        context.go('/meals');
      } else if (context.canPop()) {
        context.pop(food);
      } else {
        context.go('/foods/${food.id}?meal_type=$_mealType');
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _continue() {
    String? error;
    if (_step == 0) error = _identityError();
    if (_step == 1) error = _servingError();
    if (_step == 4) error = _valuesError();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _step++;
    });
  }

  String? _identityError() {
    if (_name.text.trim().isEmpty) return 'Enter a food name.';
    return null;
  }

  String? _servingError() {
    if (_servingName.text.trim().isEmpty) return 'Enter a serving name.';
    if (_number(_servingQuantity) <= 0) {
      return 'Serving quantity must be greater than zero.';
    }
    if (_number(_grams) <= 0) return 'Serving grams must be greater than zero.';
    return null;
  }

  String? _valuesError() {
    for (final controller in [
      _calories,
      _protein,
      _carbs,
      _fat,
      _fiber,
      _sugar,
      _sodium
    ]) {
      final text = controller.text.trim();
      if (text.isNotEmpty &&
          (double.tryParse(text) == null || double.parse(text) < 0)) {
        return 'Nutrition values must be valid non-negative numbers.';
      }
    }
    if (_calories.text.trim().isEmpty &&
        [_protein, _carbs, _fat]
            .every((controller) => controller.text.trim().isEmpty)) {
      return 'Enter calories or the main macros.';
    }
    return null;
  }

  Map<String, dynamic> _estimatePayload({String referenceId = ''}) => {
        'food_name': _name.text.trim(),
        'brand': _brand.text.trim(),
        'preparation_method': _preparation,
        'serving_name': _servingName.text.trim(),
        'serving_quantity': _servingQuantity.text.trim(),
        'serving_unit': _servingUnit,
        'serving_weight_g': _grams.text.trim(),
        if (_ingredients.text.trim().isNotEmpty)
          'ingredients_text': _ingredients.text.trim(),
        if (referenceId.isNotEmpty) 'reference_food_id': referenceId,
      };

  Map<String, dynamic> _createPayload() => {
        'name': _name.text.trim(),
        'brand': _brand.text.trim(),
        'preparation_method': _preparation,
        'serving_name': _servingName.text.trim(),
        'serving_quantity': _servingQuantity.text.trim(),
        'serving_unit': _servingUnit,
        'serving_weight_g': _grams.text.trim(),
        'ingredients_text': _ingredients.text.trim(),
        'barcode': _barcode.text.trim(),
        'notes': _notes.text.trim(),
        ..._nutrientPayload(),
        if (_estimate != null) ...{
          'estimated_nutrients': _estimate!.suggestedNutrients,
          'estimated_range': {
            for (final entry in _estimate!.ranges.entries)
              entry.key: {
                'min': entry.value.minimum,
                'likely': entry.value.likely,
                'max': entry.value.maximum,
              },
          },
          'reference_matches': _estimate!.references
              .map((reference) => {
                    'food_id': reference.foodId,
                    'name': reference.name,
                    'brand': reference.brand,
                    'preparation_state': reference.preparationState,
                    'source': reference.sourceName,
                    'source_badge': reference.sourceBadge,
                    'name_match_score': reference.matchScore,
                    'nutrients_for_entered_serving': reference.nutrients,
                  })
              .toList(),
          'confidence': _estimate!.confidence,
          'estimation_method': _estimate!.estimationMethod,
          'warnings': _estimate!.warnings,
        },
      };

  Map<String, dynamic> _updatePayload() => {
        'name': _name.text.trim(),
        'brand': _brand.text.trim(),
        'preparation_method': _preparation,
        'serving_name': _servingName.text.trim(),
        'serving_quantity': _servingQuantity.text.trim(),
        'serving_unit': _servingUnit,
        'serving_weight_g': _grams.text.trim(),
        'ingredients_text': _ingredients.text.trim(),
        'barcode': _barcode.text.trim(),
        'notes': _notes.text.trim(),
        'final_nutrients': _nutrientPayload(),
      };

  Map<String, dynamic> _nutrientPayload() => {
        if (_calories.text.trim().isNotEmpty)
          'calories_kcal': _calories.text.trim(),
        if (_protein.text.trim().isNotEmpty) 'protein_g': _protein.text.trim(),
        if (_carbs.text.trim().isNotEmpty) 'carbs_g': _carbs.text.trim(),
        if (_fat.text.trim().isNotEmpty) 'fat_g': _fat.text.trim(),
        if (_fiber.text.trim().isNotEmpty) 'fiber_g': _fiber.text.trim(),
        if (_sugar.text.trim().isNotEmpty) 'sugar_g': _sugar.text.trim(),
        if (_sodium.text.trim().isNotEmpty) 'sodium_mg': _sodium.text.trim(),
      };

  Map<String, double> _servingValues(FoodDetail food) {
    final preview = food.previewFor(quantity: 1, unit: 'serving');
    return {
      'calories_kcal': preview.caloriesKcal,
      'protein_g': preview.proteinG,
      'carbs_g': preview.carbsG,
      'fat_g': preview.fatG,
      'fiber_g': preview.fiberG,
      'sugar_g': preview.sugarG,
      'sodium_mg': preview.sodiumMg,
    };
  }

  void _fillNutrients(Map<String, double> values) {
    _calories.text = _format(values['calories_kcal'] ?? 0);
    _protein.text = _format(values['protein_g'] ?? 0);
    _carbs.text = _format(values['carbs_g'] ?? 0);
    _fat.text = _format(values['fat_g'] ?? 0);
    _fiber.text = _format(values['fiber_g'] ?? 0);
    _sugar.text = _format(values['sugar_g'] ?? 0);
    _sodium.text = _format(values['sodium_mg'] ?? 0);
  }

  MacroPreview _preview() => _macroFrom({
        'calories_kcal': _number(_calories),
        'protein_g': _number(_protein),
        'carbs_g': _number(_carbs),
        'fat_g': _number(_fat),
        'fiber_g': _number(_fiber),
        'sugar_g': _number(_sugar),
        'sodium_mg': _number(_sodium),
      });

  Widget _numberField(TextEditingController controller, String label,
          {bool decimal = false}) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: label),
      );

  Widget _responsivePair(Widget first, Widget second) => LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 520
            ? Column(children: [
                first,
                const SizedBox(height: NovaSpacing.md),
                second
              ])
            : Row(children: [
                Expanded(child: first),
                const SizedBox(width: NovaSpacing.md),
                Expanded(child: second)
              ]),
      );

  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  void _markDirty() {
    if (mounted && !_loading && !_dirty) setState(() => _dirty = true);
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text('Your custom-food changes have not been saved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() {
        _completed = true;
        _dirty = false;
      });
      await Future<void>.delayed(Duration.zero);
      if (mounted) context.pop();
    }
  }
}

class _WizardProgress extends StatelessWidget {
  const _WizardProgress({required this.step, required this.titles});
  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) => NovaCard(
        color: NovaColors.glass,
        accentColor: NovaColors.electric,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: NovaColors.premiumGradient,
                    borderRadius: BorderRadius.circular(NovaRadius.sm),
                    boxShadow: NovaShadows.glow(NovaColors.blue),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${step + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: NovaSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STEP ${step + 1} OF ${titles.length}',
                        style: const TextStyle(
                          color: NovaColors.mint,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        titles[step],
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(((step + 1) / titles.length) * 100).round()}%',
                  style: const TextStyle(
                    color: NovaColors.graphite,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: NovaSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(NovaRadius.pill),
              child: LinearProgressIndicator(
                value: (step + 1) / titles.length,
                minHeight: 8,
                backgroundColor: NovaColors.ink,
              ),
            ),
          ],
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard(
      {required this.icon, required this.message, required this.color});
  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => NovaCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(width: NovaSpacing.md),
          Expanded(child: Text(message)),
        ]),
      );
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.preview, required this.title});
  final MacroPreview preview;
  final String title;

  @override
  Widget build(BuildContext context) => NovaCard(
        color: NovaColors.panelRaised,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(title: title),
          const SizedBox(height: NovaSpacing.md),
          Text('${preview.caloriesKcal.toStringAsFixed(0)} kcal',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: NovaSpacing.sm),
          _MacroLine(preview: preview),
        ]),
      );
}

class _MacroLine extends StatelessWidget {
  const _MacroLine({required this.preview});
  final MacroPreview preview;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: NovaSpacing.sm,
        runSpacing: NovaSpacing.sm,
        children: [
          NovaBadge(
              label: 'P ${preview.proteinG.toStringAsFixed(1)}g',
              color: NovaColors.coral),
          NovaBadge(
              label: 'C ${preview.carbsG.toStringAsFixed(1)}g',
              color: NovaColors.gold),
          NovaBadge(
              label: 'F ${preview.fatG.toStringAsFixed(1)}g',
              color: NovaColors.violet),
          NovaBadge(
              label: 'Fibre ${preview.fiberG.toStringAsFixed(1)}g',
              color: NovaColors.lime),
        ],
      );
}

class _RangeCard extends StatelessWidget {
  const _RangeCard({required this.ranges});
  final Map<String, NutrientEstimateRange> ranges;

  @override
  Widget build(BuildContext context) => NovaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'Likely range'),
          const SizedBox(height: NovaSpacing.sm),
          ...['calories_kcal', 'protein_g', 'carbs_g', 'fat_g']
              .where(ranges.containsKey)
              .map((key) {
            final value = ranges[key]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                  '${_nutrientLabel(key)}: ${_format(value.minimum)} – ${_format(value.maximum)}'),
            );
          }),
        ]),
      );
}

MacroPreview _macroFrom(Map<String, double> values) => MacroPreview(
      caloriesKcal: values['calories_kcal'] ?? 0,
      proteinG: values['protein_g'] ?? 0,
      carbsG: values['carbs_g'] ?? 0,
      fatG: values['fat_g'] ?? 0,
      fiberG: values['fiber_g'] ?? 0,
      sugarG: values['sugar_g'] ?? 0,
      sodiumMg: values['sodium_mg'] ?? 0,
    );

String _format(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map((part) =>
        part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _nutrientLabel(String value) =>
    _label(value.replaceAll('_g', '').replaceAll('_kcal', ''));

const _preparations = [
  'raw',
  'cooked',
  'boiled',
  'fried',
  'baked',
  'grilled',
  'roasted',
  'steamed',
  'prepared',
  'as_sold',
  'unspecified',
];

const _servingUnits = [
  'serving',
  'piece',
  'bowl',
  'cup',
  'slice',
  'scoop',
  'packet',
  'gram',
  'ml',
];
