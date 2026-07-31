import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class CustomFoodManagementScreen extends ConsumerStatefulWidget {
  const CustomFoodManagementScreen({super.key});

  @override
  ConsumerState<CustomFoodManagementScreen> createState() =>
      _CustomFoodManagementScreenState();
}

class _CustomFoodManagementScreenState
    extends ConsumerState<CustomFoodManagementScreen> {
  final _search = TextEditingController();
  List<FoodDetail> _foods = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _foods.where((food) {
      return query.isEmpty ||
          food.name.toLowerCase().contains(query) ||
          food.brand.toLowerCase().contains(query);
    }).toList();
    return NovaScaffold(
      title: 'My custom foods',
      actions: [
        IconButton(
          tooltip: 'Create custom food',
          onPressed: _create,
          icon: const Icon(Icons.add),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(NovaSpacing.lg),
          children: [
            const PageIntro(
              title: 'Your foods',
              subtitle: 'Review, edit, re-estimate or log foods you created.',
              icon: Icons.inventory_2_outlined,
            ),
            const SizedBox(height: NovaSpacing.lg),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search your custom foods',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _search.clear,
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: NovaSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(NovaSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ManagementEmpty(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load custom foods',
                message: _error!,
                actionLabel: 'Retry',
                onAction: _load,
              )
            else if (visible.isEmpty)
              _ManagementEmpty(
                icon: Icons.restaurant_menu,
                title: query.isEmpty ? 'No custom foods yet' : 'No matches',
                message: query.isEmpty
                    ? 'Create a private food and review its macros before saving.'
                    : 'Try another name or clear the search.',
                actionLabel: query.isEmpty ? 'Create custom food' : 'Clear',
                onAction: query.isEmpty ? _create : _search.clear,
              )
            else ...[
              Text('${visible.length} food${visible.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: NovaColors.graphite,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: NovaSpacing.sm),
              ...visible.map(_foodCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _foodCard(FoodDetail food) {
    final review = food.customFood;
    final nutrients = review?.effectiveNutrients ?? const <String, double>{};
    final status = review?.status ?? 'confirmed';
    final archived = status == 'archived';
    return Padding(
      padding: const EdgeInsets.only(bottom: NovaSpacing.md),
      child: NovaCard(
        color: archived ? NovaColors.panel : NovaColors.panelRaised,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: archived
                        ? null
                        : () => context.push('/foods/${food.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (food.brand.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(food.brand,
                              style:
                                  const TextStyle(color: NovaColors.graphite)),
                        ],
                      ],
                    ),
                  ),
                ),
                NovaBadge(
                  label: _statusLabel(status),
                  color: _statusColor(status),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Custom food actions',
                  onSelected: (value) => _handleAction(value, food),
                  itemBuilder: (_) => [
                    if (!archived)
                      const PopupMenuItem(
                          value: 'log', child: Text('Log again')),
                    if (!archived)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                        value: 'duplicate', child: Text('Duplicate')),
                    if (!archived)
                      const PopupMenuItem(
                          value: 'estimate', child: Text('Re-estimate')),
                    const PopupMenuItem(
                        value: 'history', child: Text('Version history')),
                    if (!archived)
                      const PopupMenuItem(
                          value: 'archive', child: Text('Archive')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: NovaSpacing.md),
            Wrap(
              spacing: NovaSpacing.sm,
              runSpacing: NovaSpacing.sm,
              children: [
                NovaBadge(
                  label: '${_value(nutrients, 'calories_kcal', food)} kcal',
                  color: NovaColors.blue,
                ),
                NovaBadge(
                  label: 'P ${_value(nutrients, 'protein_g', food)}g',
                  color: NovaColors.coral,
                ),
                NovaBadge(
                  label: 'C ${_value(nutrients, 'carbs_g', food)}g',
                  color: NovaColors.gold,
                ),
                NovaBadge(
                  label: 'F ${_value(nutrients, 'fat_g', food)}g',
                  color: NovaColors.violet,
                ),
              ],
            ),
            const SizedBox(height: NovaSpacing.md),
            SourceConfidenceBadges(
              source:
                  food.sourceBadge.isEmpty ? 'USER CUSTOM' : food.sourceBadge,
              confidence: review?.confidence ?? food.confidenceScore,
              verified: false,
              classification: 'user_custom',
            ),
            if (review != null) ...[
              const SizedBox(height: NovaSpacing.sm),
              Text(
                '${review.servingQuantity.toStringAsFixed(0)} ${review.servingUnit} • ${review.servingWeightG.toStringAsFixed(1)}g • version ${review.version}',
                style: const TextStyle(
                  color: NovaColors.graphite,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final foods = await ref.read(nutritionRepositoryProvider).customFoods();
      if (mounted) setState(() => _foods = foods);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    await context.push('/foods/custom?return_to=manage');
    if (mounted) await _load();
  }

  Future<void> _handleAction(String action, FoodDetail food) async {
    switch (action) {
      case 'edit':
        await context.push('/foods/custom/${food.id}/edit');
        if (mounted) await _load();
        return;
      case 'duplicate':
        await context.push('/foods/custom/${food.id}/duplicate');
        if (mounted) await _load();
        return;
      case 'estimate':
        await _reEstimate(food);
        return;
      case 'history':
        await _showHistory(food);
        return;
      case 'archive':
        await _archive(food);
        return;
      case 'log':
        await _log(food);
        return;
    }
  }

  Future<void> _reEstimate(FoodDetail food) async {
    try {
      await ref
          .read(nutritionRepositoryProvider)
          .reEstimateCustomFood(food.id, {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'New suggestion ready for ${food.name}. Review it before confirming.')),
      );
      await context.push('/foods/custom/${food.id}/edit');
      if (mounted) await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _showHistory(FoodDetail food) async {
    try {
      final history = await ref
          .read(nutritionRepositoryProvider)
          .customFoodHistory(food.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(NovaSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${food.name} history',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: NovaSpacing.md),
                if (history.isEmpty)
                  const Text('No previous versions yet.')
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, index) {
                        final item = history[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history),
                          title: Text(
                              'Version ${item['version_number'] ?? item['version'] ?? index + 1}'),
                          subtitle: Text(
                              '${item['change_type'] ?? item['status'] ?? 'Saved change'} • ${item['created_at'] ?? ''}'),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _archive(FoodDetail food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive custom food?'),
        content: Text(
            '${food.name} will leave normal search, but historical meals stay unchanged.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Archive')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(nutritionRepositoryProvider).archiveCustomFood(food.id);
      if (mounted) await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _log(FoodDetail food) async {
    try {
      await ref.read(nutritionRepositoryProvider).logCustomFood(
            food.id,
            mealType: 'snack',
          );
      ref.invalidate(dashboardProvider);
      ref.invalidate(todayMealLogsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged ${food.name} to snack')),
      );
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(friendlyErrorMessage(error))),
    );
  }

  String _value(Map<String, double> values, String key, FoodDetail food) {
    final servingValue = values[key];
    final preview = food.previewFor(quantity: 1, unit: 'serving');
    final fallback = switch (key) {
      'calories_kcal' => preview.caloriesKcal,
      'protein_g' => preview.proteinG,
      'carbs_g' => preview.carbsG,
      'fat_g' => preview.fatG,
      _ => 0.0,
    };
    final value = servingValue ?? fallback;
    return value.toStringAsFixed(key == 'calories_kcal' ? 0 : 1);
  }
}

class _ManagementEmpty extends StatelessWidget {
  const _ManagementEmpty({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => NovaCard(
        child: Column(children: [
          Icon(icon, size: 42, color: NovaColors.mint),
          const SizedBox(height: NovaSpacing.md),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: NovaSpacing.sm),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: NovaColors.graphite)),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.secondary(
              label: actionLabel,
              icon: Icons.arrow_forward,
              onPressed: onAction),
        ]),
      );
}

String _statusLabel(String status) {
  switch (status) {
    case 'estimate_ready':
      return 'Estimate ready';
    case 'needs_review':
      return 'Needs review';
    case 'confirmed':
      return 'Confirmed by you';
    case 'archived':
      return 'Archived';
    default:
      return 'Draft';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'confirmed':
      return NovaColors.mint;
    case 'estimate_ready':
    case 'needs_review':
      return NovaColors.gold;
    case 'archived':
      return NovaColors.graphite;
    default:
      return NovaColors.blue;
  }
}
