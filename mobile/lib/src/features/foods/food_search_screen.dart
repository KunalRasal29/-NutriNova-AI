import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _query = TextEditingController(text: 'egg');

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(foodSearchProvider(_query.text));
    return NovaScaffold(
      title: 'Food search',
      actions: [
        IconButton(
          tooltip: 'Create custom food',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => context.go('/foods/custom'),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(NovaSpacing.lg),
            child: TextField(
              controller: _query,
              decoration: const InputDecoration(
                labelText: 'Search foods',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: foods.when(
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(NovaSpacing.lg),
                    child: NovaCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const EmptyState(
                            title: 'No foods found',
                            message:
                                'Try another name or create a private custom food.',
                            icon: Icons.search_off,
                          ),
                          NovaButton.primary(
                            label: 'Create custom',
                            icon: Icons.add,
                            onPressed: () => context.go('/foods/custom'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(NovaSpacing.lg),
                  itemBuilder: (_, index) {
                    final food = items[index];
                    return NovaCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => context.go('/foods/${food.id}'),
                        title: Text(food.name),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: NovaSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (food.brand.isNotEmpty) Text(food.brand),
                              SourceConfidenceBadges(
                                source: food.sourceBadge,
                                confidence: food.confidenceScore,
                                verified: food.verified,
                                classification: food.dataClassification,
                              ),
                            ],
                          ),
                        ),
                        trailing: Text(
                          '${food.preview.caloriesKcal.toStringAsFixed(0)} kcal',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: NovaSpacing.md),
                  itemCount: items.length,
                );
              },
              error: (error, _) => ErrorPanel(
                message: error.toString(),
                onRetry: () => ref.invalidate(foodSearchProvider(_query.text)),
              ),
              loading: () => const LoadingList(),
            ),
          ),
        ],
      ),
    );
  }
}
