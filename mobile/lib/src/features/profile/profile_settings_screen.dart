import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../auth/auth_controller.dart';
import '../dashboard/dashboard_controller.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final config = ref.watch(appConfigProvider);
    final dashboard = ref.watch(dashboardProvider).valueOrNull;
    final habits = ref.watch(todayHabitsProvider).valueOrNull ?? const [];

    return NovaScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.lg),
        children: [
          const PageIntro(
            title: 'NutriNova AI',
            subtitle:
                'Food logging, checklist habits, progress, and reviewed AI estimates in one free local app.',
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(user?.displayName ?? 'NutriNova user'),
              subtitle: Text(user?.email ?? 'Signed in'),
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          _QuickActionGrid(
            actions: [
              _QuickAction(
                icon: Icons.checklist,
                label: 'Checklist',
                color: NovaColors.mint,
                onTap: () => context.go('/habits'),
              ),
              _QuickAction(
                icon: Icons.search,
                label: 'Food search',
                color: NovaColors.blue,
                onTap: () => context.go(_withMealType('/foods/search')),
              ),
              _QuickAction(
                icon: Icons.bar_chart,
                label: 'Progress',
                color: NovaColors.violet,
                onTap: () => context.go('/analytics'),
              ),
              _QuickAction(
                icon: Icons.monitor_weight_outlined,
                label: 'Weight',
                color: NovaColors.lime,
                onTap: () => context.go('/weight/log'),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaCard(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: 'Account',
                  subtitle: user?.email ?? 'Signed in',
                  onTap: () => _showSettingsSheet(
                    context,
                    title: 'Account',
                    subtitle: user?.email ?? 'Signed in',
                    children: [
                      _InfoRow('Name', user?.displayName ?? 'NutriNova user'),
                      _InfoRow('Email', user?.email ?? 'Not available'),
                      _InfoRow(
                        'Onboarding',
                        user?.hasCompletedOnboarding == true
                            ? 'Complete'
                            : 'Needs setup',
                      ),
                      const SizedBox(height: NovaSpacing.md),
                      NovaButton.secondary(
                        label: 'Sign out',
                        icon: Icons.logout,
                        onPressed: () {
                          Navigator.of(context).pop();
                          ref.read(authControllerProvider.notifier).logout();
                        },
                      ),
                    ],
                  ),
                ),
                _SettingsTile(
                  icon: Icons.checklist,
                  title: 'Checklist',
                  subtitle: habits.isEmpty
                      ? 'Create and check daily habits'
                      : '${habits.where((habit) => habit.isCompleted).length}/${habits.length} complete today',
                  onTap: () => context.go('/habits'),
                ),
                _SettingsTile(
                  icon: Icons.straighten,
                  title: 'Units',
                  subtitle:
                      'Metric defaults: kilograms, centimeters, grams, ml',
                  onTap: () => _showSettingsSheet(
                    context,
                    title: 'Units',
                    subtitle: 'Current defaults',
                    children: const [
                      _InfoRow('Weight', 'Kilograms'),
                      _InfoRow('Height', 'Centimeters'),
                      _InfoRow('Food portions', 'Grams and servings'),
                      _InfoRow('Water', 'Milliliters / glasses'),
                    ],
                  ),
                ),
                _SettingsTile(
                  icon: Icons.track_changes,
                  title: 'Nutrition targets',
                  subtitle: dashboard == null
                      ? 'Calories, protein, carbs, fat, water, and progress'
                      : '${dashboard.targetCalories.toStringAsFixed(0)} kcal target',
                  onTap: () => _showSettingsSheet(
                    context,
                    title: 'Nutrition targets',
                    subtitle: 'Current daily tracking values',
                    children: [
                      _InfoRow(
                        'Calories',
                        dashboard == null
                            ? 'Open Dashboard after logging food'
                            : '${dashboard.consumedCalories.toStringAsFixed(0)} / ${dashboard.targetCalories.toStringAsFixed(0)} kcal',
                      ),
                      _InfoRow(
                        'Protein',
                        dashboard == null
                            ? 'Tracked from food logs'
                            : '${dashboard.proteinG.toStringAsFixed(0)}g today',
                      ),
                      _InfoRow(
                        'Carbs / Fat',
                        dashboard == null
                            ? 'Tracked in Diary and Progress'
                            : '${dashboard.carbsG.toStringAsFixed(0)}g / ${dashboard.fatG.toStringAsFixed(0)}g today',
                      ),
                      _InfoRow(
                        'Water',
                        dashboard == null
                            ? 'Connected to water checklist habits'
                            : '${dashboard.waterCompleted}/${dashboard.waterTarget} glasses',
                      ),
                      const SizedBox(height: NovaSpacing.md),
                      NovaButton.secondary(
                        label: 'Open dashboard',
                        icon: Icons.dashboard_outlined,
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.go('/home');
                        },
                      ),
                    ],
                  ),
                ),
                _SettingsTile(
                  icon: Icons.restaurant_menu_outlined,
                  title: 'Food database',
                  subtitle: 'Search foods, favorites, recent, and My Foods',
                  onTap: () => context.go(_withMealType('/foods/search')),
                ),
                _SettingsTile(
                  icon: Icons.phone_iphone,
                  title: 'Phone/API setup',
                  subtitle: config.apiBaseUrl,
                  onTap: () => _showSettingsSheet(
                    context,
                    title: 'Phone/API setup',
                    subtitle: 'Local Mac and phone testing',
                    children: [
                      _InfoRow('Current API', config.apiBaseUrl),
                      _InfoRow(
                        'Mock mode',
                        config.mockMode ? 'Enabled' : 'Disabled',
                      ),
                      const _InfoRow('iOS simulator', 'http://127.0.0.1:8000'),
                      const _InfoRow(
                          'Android emulator', 'http://10.0.2.2:8000'),
                      const _InfoRow(
                        'Real phone',
                        'Use your Mac Wi-Fi IP with port 8000',
                      ),
                      const SizedBox(height: NovaSpacing.md),
                      const Text(
                        'Keep Mac and phone on the same Wi-Fi. The backend should be running through Docker and bound to 0.0.0.0.',
                      ),
                    ],
                  ),
                ),
                _SettingsTile(
                  icon: Icons.dataset_outlined,
                  title: 'About data sources',
                  subtitle:
                      'USDA FDC, Open Food Facts, Indian sources, user custom, AI estimates',
                  onTap: () => _showSettingsSheet(
                    context,
                    title: 'Data sources',
                    subtitle: 'What the app uses',
                    children: const [
                      _InfoRow('USDA FDC', 'Official foods and nutrients'),
                      _InfoRow('IFCT / Indian foods', 'Indian common foods'),
                      _InfoRow('Open Food Facts', 'Packaged food samples'),
                      _InfoRow('User custom', 'Foods you create'),
                      _InfoRow('AI estimates', 'Require review before saving'),
                    ],
                  ),
                ),
                _SettingsTile(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Health note',
                  subtitle: 'Wellness tracking only. Not medical diagnosis.',
                  onTap: () => _showSettingsSheet(
                    context,
                    title: 'Health note',
                    subtitle: 'Important',
                    children: const [
                      Text(
                        'NutriNova AI is for wellness tracking only. It is not medical diagnosis, treatment, emergency guidance, or a replacement for a qualified clinician.',
                      ),
                    ],
                  ),
                ),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'App version',
                  subtitle: 'NutriNova AI mobile 0.1.0',
                  onTap: () => _showSettingsSheet(
                    context,
                    title: 'App version',
                    subtitle: 'NutriNova AI mobile 0.1.0',
                    children: [
                      _InfoRow('API base URL', config.apiBaseUrl),
                      _InfoRow(
                        'Mock mode',
                        config.mockMode ? 'Enabled' : 'Disabled',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.secondary(
            label: 'Sign out',
            icon: Icons.logout,
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({required this.actions});

  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: NovaSpacing.md,
      mainAxisSpacing: NovaSpacing.md,
      childAspectRatio: 2.35,
      children: [
        for (final action in actions)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: action.onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: NovaColors.panelRaised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NovaColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(NovaSpacing.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: action.color.withValues(alpha: 0.16),
                      child: Icon(action.icon, color: action.color, size: 19),
                    ),
                    const SizedBox(width: NovaSpacing.md),
                    Expanded(
                      child: Text(
                        action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: NovaColors.graphite,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

void _showSettingsSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<Widget> children,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: NovaColors.panel,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NovaSpacing.lg,
          NovaSpacing.sm,
          NovaSpacing.lg,
          NovaSpacing.lg,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: NovaSpacing.xs),
            Text(subtitle, style: const TextStyle(color: NovaColors.graphite)),
            const SizedBox(height: NovaSpacing.lg),
            ...children,
          ],
        ),
      ),
    ),
  );
}

String _withMealType(String path, {String mealType = 'lunch'}) {
  return Uri(path: path, queryParameters: {'meal_type': mealType}).toString();
}
