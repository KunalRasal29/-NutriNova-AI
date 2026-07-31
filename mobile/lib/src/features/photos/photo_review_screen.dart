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
      title: 'Review meal scan',
      body: reviewState.when(
        data: _buildReview,
        error: (error, _) => ErrorPanel(
          message: friendlyErrorMessage(error),
          onRetry: () => ref.invalidate(photoReviewProvider(widget.analysisId)),
        ),
        loading: () => const _ReviewLoadingState(),
      ),
    );
  }

  Widget _buildReview(PhotoReview review) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NovaSpacing.lg,
        NovaSpacing.lg,
        NovaSpacing.lg,
        120,
      ),
      children: [
        _ReviewHero(review: review),
        const SizedBox(height: NovaSpacing.lg),
        _DisclaimerCard(message: review.disclaimer),
        const SizedBox(height: NovaSpacing.lg),
        _MealTypeCard(
          value: _mealType,
          onChanged: (value) => setState(() => _mealType = value),
        ),
        const SizedBox(height: NovaSpacing.lg),
        if (review.isProcessing) ...[
          _ReviewStateCard(
            icon: Icons.hourglass_top,
            title: 'Analyzing meal',
            message: 'Refresh in a moment if the results are not ready.',
            actionLabel: 'Refresh',
            actionIcon: Icons.refresh,
            onAction: () =>
                ref.invalidate(photoReviewProvider(widget.analysisId)),
          ),
          const SizedBox(height: NovaSpacing.lg),
        ] else if (review.isFailed) ...[
          _ReviewStateCard(
            icon: Icons.error_outline,
            title: 'Analysis failed',
            message: 'Try another photo or add the visible foods manually.',
            danger: true,
            actionLabel: 'Add missing food',
            actionIcon: Icons.add,
            onAction: _showAddMissingFood,
          ),
          const SizedBox(height: NovaSpacing.lg),
        ] else if (review.items.isEmpty) ...[
          _ReviewStateCard(
            icon: Icons.no_food_outlined,
            title: 'No foods detected',
            message: 'Add the foods you can see and save the meal normally.',
            actionLabel: 'Add food',
            actionIcon: Icons.add,
            onAction: _showAddMissingFood,
          ),
          const SizedBox(height: NovaSpacing.lg),
        ],
        _DetectedFoodsSection(
          analysisId: widget.analysisId,
          review: review,
          onChanged: () =>
              ref.invalidate(photoReviewProvider(widget.analysisId)),
        ),
        const SizedBox(height: NovaSpacing.lg),
        NovaButton.secondary(
          label: 'Add missing food',
          icon: Icons.add,
          onPressed: _showAddMissingFood,
        ),
        const SizedBox(height: NovaSpacing.md),
        _ConfirmMealCard(
          review: review,
          mealType: _mealType,
          saving: _saving,
          onConfirm: review.hasConfirmableItems && !review.isProcessing
              ? () => _confirmMeal(review)
              : null,
        ),
      ],
    );
  }

  Future<void> _showAddMissingFood() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: NovaColors.panel,
      builder: (_) => _ManualPhotoFoodSheet(
        analysisId: widget.analysisId,
        mealType: _mealType,
      ),
    );
    if (added == true) {
      ref.invalidate(photoReviewProvider(widget.analysisId));
    }
  }

  Future<void> _confirmMeal(PhotoReview review) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(nutritionRepositoryProvider)
          .confirmPhotoMeal(review.analysisId, _mealType);
      ref.invalidate(dashboardProvider);
      ref.invalidate(todayMealLogsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${_mealLabel(_mealType)}')),
      );
      context.go('/meals');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }
}

class _ReviewHero extends StatelessWidget {
  const _ReviewHero({required this.review});

  final PhotoReview review;

