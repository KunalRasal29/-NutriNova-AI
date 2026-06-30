import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

final photoReviewProvider =
    FutureProvider.family<PhotoReview, String>((ref, analysisId) {
  return ref.watch(nutritionRepositoryProvider).photoReview(analysisId);
});

class PhotoReviewScreen extends ConsumerStatefulWidget {
  const PhotoReviewScreen({
    required this.analysisId,
    super.key,
    this.initialMealType = 'lunch',
  });

  final String analysisId;
  final String initialMealType;

  @override
  ConsumerState<PhotoReviewScreen> createState() => _PhotoReviewScreenState();
}

class _PhotoReviewScreenState extends ConsumerState<PhotoReviewScreen> {
  late String _mealType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType;
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(photoReviewProvider(widget.analysisId));
    return NovaScaffold(
      title: 'Review photo',
      body: reviewState.when(
        data: (review) => ListView(
          padding: const EdgeInsets.all(NovaSpacing.lg),
          children: [
            NovaBadge(
              label: review.status.replaceAll('_', ' '),
              icon: Icons.verified_outlined,
              color: NovaColors.gold,
            ),
            const SizedBox(height: NovaSpacing.lg),
            if (review.imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    review.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: NovaColors.border,
                      child: Center(child: Icon(Icons.image_not_supported)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NovaSpacing.lg),
            ],
            NovaCard(child: Text(review.disclaimer)),
            const SizedBox(height: NovaSpacing.lg),
            _TotalPreview(preview: review.totalPreview),
            if (review.warnings.isNotEmpty) ...[
              const SizedBox(height: NovaSpacing.md),
              _WarningList(warnings: review.warnings),
            ],
            const SizedBox(height: NovaSpacing.lg),
            if (review.items.isEmpty) ...[
              NovaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Analysis pending'),
                    const SizedBox(height: NovaSpacing.sm),
                    Text(
                      review.status == 'failed'
                          ? 'Analysis failed. Try another photo or add foods manually.'
                          : 'Analysis is still processing. Refresh in a moment.',
                    ),
                    const SizedBox(height: NovaSpacing.md),
                    NovaButton.secondary(
                      label: 'Refresh',
                      icon: Icons.refresh,
                      onPressed: () => ref
                          .invalidate(photoReviewProvider(widget.analysisId)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NovaSpacing.md),
            ] else ...[
              for (final food in review.items) ...[
                _PhotoFoodTile(analysisId: widget.analysisId, item: food),
                const SizedBox(height: NovaSpacing.md),
              ],
            ],
            NovaButton.secondary(
              label: 'Add missing item',
              icon: Icons.add,
              onPressed: () async {
                final added = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _ManualPhotoFoodSheet(
                    analysisId: widget.analysisId,
                  ),
                );
                if (added == true) {
                  ref.invalidate(photoReviewProvider(widget.analysisId));
                }
              },
            ),
            const SizedBox(height: NovaSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _mealType,
              decoration: const InputDecoration(labelText: 'Save to meal'),
              items: const [
                DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
                DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                DropdownMenuItem(value: 'snack', child: Text('Snack')),
              ],
              onChanged: (value) =>
                  setState(() => _mealType = value ?? _mealType),
            ),
            const SizedBox(height: NovaSpacing.md),
            NovaButton.primary(
              label: _saving ? 'Saving...' : 'Confirm as meal',
              icon: Icons.check,
              onPressed: _saving || !_canConfirm(review)
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await ref
                            .read(nutritionRepositoryProvider)
                            .confirmPhotoMeal(widget.analysisId, _mealType);
                        ref.invalidate(dashboardProvider);
                        ref.invalidate(todayMealLogsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Photo meal saved')),
                          );
                          context.go('/meals');
                        }
                      } catch (error) {
                        if (context.mounted) {
                          setState(() => _saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
        error: (error, _) => ErrorPanel(
          message: error.toString(),
          onRetry: () => ref.invalidate(photoReviewProvider(widget.analysisId)),
        ),
        loading: () => const LoadingList(),
      ),
    );
  }

  bool _canConfirm(PhotoReview review) {
    final activeItems = review.items.where((item) => !item.isRemoved);
    if (activeItems.isEmpty) return false;
    return activeItems.every(
      (item) => item.matchedFoodId.isNotEmpty && item.grams > 0,
    );
  }
}

class _TotalPreview extends StatelessWidget {
  const _TotalPreview({required this.preview});

  final MacroPreview preview;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Meal preview'),
          const SizedBox(height: NovaSpacing.md),
          Text(
            '${preview.caloriesKcal.toStringAsFixed(0)} kcal',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: NovaSpacing.sm),
          _MacroLine(preview: preview),
        ],
      ),
    );
  }
}

