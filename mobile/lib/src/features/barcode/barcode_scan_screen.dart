import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class BarcodeScanScreen extends ConsumerStatefulWidget {
  const BarcodeScanScreen({super.key, this.initialMealType = 'snack'});

  final String initialMealType;

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  final _manualBarcode = TextEditingController();
  final _grams = TextEditingController(text: '100');
  String? _barcode;
  List<FoodSummary> _results = [];
  bool _loading = false;
  late String _mealType;
  String? _savingFoodId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType;
  }

  @override
  void dispose() {
    _manualBarcode.dispose();
    _grams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grams = double.tryParse(_grams.text.trim()) ?? 100;
    return NovaScaffold(
      title: 'Barcode scan',
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.lg),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 280,
              child: MobileScanner(
                onDetect: (capture) {
                  final code = capture.barcodes.isEmpty
                      ? null
                      : capture.barcodes.first.rawValue;
                  if (code != null && code != _barcode && !_loading) {
                    _lookup(code);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualBarcode,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Enter barcode',
                    prefixIcon: Icon(Icons.qr_code_2_outlined),
                  ),
                  onSubmitted: _lookup,
                ),
              ),
              const SizedBox(width: NovaSpacing.md),
              IconButton.filled(
                tooltip: 'Lookup barcode',
                onPressed:
                    _loading ? null : () => _lookup(_manualBarcode.text.trim()),
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.sm),
          Wrap(
            spacing: NovaSpacing.sm,
            runSpacing: NovaSpacing.sm,
            children: [
              for (final sample in const [
                '8900000000011',
                '8900000000028',
                '8900000000042',
              ])
                ActionChip(
                  label: Text(sample),
                  onPressed: _loading
                      ? null
                      : () {
                          _manualBarcode.text = sample;
                          _lookup(sample);
                        },
                ),
            ],
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaCard(
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner),
                const SizedBox(width: NovaSpacing.md),
                Expanded(
                  child: Text(
                    _barcode ?? 'Point camera at a packaged food barcode',
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          if (_error != null)
            ErrorPanel(message: _error!, onRetry: () => _lookup(_barcode ?? ''))
          else if (_barcode != null && !_loading && _results.isEmpty)
            NovaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'No product found'),
                  const SizedBox(height: NovaSpacing.sm),
                  const Text(
                    'This barcode was not found. If live Open Food Facts lookup is enabled, it was checked automatically. You can create a custom food instead.',
                  ),
                  const SizedBox(height: NovaSpacing.md),
                  NovaButton.primary(
                    label: 'Create custom food',
                    icon: Icons.add,
                    onPressed: _createFromBarcode,
                  ),
                ],
              ),
            )
          else if (_results.isNotEmpty) ...[
            NovaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Log amount'),
                  const SizedBox(height: NovaSpacing.md),
                  MealTypeSelector(
                    value: _mealType,
                    onChanged: (value) => setState(() => _mealType = value),
                  ),
                  const SizedBox(height: NovaSpacing.md),
                  TextField(
                    controller: _grams,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total grams',
                      prefixIcon: Icon(Icons.scale_outlined),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NovaSpacing.lg),
            for (final food in _results) ...[
              _BarcodeFoodCard(
                food: food,
                grams: grams,
                saving: _savingFoodId == food.id,
                onOpen: () => context.push(
                  _withMealType('/foods/${food.id}', _mealType),
                ),
                onLog: grams <= 0
                    ? null
                    : () => _logFood(food: food, grams: grams),
              ),
              const SizedBox(height: NovaSpacing.md),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _createFromBarcode() async {
    final food = await context.push<FoodDetail>(
      Uri(
        path: '/foods/custom',
        queryParameters: {
          'barcode': _barcode ?? '',
          'meal_type': _mealType,
          'return_to': 'barcode',
        },
      ).toString(),
    );
    if (!mounted || food == null) return;
    await context.push(
      Uri(
        path: '/foods/${food.id}',
        queryParameters: {'meal_type': _mealType},
      ).toString(),
    );
  }

  Future<void> _lookup(String barcode) async {
    if (barcode.isEmpty) return;
    setState(() {
      _barcode = barcode;
      _manualBarcode.text = barcode;
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final results =
          await ref.read(nutritionRepositoryProvider).lookupBarcode(barcode);
      if (!mounted) return;
      setState(() {
        _results = results;
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

  Future<void> _logFood({
    required FoodSummary food,
    required double grams,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingFoodId = food.id);
    try {
      await ref.read(nutritionRepositoryProvider).addManualFood(
            foodId: food.id,
            quantity: grams,
            unit: 'gram',
            mealType: _mealType,
            totalGrams: grams,
          );
      ref.invalidate(dashboardProvider);
      ref.invalidate(todayMealLogsProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${food.name} logged')),
      );
      context.go('/meals');
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingFoodId = null);
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }
}

String _withMealType(String path, String mealType) {
  return Uri(path: path, queryParameters: {'meal_type': mealType}).toString();
}

class _BarcodeFoodCard extends StatelessWidget {
  const _BarcodeFoodCard({
    required this.food,
    required this.grams,
    required this.saving,
    required this.onOpen,
    required this.onLog,
  });

  final FoodSummary food;
  final double grams;
  final bool saving;
  final VoidCallback onOpen;
  final VoidCallback? onLog;

  @override
  Widget build(BuildContext context) {
    final scale = grams <= 0 ? 1.0 : grams / 100;
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.inventory_2_outlined),
              const SizedBox(width: NovaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (food.brand.isNotEmpty) ...[
                      const SizedBox(height: NovaSpacing.xs),
                      Text(
                        food.brand,
                        style: const TextStyle(color: NovaColors.graphite),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.md),
          SourceConfidenceBadges(
            source: food.sourceBadge,
            confidence: food.confidenceScore,
            verified: food.verified,
            classification: food.dataClassification,
          ),
          if (food.preparationState != 'unspecified') ...[
            const SizedBox(height: NovaSpacing.sm),
            NovaBadge(
              label: food.preparationState == 'as_sold'
                  ? 'As sold / packaged'
                  : food.preparationState,
              icon: Icons.soup_kitchen_outlined,
              color: NovaColors.blue,
            ),
          ],
          if (food.allergens.isNotEmpty) ...[
            const SizedBox(height: NovaSpacing.sm),
            Text(
              'Allergens: ${food.allergens.join(', ')}',
              style: const TextStyle(
                color: NovaColors.coral,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (food.confidenceScore < 0.7) ...[
            const SizedBox(height: NovaSpacing.sm),
            const Text(
              'Product data may be incomplete. Review the label and serving before logging.',
              style: TextStyle(color: NovaColors.gold),
            ),
          ],
          const SizedBox(height: NovaSpacing.md),
          NutritionPreviewBar(
            caloriesKcal: food.preview.caloriesKcal * scale,
            proteinG: food.preview.proteinG * scale,
            carbsG: food.preview.carbsG * scale,
            fatG: food.preview.fatG * scale,
            compact: true,
          ),
          const SizedBox(height: NovaSpacing.md),
          Row(
            children: [
              Expanded(
                child: NovaButton.secondary(
                  label: 'Open food',
                  icon: Icons.open_in_new,
                  onPressed: onOpen,
                ),
              ),
              const SizedBox(width: NovaSpacing.md),
              Expanded(
                child: NovaButton.primary(
                  label: saving ? 'Saving...' : 'Log',
                  icon: Icons.check,
                  onPressed: saving ? null : onLog,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
