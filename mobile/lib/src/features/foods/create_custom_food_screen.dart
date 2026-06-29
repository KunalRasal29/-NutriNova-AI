import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';

class CreateCustomFoodScreen extends ConsumerStatefulWidget {
  const CreateCustomFoodScreen({super.key});

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
  final _notes = TextEditingController();
  bool _saving = false;

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
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NovaScaffold(
      title: 'Custom food',
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.lg),
        children: [
          const NovaBadge(
            label: 'Private USER_CUSTOM food',
            icon: Icons.lock_outline,
            color: NovaColors.mint,
          ),
          const SizedBox(height: NovaSpacing.md),
          const SourceConfidenceBadges(
            source: 'USER_CUSTOM',
            confidence: 0.5,
            verified: false,
            classification: 'user_custom',
          ),
          const SizedBox(height: NovaSpacing.lg),
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
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: _saving ? 'Saving...' : 'Save custom food',
            icon: Icons.save_outlined,
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await ref
                          .read(nutritionRepositoryProvider)
                          .createCustomFood(_payload());
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Custom food saved')),
                      );
                      context.go('/foods/search');
                    } catch (error) {
                      if (!context.mounted) return;
                      setState(() => _saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
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
    putIfPresent('notes', _notes);
    return payload;
  }
}