class _WarningList extends StatelessWidget {
  const _WarningList({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Needs review'),
          const SizedBox(height: NovaSpacing.sm),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 18,
                    color: NovaColors.gold,
                  ),
                  const SizedBox(width: NovaSpacing.sm),
                  Expanded(child: Text(warning)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoFoodTile extends ConsumerStatefulWidget {
  const _PhotoFoodTile({required this.analysisId, required this.item});

  final String analysisId;
  final PhotoReviewItem item;

  @override
  ConsumerState<_PhotoFoodTile> createState() => _PhotoFoodTileState();
}

class _PhotoFoodTileState extends ConsumerState<_PhotoFoodTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    decoration:
                        item.isRemoved ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              NovaBadge(
                label:
                    '${(item.confidence * 100).toStringAsFixed(0)}% confidence',
                color: item.isRemoved ? NovaColors.graphite : NovaColors.mint,
              ),
            ],
          ),
          if (item.addedManually) ...[
            const SizedBox(height: NovaSpacing.sm),
            const NovaBadge(label: 'Added manually', icon: Icons.edit),
          ],
          if (item.sourceBadges.isNotEmpty) ...[
            const SizedBox(height: NovaSpacing.sm),
            Wrap(
              spacing: NovaSpacing.xs,
              runSpacing: NovaSpacing.xs,
              children: [
                for (final source in item.sourceBadges)
                  NovaBadge(
                    label: source,
                    icon: Icons.dataset_outlined,
                  ),
              ],
            ),
          ],
          const SizedBox(height: NovaSpacing.md),
          Wrap(
            spacing: NovaSpacing.md,
            runSpacing: NovaSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              QuantityStepper(
                value: item.quantity,
                unit: item.unit,
                isLoading: _busy,
                onDecrement: item.isRemoved
                    ? null
                    : () => _mutate(() async {
                          await ref
                              .read(nutritionRepositoryProvider)
                              .decrementPhotoFood(item.id);
                        }),
                onIncrement: item.isRemoved
                    ? null
                    : () => _mutate(() async {
                          await ref
                              .read(nutritionRepositoryProvider)
                              .incrementPhotoFood(item.id);
                        }),
              ),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  initialValue:
                      _unitOptions.contains(item.unit) ? item.unit : 'serving',
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: [
                    for (final unit in _unitOptions)
                      DropdownMenuItem(value: unit, child: Text(_label(unit))),
                  ],
                  onChanged: item.isRemoved || _busy
                      ? null
                      : (unit) {
                          if (unit == null) return;
                          _mutate(() async {
                            await ref
                                .read(nutritionRepositoryProvider)
                                .updatePhotoFood(
                                  detectedFoodId: item.id,
                                  unit: unit,
                                );
                          });
                        },
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.scale_outlined, size: 16),
                label: Text('${item.grams.toStringAsFixed(0)}g'),
                onPressed:
                    item.isRemoved || _busy ? null : () => _editGrams(item),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.sm),
          Wrap(
            spacing: NovaSpacing.sm,
            children: [
              const Text('Eaten'),
              ActionChip(
                label: const Text('All'),
                onPressed: item.isRemoved || _busy
                    ? null
                    : () => _mutate(() async {
                          await ref
                              .read(nutritionRepositoryProvider)
                              .updatePhotoFood(
                                detectedFoodId: item.id,
                                totalGrams: item.grams,
                              );
                        }),
              ),
              ActionChip(
                label: const Text('75%'),
                onPressed: item.isRemoved || _busy
                    ? null
                    : () => _mutate(() async {
                          await ref
                              .read(nutritionRepositoryProvider)
                              .updatePhotoFood(
                                detectedFoodId: item.id,
                                totalGrams: item.grams * 0.75,
                              );
                        }),
              ),
              ActionChip(
                label: const Text('Half'),
                onPressed: item.isRemoved || _busy
                    ? null
                    : () => _mutate(() async {
                          await ref
                              .read(nutritionRepositoryProvider)
                              .updatePhotoFood(
                                detectedFoodId: item.id,
                                totalGrams: item.grams * 0.5,
                              );
                        }),
              ),
              ActionChip(
                label: const Text('Custom'),
                onPressed:
                    item.isRemoved || _busy ? null : () => _editGrams(item),
              ),
            ],
          ),
          if (item.alternatives.isNotEmpty) ...[
            const SizedBox(height: NovaSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue:
                  item.alternatives.any((food) => food.id == item.matchedFoodId)
                      ? item.matchedFoodId
                      : null,
              decoration: const InputDecoration(labelText: 'Food match'),
              items: item.alternatives
                  .map(
                    (food) => DropdownMenuItem(
                      value: food.id,
                      child: Text(food.name),
                    ),
                  )
                  .toList(),
              onChanged: item.isRemoved
                  ? null
                  : (foodId) {
                      if (foodId == null) return;
                      _mutate(() async {
                        await ref
                            .read(nutritionRepositoryProvider)
                            .updatePhotoFood(
                              detectedFoodId: item.id,
                              matchedFoodId: foodId,
                            );
                      });
                    },
            ),
          ],
          if (item.warnings.isNotEmpty) ...[
            const SizedBox(height: NovaSpacing.sm),
            Wrap(
              spacing: NovaSpacing.sm,
              runSpacing: NovaSpacing.sm,
              children: [
                for (final warning in item.warnings)
                  NovaBadge(
                    label: warning,
                    icon: Icons.warning_amber,
                    color: NovaColors.gold,
                  ),
              ],
            ),
          ],
          const Divider(),
          NutritionPreviewBar(
            caloriesKcal: item.preview.caloriesKcal,
            proteinG: item.preview.proteinG,
            carbsG: item.preview.carbsG,
            fatG: item.preview.fatG,
            compact: true,
          ),
          const SizedBox(height: NovaSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => _mutate(() async {
                        await ref
                            .read(nutritionRepositoryProvider)
                            .updatePhotoFood(
                              detectedFoodId: item.id,
                              isRemoved: !item.isRemoved,
                            );
                      }),
              icon: Icon(
                item.isRemoved ? Icons.restore : Icons.delete_outline,
              ),
              label: Text(item.isRemoved ? 'Restore' : 'Remove'),
            ),
          ),
        ],
      ),
    );
  }

  static const _unitOptions = [
    'serving',
    'gram',
    'egg',
    'piece',
    'slice',
    'bowl',
    'cup',
    'scoop',
  ];

  String _label(String unit) {
    return unit[0].toUpperCase() + unit.substring(1).replaceAll('_', ' ');
  }

  Future<void> _editGrams(PhotoReviewItem item) async {
    final controller = TextEditingController(
      text: item.grams <= 0 ? '' : item.grams.toStringAsFixed(0),
    );
    final grams = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: 'Edit grams for ${item.name}'),
              const SizedBox(height: NovaSpacing.md),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total grams eaten',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
              ),
              const SizedBox(height: NovaSpacing.lg),
              NovaButton.primary(
                label: 'Apply grams',
                icon: Icons.check,
                onPressed: () {
                  Navigator.of(context).pop(double.tryParse(controller.text));
                },
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (grams == null || grams <= 0) return;
    await _mutate(() async {
      await ref.read(nutritionRepositoryProvider).updatePhotoFood(
            detectedFoodId: item.id,
            totalGrams: grams,
          );
    });
  }

  Future<void> _mutate(Future<void> Function() update) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await update();
      ref.invalidate(photoReviewProvider(widget.analysisId));
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MacroLine extends StatelessWidget {
  const _MacroLine({required this.preview});

  final MacroPreview preview;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${preview.caloriesKcal.toStringAsFixed(0)} kcal • '
      'P ${preview.proteinG.toStringAsFixed(1)}g • '
      'C ${preview.carbsG.toStringAsFixed(1)}g • '
      'F ${preview.fatG.toStringAsFixed(1)}g',
    );
  }
}

