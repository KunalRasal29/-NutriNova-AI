import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';

class NutritionLabelScanScreen extends ConsumerStatefulWidget {
  const NutritionLabelScanScreen({super.key});

  @override
  ConsumerState<NutritionLabelScanScreen> createState() =>
      _NutritionLabelScanScreenState();
}

class _NutritionLabelScanScreenState
    extends ConsumerState<NutritionLabelScanScreen> {
  XFile? _image;
  NutritionLabelReview? _review;
  bool _busy = false;
  String _error = '';
  final _product = TextEditingController();
  final _brand = TextEditingController();
  final _serving = TextEditingController();
  final _barcode = TextEditingController();
  final _ingredients = TextEditingController();
  final _allergens = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _sugar = TextEditingController();
  final _sodium = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      _product,
      _brand,
      _serving,
      _barcode,
      _ingredients,
      _allergens,
      _calories,
      _protein,
      _carbs,
      _fat,
      _fiber,
      _sugar,
      _sodium,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NovaScaffold(
      title: 'Nutrition label',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          NovaSpacing.lg,
          NovaSpacing.lg,
          NovaSpacing.lg,
          120,
        ),
        children: [
          const PageIntro(
            title: 'Scan, review, then save',
            subtitle:
                'Nothing is added to your foods until you check every field.',
            icon: Icons.document_scanner_outlined,
          ),
          const SizedBox(height: NovaSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final preview = _LabelImageCard(image: _image);
              final form = _review == null ? _pickerActions() : _reviewForm();
              if (constraints.maxWidth >= 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: preview),
                    const SizedBox(width: NovaSpacing.lg),
                    Expanded(child: form),
                  ],
                );
              }
              return Column(
                children: [
                  preview,
                  const SizedBox(height: NovaSpacing.lg),
                  form,
                ],
              );
            },
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: NovaSpacing.lg),
            ErrorBanner(message: _error),
          ],
          const SizedBox(height: NovaSpacing.lg),
          const NovaCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, color: NovaColors.mint),
                SizedBox(width: NovaSpacing.md),
                Expanded(
                  child: Text(
                    'A confirmed scan becomes your private custom food. Label OCR can be wrong, so compare the image with every value.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerActions() {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Choose a clear label photo'),
          const SizedBox(height: NovaSpacing.md),
          Row(
            children: [
              Expanded(
                child: NovaButton.primary(
                  label: 'Camera',
                  icon: Icons.photo_camera_outlined,
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                ),
              ),
              const SizedBox(width: NovaSpacing.md),
              Expanded(
                child: NovaButton.secondary(
                  label: 'Gallery',
                  icon: Icons.photo_library_outlined,
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: _busy ? 'Reading label...' : 'Read label',
            icon: Icons.document_scanner_outlined,
            onPressed: _image == null || _busy ? null : _analyze,
          ),
        ],
      ),
    );
  }

  Widget _reviewForm() {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Review parsed fields',
            action: NovaBadge(
              label: '${((_review?.confidence ?? 0) * 100).round()}%',
              color: NovaColors.gold,
            ),
          ),
          const SizedBox(height: NovaSpacing.md),
          _field(_product, 'Product name'),
          _field(_brand, 'Brand (optional)'),
          _field(_serving, 'Serving size, e.g. 1 bar (50 g)'),
          _field(_barcode, 'Barcode (optional)'),
          const SizedBox(height: NovaSpacing.md),
          const Text(
            'Nutrients per label serving',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: NovaSpacing.sm),
          Row(
            children: [
              Expanded(child: _numberField(_calories, 'Calories')),
              const SizedBox(width: NovaSpacing.sm),
              Expanded(child: _numberField(_protein, 'Protein g')),
            ],
          ),
          Row(
            children: [
              Expanded(child: _numberField(_carbs, 'Carbs g')),
              const SizedBox(width: NovaSpacing.sm),
              Expanded(child: _numberField(_fat, 'Fat g')),
            ],
          ),
          Row(
            children: [
              Expanded(child: _numberField(_fiber, 'Fiber g')),
              const SizedBox(width: NovaSpacing.sm),
              Expanded(child: _numberField(_sugar, 'Sugar g')),
            ],
          ),
          _numberField(_sodium, 'Sodium mg'),
          _field(_ingredients, 'Ingredients', maxLines: 3),
          _field(_allergens, 'Allergens, comma separated'),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: _busy ? 'Saving...' : 'Confirm private food',
            icon: Icons.check_circle_outline,
            onPressed: _busy ? null : _confirm,
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NovaSpacing.sm),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NovaSpacing.sm),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image != null && mounted) {
        setState(() {
          _image = image;
          _review = null;
          _error = '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Allow camera/photos access or use Gallery.');
      }
    }
  }

  Future<void> _analyze() async {
    final image = _image;
    if (image == null) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final review = await ref
          .read(nutritionRepositoryProvider)
          .uploadNutritionLabel(
            fileName: image.name.isEmpty ? 'nutrition-label.jpg' : image.name,
            bytes: await image.readAsBytes(),
          );
      _fill(review);
      if (mounted) setState(() => _review = review);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fill(NutritionLabelReview review) {
    _product.text = review.productName;
    _brand.text = review.brand;
    _serving.text = review.servingSize;
    _barcode.text = review.barcode;
    _ingredients.text = review.ingredients;
    _allergens.text = review.allergens.join(', ');
    _calories.text = _nutrient(review, 'calories');
    _protein.text = _nutrient(review, 'protein_g');
    _carbs.text = _nutrient(review, 'carbs_g');
    _fat.text = _nutrient(review, 'fat_g');
    _fiber.text = _nutrient(review, 'fiber_g');
    _sugar.text = _nutrient(review, 'sugar_g');
    _sodium.text = _nutrient(review, 'sodium_mg');
  }

  String _nutrient(NutritionLabelReview review, String code) {
    return review.nutrients[code]?.toString() ?? '';
  }

  Future<void> _confirm() async {
    final review = _review;
    if (review == null || _product.text.trim().isEmpty) {
      setState(() => _error = 'Enter a product name before saving.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      Map<String, dynamic> nutrients() => {
            for (final entry in {
              'calories': _calories,
              'protein_g': _protein,
              'carbs_g': _carbs,
              'fat_g': _fat,
              'fiber_g': _fiber,
              'sugar_g': _sugar,
              'sodium_mg': _sodium,
            }.entries)
              if (double.tryParse(entry.value.text) != null)
                entry.key: double.parse(entry.value.text),
          };
      final food =
          await ref.read(nutritionRepositoryProvider).confirmNutritionLabel(
        review.analysisId,
        {
          'product_name': _product.text.trim(),
          'brand': _brand.text.trim(),
          'serving_size': _serving.text.trim(),
          'barcode': _barcode.text.trim(),
          'parsed_nutrients': nutrients(),
          'ingredients_text': _ingredients.text.trim(),
          'allergens': _allergens.text
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
        },
      );
      if (mounted) context.go('/foods/${food.id}?meal_type=snack');
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _LabelImageCard extends StatelessWidget {
  const _LabelImageCard({required this.image});

  final XFile? image;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: image == null
            ? const Center(
                child: Icon(Icons.receipt_long_outlined, size: 54),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FutureBuilder<Uint8List>(
                  future: image!.readAsBytes(),
                  builder: (context, snapshot) => snapshot.data == null
                      ? const Center(child: CircularProgressIndicator())
                      : Image.memory(snapshot.data!, fit: BoxFit.contain),
                ),
              ),
      ),
    );
  }
}