  @override
  Widget build(BuildContext context) {
    final activeCount = review.activeItems.length;
    final removedCount = review.removedItems.length;
    return NovaCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (review.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
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
          Padding(
            padding: const EdgeInsets.all(NovaSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: NovaSpacing.sm,
                  runSpacing: NovaSpacing.sm,
                  children: [
                    NovaBadge(
                      label: _statusLabel(review.status),
                      icon: review.isConfirmed
                          ? Icons.check_circle_outline
                          : Icons.auto_awesome,
                      color: review.isFailed
                          ? NovaColors.danger
                          : review.isProcessing
                              ? NovaColors.gold
                              : NovaColors.mint,
                    ),
                    NovaBadge(
                      label: '$activeCount active',
                      icon: Icons.restaurant_menu,
                      color: NovaColors.blue,
                    ),
                    if (removedCount > 0)
                      NovaBadge(
                        label: '$removedCount removed',
                        icon: Icons.delete_outline,
                        color: NovaColors.graphite,
                      ),
                  ],
                ),
                const SizedBox(height: NovaSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Meal total',
                            style: TextStyle(
                              color: NovaColors.graphite,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: NovaSpacing.xs),
                          Text(
                            '${review.totalPreview.caloriesKcal.toStringAsFixed(0)} kcal',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.local_fire_department,
                      color: NovaColors.mint,
                      size: 36,
                    ),
                  ],
                ),
                const SizedBox(height: NovaSpacing.lg),
                _MacroGrid(preview: review.totalPreview),
                if (review.warnings.isNotEmpty) ...[
                  const SizedBox(height: NovaSpacing.lg),
                  _WarningWrap(warnings: review.warnings),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroGrid extends StatelessWidget {
  const _MacroGrid({required this.preview});

  final MacroPreview preview;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MacroMetric('Protein', '${preview.proteinG.toStringAsFixed(1)}g',
          Icons.fitness_center, NovaColors.coral),
      _MacroMetric('Carbs', '${preview.carbsG.toStringAsFixed(1)}g',
          Icons.grain, NovaColors.gold),
      _MacroMetric('Fat', '${preview.fatG.toStringAsFixed(1)}g', Icons.opacity,
          NovaColors.violet),
      _MacroMetric('Fiber', '${preview.fiberG.toStringAsFixed(1)}g',
          Icons.spa_outlined, NovaColors.mint),
    ];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: NovaSpacing.sm,
      crossAxisSpacing: NovaSpacing.sm,
      childAspectRatio: 2.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final metric in metrics)
          DecoratedBox(
            decoration: BoxDecoration(
              color: NovaColors.panelSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NovaColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(NovaSpacing.md),
              child: Row(
                children: [
                  Icon(metric.icon, color: metric.color, size: 20),
                  const SizedBox(width: NovaSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          metric.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: NovaColors.graphite,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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

class _MacroMetric {
  const _MacroMetric(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      color: NovaColors.panelSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: NovaColors.gold),
          const SizedBox(width: NovaSpacing.md),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealTypeCard extends StatelessWidget {
  const _MealTypeCard({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Save meal to'),
          const SizedBox(height: NovaSpacing.md),
          MealTypeSelector(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _DetectedFoodsSection extends StatelessWidget {
  const _DetectedFoodsSection({
    required this.analysisId,
    required this.review,
    required this.onChanged,
  });

  final String analysisId;
  final PhotoReview review;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (review.items.isEmpty) return const SizedBox.shrink();
    final activeItems = review.activeItems;
    final removedItems = review.removedItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Detected foods',
          action: Text(
            '${activeItems.length} to save',
            style: const TextStyle(
              color: NovaColors.graphite,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: NovaSpacing.md),
        for (final item in [...activeItems, ...removedItems]) ...[
          _PhotoFoodTile(
            analysisId: analysisId,
            item: item,
            onChanged: onChanged,
          ),
          const SizedBox(height: NovaSpacing.md),
        ],
      ],
    );
  }
}

class _PhotoFoodTile extends ConsumerStatefulWidget {
  const _PhotoFoodTile({
    required this.analysisId,
    required this.item,
    required this.onChanged,
  });

  final String analysisId;
  final PhotoReviewItem item;
  final VoidCallback onChanged;

  @override
  ConsumerState<_PhotoFoodTile> createState() => _PhotoFoodTileState();
}

class _PhotoFoodTileState extends ConsumerState<_PhotoFoodTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return NovaCard(
      color: item.isRemoved ? NovaColors.panelSoft : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            decoration: item.isRemoved
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.matchLabel,
                      style: const TextStyle(
                        color: NovaColors.graphite,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: NovaSpacing.sm),
              NovaBadge(
                label: item.isRemoved
                    ? 'Removed'
                    : '${(item.confidence * 100).toStringAsFixed(0)}%',
                icon: item.isRemoved
                    ? Icons.delete_outline
                    : Icons.speed_outlined,
                color: item.isRemoved
                    ? NovaColors.graphite
                    : item.needsAttention
                        ? NovaColors.gold
                        : NovaColors.mint,
              ),
            ],
          ),
          if (item.reasoning.isNotEmpty) ...[
            const SizedBox(height: NovaSpacing.sm),
            Text(
              item.reasoning,
              style: const TextStyle(color: NovaColors.graphite),
            ),
          ],
          if (item.estimateRangeLabel.isNotEmpty) ...[
            const SizedBox(height: NovaSpacing.sm),
            Text(
              'AI portion range: ${item.estimateRangeLabel}',
              style: const TextStyle(
                color: NovaColors.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: NovaSpacing.lg),
          _FoodNutritionStrip(item: item),
          const SizedBox(height: NovaSpacing.lg),
          _PortionControls(
            item: item,
            busy: _busy,
            onDecrement: item.isRemoved ? null : () => _changeQuantity(false),
            onIncrement: item.isRemoved ? null : () => _changeQuantity(true),
            onUnitChanged: item.isRemoved ? null : _changeUnit,
            onEditGrams: item.isRemoved ? null : () => _editGrams(item),
          ),
          if (item.alternatives.isNotEmpty) ...[
            const SizedBox(height: NovaSpacing.md),
            DropdownButtonFormField<String>(
              key: ValueKey('match-${item.id}-${item.matchedFoodId}'),
              initialValue:
                  item.alternatives.any((food) => food.id == item.matchedFoodId)
                      ? item.matchedFoodId
                      : null,
              decoration: const InputDecoration(
                labelText: 'Food match',
                prefixIcon: Icon(Icons.manage_search),
              ),
              items: [
                for (final food in item.alternatives)
                  DropdownMenuItem(
                    value: food.id,
                    child: Text(
                      food.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: item.isRemoved || _busy
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
          if (item.sourceBadges.isNotEmpty) ...[
            const SizedBox(height: NovaSpacing.md),
            Wrap(
              spacing: NovaSpacing.xs,
              runSpacing: NovaSpacing.xs,
              children: [
                for (final source in item.sourceBadges)
                  NovaBadge(label: source, icon: Icons.dataset_outlined),
              ],
            ),
          ],
          if (item.warnings.isNotEmpty) ...[
            const SizedBox(height: NovaSpacing.md),
            _WarningWrap(warnings: item.warnings),
          ],
          const SizedBox(height: NovaSpacing.md),
          DropdownButtonFormField<double>(
            key: ValueKey('eaten-${item.id}-${item.eatenPercentage}'),
            initialValue:
                [25.0, 50.0, 75.0, 100.0].contains(item.eatenPercentage)
                    ? item.eatenPercentage
                    : 100,
            decoration: const InputDecoration(
              labelText: 'How much did you eat?',
              prefixIcon: Icon(Icons.pie_chart_outline),
            ),
            items: const [
              DropdownMenuItem(value: 100, child: Text('All (100%)')),
              DropdownMenuItem(value: 75, child: Text('About 75%')),
              DropdownMenuItem(value: 50, child: Text('Half (50%)')),
              DropdownMenuItem(value: 25, child: Text('About 25%')),
            ],
            onChanged: item.isRemoved || _busy
                ? null
                : (value) {
                    if (value != null) _changeEatenPercentage(value);
                  },
          ),
          const SizedBox(height: NovaSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _toggleRemoved(item),
                  icon: Icon(
                    item.isRemoved ? Icons.restore : Icons.delete_outline,
                  ),
                  label: Text(item.isRemoved ? 'Restore item' : 'Remove item'),
                ),
              ),
              const SizedBox(width: NovaSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      item.isRemoved || _busy ? null : () => _editGrams(item),
                  icon: const Icon(Icons.scale_outlined),
                  label: const Text('Edit grams'),
                ),
              ),
            ],
          ),
          if (!item.isRemoved) ...[
            const SizedBox(height: NovaSpacing.sm),
            NovaButton.secondary(
              label: 'Split into separate foods',
              icon: Icons.call_split_outlined,
              onPressed: _busy ? null : () => _splitItem(item),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _changeQuantity(bool increment) {
    return _mutate(() async {
      if (increment) {
        await ref
            .read(nutritionRepositoryProvider)
            .incrementPhotoFood(widget.item.id);
      } else {
        await ref
            .read(nutritionRepositoryProvider)
            .decrementPhotoFood(widget.item.id);
      }
    });
  }

  Future<void> _changeUnit(String? unit) async {
    if (unit == null) return;
    await _mutate(() async {
      await ref.read(nutritionRepositoryProvider).updatePhotoFood(
            detectedFoodId: widget.item.id,
            unit: unit,
          );
    });
  }

  Future<void> _changeEatenPercentage(double percentage) async {
    await _mutate(() async {
      await ref.read(nutritionRepositoryProvider).applyEatenPercentage(
            widget.item.id,
            percentage,
          );
    });
  }

  Future<void> _splitItem(PhotoReviewItem item) async {
    final split = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: NovaColors.panel,
      builder: (_) => _SplitPhotoFoodSheet(item: item),
    );
    if (split == true) widget.onChanged();
  }

  Future<void> _toggleRemoved(PhotoReviewItem item) async {
    if (!item.isRemoved) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove this item?'),
          content: Text('${item.name} will not be saved with this meal.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _mutate(() async {
      await ref.read(nutritionRepositoryProvider).updatePhotoFood(
            detectedFoodId: item.id,
            isRemoved: !item.isRemoved,
          );
    });
  }

  Future<void> _editGrams(PhotoReviewItem item) async {
    final controller = TextEditingController(
      text: item.grams <= 0 ? '' : item.grams.toStringAsFixed(0),
    );
    final grams = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: NovaColors.panel,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: 'Total grams for ${item.name}'),
              const SizedBox(height: NovaSpacing.md),
              TextField(
                controller: controller,
                autofocus: true,
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
      widget.onChanged();
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _FoodNutritionStrip extends StatelessWidget {
  const _FoodNutritionStrip({required this.item});

  final PhotoReviewItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NovaColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NovaColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _NutritionValue(
                    label: 'Quantity',
                    value: item.portionLabel,
                    color: NovaColors.blue,
                  ),
                ),
                Expanded(
                  child: _NutritionValue(
                    label: 'Grams',
                    value: item.gramsLabel,
                    color: item.grams > 0 ? NovaColors.mint : NovaColors.gold,
                  ),
                ),
                Expanded(
                  child: _NutritionValue(
                    label: 'Calories',
                    value: item.preview.caloriesKcal.toStringAsFixed(0),
                    color: NovaColors.mint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: NovaSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _NutritionValue(
                    label: 'Protein',
                    value: '${item.preview.proteinG.toStringAsFixed(1)}g',
                    color: NovaColors.coral,
                  ),
                ),
                Expanded(
                  child: _NutritionValue(
                    label: 'Carbs',
                    value: '${item.preview.carbsG.toStringAsFixed(1)}g',
                    color: NovaColors.gold,
                  ),
                ),
                Expanded(
                  child: _NutritionValue(
                    label: 'Fat',
                    value: '${item.preview.fatG.toStringAsFixed(1)}g',
                    color: NovaColors.violet,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionValue extends StatelessWidget {
  const _NutritionValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: NovaColors.graphite,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PortionControls extends StatelessWidget {
  const _PortionControls({
    required this.item,
    required this.busy,
    required this.onDecrement,
    required this.onIncrement,
    required this.onUnitChanged,
    required this.onEditGrams,
  });

  final PhotoReviewItem item;
  final bool busy;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final ValueChanged<String?>? onUnitChanged;
  final VoidCallback? onEditGrams;

  static const _unitOptions = [
    'serving',
    'gram',
    'egg',
    'piece',
    'slice',
    'bowl',
    'cup',
    'glass',
    'scoop',
    'packet',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Adjust quantity',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: NovaSpacing.sm),
        Row(
          children: [
            Expanded(
              child: QuantityStepper(
                value: item.quantity,
                unit: item.unit,
                isLoading: busy,
                onDecrement: onDecrement,
                onIncrement: onIncrement,
              ),
            ),
            const SizedBox(width: NovaSpacing.sm),
            SizedBox(
              width: 132,
              child: DropdownButtonFormField<String>(
                key: ValueKey('unit-${item.id}-${item.unit}'),
                initialValue:
                    _unitOptions.contains(item.unit) ? item.unit : 'serving',
                decoration: const InputDecoration(labelText: 'Unit'),
                items: [
                  for (final unit in _unitOptions)
                    DropdownMenuItem(
                        value: unit, child: Text(_unitLabel(unit))),
                ],
                onChanged: busy ? null : onUnitChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: NovaSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onEditGrams,
                icon: const Icon(Icons.scale_outlined),
                label: Text(
                    item.grams > 0 ? 'Set ${item.gramsLabel}' : 'Set grams'),
              ),
            ),
            if (item.gramsPerUnit > 0) ...[
              const SizedBox(width: NovaSpacing.sm),
              Expanded(
                child: Text(
                  '${item.gramsPerUnit.toStringAsFixed(0)}g per ${_unitLabel(item.unit).toLowerCase()}',
                  style: const TextStyle(
                    color: NovaColors.graphite,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _WarningWrap extends StatelessWidget {
  const _WarningWrap({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: NovaSpacing.xs,
      runSpacing: NovaSpacing.xs,
      children: [
        for (final warning in warnings)
          NovaBadge(
            label: _warningLabel(warning),
            icon: Icons.warning_amber,
            color: NovaColors.gold,
          ),
      ],
    );
  }
}

class _ReviewStateCard extends StatelessWidget {
  const _ReviewStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        children: [
          Icon(
            icon,
            color: danger ? NovaColors.danger : NovaColors.gold,
            size: 36,
          ),
          const SizedBox(height: NovaSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: NovaSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NovaColors.graphite),
          ),
          if (actionLabel != null && actionIcon != null) ...[
            const SizedBox(height: NovaSpacing.lg),
            NovaButton.secondary(
              label: actionLabel!,
              icon: actionIcon!,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfirmMealCard extends StatelessWidget {
  const _ConfirmMealCard({
    required this.review,
    required this.mealType,
    required this.saving,
    required this.onConfirm,
  });

  final PhotoReview review;
  final String mealType;
  final bool saving;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final message = review.hasConfirmableItems
        ? 'Ready to save ${review.activeItems.length} item${review.activeItems.length == 1 ? '' : 's'} to ${_mealLabel(mealType)}.'
        : _disabledConfirmMessage(review);
    return NovaCard(
      color: NovaColors.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: NovaSpacing.md),
          NovaButton.primary(
            label: saving ? 'Saving...' : 'Save to ${_mealLabel(mealType)}',
            icon: Icons.check_circle_outline,
            onPressed: saving ? null : onConfirm,
          ),
        ],
      ),
    );
  }
}

class _SplitPhotoFoodSheet extends ConsumerStatefulWidget {
  const _SplitPhotoFoodSheet({required this.item});

  final PhotoReviewItem item;

  @override
  ConsumerState<_SplitPhotoFoodSheet> createState() =>
      _SplitPhotoFoodSheetState();
}

class _SplitPhotoFoodSheetState extends ConsumerState<_SplitPhotoFoodSheet> {
  final _query = TextEditingController();
  final _selected = <FoodSummary>[];
  final _grams = <String, TextEditingController>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(_refresh);
  }

  @override
  void dispose() {
    _query
      ..removeListener(_refresh)
      ..dispose();
    for (final controller in _grams.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    final results = query.isEmpty
        ? const AsyncValue<List<FoodSummary>>.data([])
        : ref.watch(foodSearchProvider(query));
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, inset + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: 'Split ${widget.item.name}'),
              const SizedBox(height: NovaSpacing.sm),
              const Text(
                'Choose at least two separate foods. The original AI item stays in history as removed.',
                style: TextStyle(color: NovaColors.graphite),
              ),
              const SizedBox(height: NovaSpacing.md),
              TextField(
                controller: _query,
                decoration: const InputDecoration(
                  labelText: 'Search a food to add',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: NovaSpacing.sm),
              SizedBox(
                height: query.isEmpty ? 0 : 180,
                child: results.when(
                  data: (foods) => ListView.builder(
                    itemCount: foods.length,
                    itemBuilder: (context, index) {
                      final food = foods[index];
                      final already =
                          _selected.any((item) => item.id == food.id);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(food.name),
                        trailing: Icon(
                          already
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color: already ? NovaColors.mint : NovaColors.blue,
                        ),
                        onTap: already ? null : () => _add(food),
                      );
                    },
                  ),
                  error: (error, _) => ErrorPanel(
                    message: friendlyErrorMessage(error),
                    onRetry: () => query.isEmpty
                        ? ref.invalidate(recentFoodsProvider)
                        : ref.invalidate(foodSearchProvider(query)),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
              if (_selected.isNotEmpty) ...[
                const SizedBox(height: NovaSpacing.md),
                const Text(
                  'Foods and grams',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: NovaSpacing.sm),
                for (final food in _selected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: NovaSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(child: Text(food.name)),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _grams[food.id],
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'grams'),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () => _remove(food),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: NovaSpacing.lg),
              NovaButton.primary(
                label: _saving ? 'Splitting...' : 'Apply split',
                icon: Icons.call_split_outlined,
                onPressed: _selected.length < 2 || _saving ? null : _saveSplit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _add(FoodSummary food) {
    final defaultGrams = widget.item.grams > 0
        ? widget.item.grams / (_selected.length + 2)
        : food.defaultServingGrams;
    setState(() {
      _selected.add(food);
      _grams[food.id] = TextEditingController(
        text: defaultGrams > 0 ? defaultGrams.toStringAsFixed(0) : '',
      );
      _query.clear();
    });
  }

  void _remove(FoodSummary food) {
    setState(() {
      _selected.removeWhere((item) => item.id == food.id);
      _grams.remove(food.id)?.dispose();
    });
  }

  Future<void> _saveSplit() async {
    final items = <Map<String, dynamic>>[];
    for (final food in _selected) {
      final grams = double.tryParse(_grams[food.id]?.text ?? '') ?? 0;
      if (grams <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter grams for ${food.name}.')),
        );
        return;
      }
      items.add({
        'food_id': food.id,
        'quantity_value': grams,
        'quantity_unit': 'gram',
        'total_grams': grams,
      });
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(nutritionRepositoryProvider)
          .splitPhotoFood(widget.item.id, items);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }
}

class _ManualPhotoFoodSheet extends ConsumerStatefulWidget {
  const _ManualPhotoFoodSheet({
    required this.analysisId,
    required this.mealType,
  });

  final String analysisId;
  final String mealType;

  @override
  ConsumerState<_ManualPhotoFoodSheet> createState() =>
      _ManualPhotoFoodSheetState();
}

class _ManualPhotoFoodSheetState extends ConsumerState<_ManualPhotoFoodSheet> {
  final _query = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _grams = TextEditingController();
  String _unit = 'serving';
  FoodSummary? _selectedFood;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(_refresh);
    _quantity.addListener(_refresh);
    _grams.addListener(_refresh);
  }

  @override
  void dispose() {
    _query
      ..removeListener(_refresh)
      ..dispose();
    _quantity
      ..removeListener(_refresh)
      ..dispose();
    _grams
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    final foods = query.isEmpty
        ? ref.watch(recentFoodsProvider)
        : ref.watch(foodSearchProvider(query));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Add missing food'),
              const SizedBox(height: NovaSpacing.md),
              TextField(
                controller: _query,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Search food',
                  hintText: 'rice, chicken, chapati, banana',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: NovaSpacing.sm),
              Wrap(
                spacing: NovaSpacing.xs,
                runSpacing: NovaSpacing.xs,
                children: [
                  for (final suggestion in const [
                    'rice',
                    'chapati',
                    'chicken',
                    'dal',
                    'banana',
                  ])
                    ActionChip(
                      label: Text(suggestion),
                      onPressed: () => _query.text = suggestion,
                    ),
                ],
              ),
              const SizedBox(height: NovaSpacing.md),
              SizedBox(
                height: 240,
                child: foods.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return EmptyState(
                        title: query.isEmpty
                            ? 'No recent foods yet'
                            : 'No results',
                        message: query.isEmpty
                            ? 'Search above to add the missing item.'
                            : 'Try a simpler food name or add it as a custom food later.',
                        icon: Icons.search_off,
                      );
                    }
                    return ListView.separated(
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
                                : Icons.add_circle_outline,
                            color: selected ? NovaColors.mint : NovaColors.blue,
                          ),
                          title: Text(
                            food.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${food.preview.caloriesKcal.toStringAsFixed(0)} kcal/100g • ${food.servingSummary}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => setState(() => _selectedFood = food),
                        );
                      },
                    );
                  },
                  error: (error, _) => ErrorPanel(
                    message: friendlyErrorMessage(error),
                    onRetry: () => query.isEmpty
                        ? ref.invalidate(recentFoodsProvider)
                        : ref.invalidate(foodSearchProvider(query)),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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
              if (_selectedFood != null) ...[
                const SizedBox(height: NovaSpacing.md),
                _ManualPreviewCard(
                  food: _selectedFood!,
                  grams: _computedTotalGrams(),
                ),
              ],
              const SizedBox(height: NovaSpacing.lg),
              NovaButton.primary(
                label: _saving ? 'Adding...' : 'Add to review',
                icon: Icons.add,
                onPressed:
                    _selectedFood == null || _saving ? null : _saveManualFood,
              ),
              const SizedBox(height: NovaSpacing.sm),
              NovaButton.secondary(
                label: 'Create custom food here',
                icon: Icons.edit_note_outlined,
                onPressed: _saving ? null : _createCustomFoodAndAdd,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  double _quantityValue() => double.tryParse(_quantity.text) ?? 1;

  double? _computedTotalGrams() {
    final typedGrams = double.tryParse(_grams.text);
    if (typedGrams != null && typedGrams > 0) return typedGrams;
    final quantity = _quantityValue();
    if (_unit == 'gram') return quantity;
    final servingGrams = _selectedFood?.defaultServingGrams ?? 0;
    if (servingGrams > 0) return servingGrams * quantity;
    return null;
  }

  Future<void> _saveManualFood() async {
    final food = _selectedFood;
    if (food == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(nutritionRepositoryProvider).addManualPhotoFood(
            analysisId: widget.analysisId,
            foodId: food.id,
            quantity: _quantityValue(),
            unit: _unit,
            totalGrams: _computedTotalGrams(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }

  Future<void> _createCustomFoodAndAdd() async {
    final food = await context.push<FoodDetail>(
      Uri(
        path: '/foods/custom',
        queryParameters: {
          'meal_type': widget.mealType,
          'return_to': 'photo',
        },
      ).toString(),
    );
    if (food == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(nutritionRepositoryProvider).addManualPhotoFood(
            analysisId: widget.analysisId,
            foodId: food.id,
            quantity: 1,
            unit: 'serving',
            totalGrams: food.defaultServingG,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }
}

class _ManualPreviewCard extends StatelessWidget {
  const _ManualPreviewCard({required this.food, required this.grams});

  final FoodSummary food;
  final double? grams;

  @override
  Widget build(BuildContext context) {
    final scale = (grams ?? 100) / 100;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NovaColors.panelSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NovaColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(food.name,
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: NovaSpacing.xs),
            Text(
              grams == null
                  ? 'Using 100g preview until grams are known'
                  : '${grams!.toStringAsFixed(0)}g preview',
              style: const TextStyle(color: NovaColors.graphite),
            ),
            const SizedBox(height: NovaSpacing.sm),
            NutritionPreviewBar(
              caloriesKcal: food.preview.caloriesKcal * scale,
              proteinG: food.preview.proteinG * scale,
              carbsG: food.preview.carbsG * scale,
              fatG: food.preview.fatG * scale,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewLoadingState extends StatelessWidget {
  const _ReviewLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(NovaSpacing.lg),
      children: const [
        _ReviewStateCard(
          icon: Icons.auto_awesome,
          title: 'Loading review',
          message: 'Fetching the latest scan results.',
        ),
      ],
    );
  }
}

String _mealLabel(String value) {
  switch (value) {
    case 'breakfast':
      return 'Breakfast';
    case 'lunch':
      return 'Lunch';
    case 'dinner':
      return 'Dinner';
    case 'snack':
      return 'Snack';
    default:
      return 'Meal';
  }
}

String _statusLabel(String value) {
  switch (value) {
    case 'uploaded':
      return 'Uploaded';
    case 'processing':
      return 'Analyzing';
    case 'needs_review':
      return 'Needs review';
    case 'confirmed':
      return 'Saved';
    case 'failed':
      return 'Failed';
    default:
      return value.replaceAll('_', ' ');
  }
}

String _warningLabel(String value) {
  switch (value) {
    case 'grams missing':
      return 'Set grams';
    case 'low confidence food match':
      return 'Check food match';
    case 'AI estimate needs review':
      return 'Review estimate';
    case 'low confidence portion estimate':
      return 'Check portion';
    case 'removed':
      return 'Removed';
    default:
      return value.replaceAll('_', ' ');
  }
}

String _disabledConfirmMessage(PhotoReview review) {
  if (review.isProcessing) return 'Wait for analysis to finish before saving.';
  if (review.isFailed) return 'Add at least one food manually before saving.';
  if (review.activeItems.isEmpty) return 'Add or restore at least one food.';
  return 'Resolve missing food matches or grams before saving.';
}

String _unitLabel(String unit) {
  return unit[0].toUpperCase() + unit.substring(1).replaceAll('_', ' ');
}
