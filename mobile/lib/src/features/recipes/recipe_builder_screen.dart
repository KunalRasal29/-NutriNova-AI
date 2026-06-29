import 'package:flutter/material.dart';

import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';

class RecipeBuilderScreen extends StatefulWidget {
  const RecipeBuilderScreen({super.key});

  @override
  State<RecipeBuilderScreen> createState() => _RecipeBuilderScreenState();
}

class _RecipeBuilderScreenState extends State<RecipeBuilderScreen> {
  final _name = TextEditingController(text: 'Paneer power bowl');
  final _servings = TextEditingController(text: '2');
  final _instructions = TextEditingController();
  final _ingredients = <String>['Paneer 200g', 'Cooked rice 150g'];

  @override
  void dispose() {
    _name.dispose();
    _servings.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NovaScaffold(
      title: 'Recipe builder',
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.lg),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Recipe name'),
          ),
          const SizedBox(height: NovaSpacing.md),
          TextField(
            controller: _servings,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Servings'),
          ),
          const SizedBox(height: NovaSpacing.lg),
          const SectionHeader(title: 'Ingredients'),
          const SizedBox(height: NovaSpacing.sm),
          for (final ingredient in _ingredients)
            NovaCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.drag_indicator),
                title: Text(ingredient),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      setState(() => _ingredients.remove(ingredient)),
                ),
              ),
            ),
          const SizedBox(height: NovaSpacing.md),
          NovaButton.secondary(
            label: 'Add ingredient',
            icon: Icons.add,
            onPressed: () =>
                setState(() => _ingredients.add('New ingredient 100g')),
          ),
          const SizedBox(height: NovaSpacing.lg),
          TextField(
            controller: _instructions,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Instructions'),
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Per serving preview'),
                const SizedBox(height: NovaSpacing.md),
                Wrap(
                  spacing: NovaSpacing.sm,
                  runSpacing: NovaSpacing.sm,
                  children: const [
                    NovaBadge(
                        label: '420 kcal', icon: Icons.local_fire_department),
                    NovaBadge(
                      label: '31g protein',
                      icon: Icons.fitness_center,
                      color: NovaColors.coral,
                    ),
                    NovaBadge(
                      label: '42g carbs',
                      icon: Icons.grain,
                      color: NovaColors.gold,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: 'Save recipe',
            icon: Icons.save_outlined,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
