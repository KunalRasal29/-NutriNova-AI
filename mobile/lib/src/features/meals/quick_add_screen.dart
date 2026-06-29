import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class QuickAddScreen extends ConsumerStatefulWidget {
  const QuickAddScreen({super.key});

  @override
  ConsumerState<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends ConsumerState<QuickAddScreen> {
  final _text = TextEditingController(text: '2 eggs');
  String _mealType = 'breakfast';
  Map<String, dynamic>? _result;
  bool _loading = false;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final parsedItems = result == null
        ? const <dynamic>[]
        : (result['parsed_items'] as List<dynamic>? ?? const <dynamic>[]);
    final preview = result == null
        ? const <String, dynamic>{}
        : result['preview'] as Map<String, dynamic>? ?? const {};

    return NovaScaffold(
      title: 'Quick add',
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.lg),
        children: [
          TextField(
            controller: _text,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Describe food',
              hintText: '2 eggs, 1 banana, 200g rice, 2 chapati',
              prefixIcon: Icon(Icons.flash_on_outlined),
            ),
          ),
          const SizedBox(height: NovaSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _mealType,
            decoration: const InputDecoration(labelText: 'Meal'),
            items: const [
              DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
              DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
              DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
              DropdownMenuItem(value: 'snack', child: Text('Snack')),
            ],
            onChanged: (value) =>
                setState(() => _mealType = value ?? _mealType),
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: _loading ? 'Parsing...' : 'Parse food',
            icon: Icons.auto_awesome,
            onPressed: _loading
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _loading = true);
                    try {
                      final result = await ref
                          .read(nutritionRepositoryProvider)
                          .quickAdd(_text.text, _mealType);
                      if (mounted) {
                        setState(() {
                          _result = result;
                          _loading = false;
                        });
                      }
                    } catch (error) {
                      if (mounted) {
                        setState(() => _loading = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
          ),
          if (_result != null) ...[
            const SizedBox(height: NovaSpacing.lg),
            NovaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      NovaBadge(
                        label: _result!['requires_review'] == true
                            ? 'Review needed'
                            : 'Ready',
                        icon: _result!['requires_review'] == true
                            ? Icons.warning_amber
                            : Icons.check,
                        color: _result!['requires_review'] == true
                            ? NovaColors.gold
                            : NovaColors.mint,
                      ),
                      const Spacer(),
                      Text('Confidence ${_result!['confidence']}'),
                    ],
                  ),
                  const SizedBox(height: NovaSpacing.lg),
                  Text(
                    '${preview['calories_kcal'] ?? 0} kcal',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: NovaSpacing.sm),
                  Text(
                    'Protein ${preview['protein_g'] ?? 0}g • Carbs ${preview['carbs_g'] ?? 0}g • Fat ${preview['fat_g'] ?? 0}g',
                  ),
                  const Divider(height: 28),
                  for (final item in parsedItems)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.restaurant),
                      title: Text(item['food_name']?.toString() ?? 'Food'),
                      subtitle: Text(
                        '${item['quantity_value']} ${item['quantity_unit']} • ${item['effective_total_grams']}g',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: NovaSpacing.lg),
            NovaButton.primary(
              label: _saving ? 'Saving...' : 'Confirm and save',
              icon: Icons.check,
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await ref
                            .read(nutritionRepositoryProvider)
                            .confirmQuickAdd({
                          'text': _text.text,
                          'meal_type': _mealType,
                          'items': parsedItems,
                        });
                        ref.invalidate(dashboardProvider);
                        ref.invalidate(todayMealLogsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Quick add saved')),
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
        ],
      ),
    );
  }
}