class _ManualPhotoFoodSheet extends ConsumerStatefulWidget {
  const _ManualPhotoFoodSheet({required this.analysisId});

  final String analysisId;

  @override
  ConsumerState<_ManualPhotoFoodSheet> createState() =>
      _ManualPhotoFoodSheetState();
}

class _ManualPhotoFoodSheetState extends ConsumerState<_ManualPhotoFoodSheet> {
  final _query = TextEditingController(text: 'rice');
  final _quantity = TextEditingController(text: '1');
  final _grams = TextEditingController();
  String _unit = 'serving';
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Add missing item'),
            const SizedBox(height: NovaSpacing.md),
            TextField(
              controller: _query,
              decoration: const InputDecoration(
                labelText: 'Search food',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NovaSpacing.md),
            SizedBox(
              height: 180,
              child: foods.when(
                data: (items) => ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final food = items[index];
                    final selected = _selectedFood?.id == food.id;
                    return ListTile(
                      selected: selected,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected ? NovaColors.mint : NovaColors.graphite,
                      ),
                      title: Text(food.name),
                      subtitle: SourceConfidenceBadges(
                        source: food.sourceBadge,
                        confidence: food.confidenceScore,
                        verified: food.verified,
                        classification: food.dataClassification,
                      ),
                      onTap: () => setState(() => _selectedFood = food),
                    );
                  },
                ),
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
                  ),
                ),
                const SizedBox(width: NovaSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: const [
                      DropdownMenuItem(
                          value: 'serving', child: Text('Serving')),
                      DropdownMenuItem(value: 'gram', child: Text('Gram')),
                      DropdownMenuItem(value: 'egg', child: Text('Egg')),
                      DropdownMenuItem(value: 'piece', child: Text('Piece')),
                      DropdownMenuItem(value: 'bowl', child: Text('Bowl')),
                      DropdownMenuItem(value: 'cup', child: Text('Cup')),
                      DropdownMenuItem(value: 'scoop', child: Text('Scoop')),
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
                labelText: 'Total grams if known',
                prefixIcon: Icon(Icons.scale_outlined),
              ),
            ),
            const SizedBox(height: NovaSpacing.lg),
            NovaButton.primary(
              label: _saving ? 'Adding...' : 'Add to review',
              icon: Icons.add,
              onPressed: _selectedFood == null || _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await ref
                            .read(nutritionRepositoryProvider)
                            .addManualPhotoFood(
                              analysisId: widget.analysisId,
                              foodId: _selectedFood!.id,
                              quantity: double.tryParse(_quantity.text),
                              unit: _unit,
                              totalGrams: double.tryParse(_grams.text),
                            );
                        if (context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      } catch (error) {
                        if (context.mounted) {
                          setState(() => _saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
