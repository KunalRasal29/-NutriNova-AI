import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

Future<void> showNutritionTargetsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: NovaColors.panel,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.92,
      child: _NutritionTargetsSheet(),
    ),
  );
}

class _NutritionTargetsSheet extends ConsumerStatefulWidget {
  const _NutritionTargetsSheet();

  @override
  ConsumerState<_NutritionTargetsSheet> createState() =>
      _NutritionTargetsSheetState();
}

class _NutritionTargetsSheetState
    extends ConsumerState<_NutritionTargetsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _water = TextEditingController();
  NutritionTargetPlan? _current;
  NutritionTargetPlan? _estimate;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _calories,
      _protein,
      _carbs,
      _fat,
      _fiber,
      _water,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NovaSpacing.lg,
          NovaSpacing.xs,
          NovaSpacing.lg,
          NovaSpacing.lg,
        ),
        child: _loading
            ? const LoadingList()
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Text(
                      'Nutrition targets',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: NovaSpacing.xs),
                    const Text(
                      'Your starting targets are personalized from onboarding and remain fully editable.',
                      style: TextStyle(color: NovaColors.graphite),
                    ),
                    const SizedBox(height: NovaSpacing.lg),
                    if (_error != null) ...[
                      ErrorBanner(message: friendlyErrorMessage(_error!)),
                      const SizedBox(height: NovaSpacing.md),
                    ],
                    NovaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Daily targets'),
                          const SizedBox(height: NovaSpacing.md),
                          _TargetField(
                            controller: _calories,
                            label: 'Calories',
                            suffix: 'kcal',
                            minimum: 1000,
                            maximum: 6000,
                          ),
                          const SizedBox(height: NovaSpacing.md),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _TargetField(
                                  controller: _protein,
                                  label: 'Protein',
                                  suffix: 'g',
                                  minimum: 20,
                                  maximum: 400,
                                ),
                              ),
                              const SizedBox(width: NovaSpacing.md),
                              Expanded(
                                child: _TargetField(
                                  controller: _carbs,
                                  label: 'Carbs',
                                  suffix: 'g',
                                  minimum: 20,
                                  maximum: 800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: NovaSpacing.md),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _TargetField(
                                  controller: _fat,
                                  label: 'Fat',
                                  suffix: 'g',
                                  minimum: 20,
                                  maximum: 300,
                                ),
                              ),
                              const SizedBox(width: NovaSpacing.md),
                              Expanded(
                                child: _TargetField(
                                  controller: _fiber,
                                  label: 'Fibre',
                                  suffix: 'g',
                                  minimum: 5,
                                  maximum: 100,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: NovaSpacing.md),
                          _TargetField(
                            controller: _water,
                            label: 'Water',
                            suffix: 'ml',
                            minimum: 500,
                            maximum: 10000,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NovaSpacing.md),
                    NovaCard(
                      color: NovaColors.panelRaised,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: NovaColors.blue,
                              ),
                              SizedBox(width: NovaSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Wellness estimate',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: NovaSpacing.sm),
                          Text(
                            _current?.disclaimer ??
                                'These targets are not medical advice.',
                          ),
                          if ((_current?.method ?? '').isNotEmpty) ...[
                            const SizedBox(height: NovaSpacing.sm),
                            Text(
                              _current!.customized
                                  ? 'Method: edited by you'
                                  : 'Method: personalized onboarding estimate',
                              style: const TextStyle(
                                color: NovaColors.graphite,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_estimate != null) ...[
                      const SizedBox(height: NovaSpacing.md),
                      _EstimatePreview(
                        plan: _estimate!,
                        applying: _saving,
                        onApply: _applyEstimate,
                      ),
                    ],
                    const SizedBox(height: NovaSpacing.lg),
                    NovaButton.primary(
                      label: _saving ? 'Saving...' : 'Save edited targets',
                      icon: Icons.save_outlined,
                      onPressed: _saving ? null : _saveCustomTargets,
                    ),
                    const SizedBox(height: NovaSpacing.sm),
                    NovaButton.secondary(
                      label: 'Preview recalculated targets',
                      icon: Icons.calculate_outlined,
                      onPressed: _saving ? null : _previewEstimate,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _load() async {
    try {
      final plan =
          await ref.read(nutritionRepositoryProvider).nutritionTargets();
      if (!mounted) return;
      _hydrate(plan);
      setState(() {
        _current = plan;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _saveCustomTargets() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final plan =
          await ref.read(nutritionRepositoryProvider).updateNutritionTargets({
        'calories_kcal': _calories.text.trim(),
        'protein_g': _protein.text.trim(),
        'carbs_g': _carbs.text.trim(),
        'fat_g': _fat.text.trim(),
        'fiber_g': _fiber.text.trim(),
        'water_ml': _water.text.trim(),
      });
      if (!mounted) return;
      _hydrate(plan);
      ref.invalidate(nutritionTargetsProvider);
      ref.invalidate(dashboardProvider);
      setState(() {
        _current = plan;
        _estimate = null;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nutrition targets updated')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(error);
        _saving = false;
      });
    }
  }

  Future<void> _previewEstimate() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final estimate = await ref
          .read(nutritionRepositoryProvider)
          .estimateNutritionTargets();
      if (!mounted) return;
      setState(() {
        _estimate = estimate;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(error);
        _saving = false;
      });
    }
  }

  Future<void> _applyEstimate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply recalculated targets?'),
        content: const Text(
          'This replaces your current targets. Existing meal history and nutrition snapshots will not change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final plan = await ref
          .read(nutritionRepositoryProvider)
          .applyEstimatedNutritionTargets();
      if (!mounted) return;
      _hydrate(plan);
      ref.invalidate(nutritionTargetsProvider);
      ref.invalidate(dashboardProvider);
      setState(() {
        _current = plan;
        _estimate = null;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personalized targets applied')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(error);
        _saving = false;
      });
    }
  }

  void _hydrate(NutritionTargetPlan plan) {
    _calories.text = _format(plan.caloriesKcal);
    _protein.text = _format(plan.proteinG);
    _carbs.text = _format(plan.carbsG);
    _fat.text = _format(plan.fatG);
    _fiber.text = _format(plan.fiberG);
    _water.text = _format(plan.waterMl);
  }
}

class _TargetField extends StatelessWidget {
  const _TargetField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.minimum,
    required this.maximum,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final double minimum;
  final double maximum;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: (value) {
        final parsed = double.tryParse(value?.trim() ?? '');
        if (parsed == null) return 'Enter a number';
        if (parsed < minimum || parsed > maximum) return 'Check value';
        return null;
      },
    );
  }
}

class _EstimatePreview extends StatelessWidget {
  const _EstimatePreview({
    required this.plan,
    required this.applying,
    required this.onApply,
  });

  final NutritionTargetPlan plan;
  final bool applying;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Recalculated preview'),
          const SizedBox(height: NovaSpacing.sm),
          Text(
            '${_format(plan.caloriesKcal)} kcal  •  '
            'P ${_format(plan.proteinG)}g  •  '
            'C ${_format(plan.carbsG)}g  •  '
            'F ${_format(plan.fatG)}g',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: NovaSpacing.xs),
          Text(
            'Fibre ${_format(plan.fiberG)}g  •  '
            'Water ${_format(plan.waterMl)}ml',
          ),
          for (final assumption in plan.assumptions) ...[
            const SizedBox(height: NovaSpacing.xs),
            Text(
              '• $assumption',
              style: const TextStyle(color: NovaColors.graphite),
            ),
          ],
          const SizedBox(height: NovaSpacing.md),
          NovaButton.primary(
            label: applying ? 'Applying...' : 'Apply this estimate',
            icon: Icons.check,
            onPressed: applying ? null : onApply,
          ),
        ],
      ),
    );
  }
}

String _format(double value) {
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}
