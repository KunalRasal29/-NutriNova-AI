import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../auth/auth_controller.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final config = ref.watch(appConfigProvider);

    return NovaScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.lg),
        children: [
          const PageIntro(
            title: 'NutriNova AI',
            subtitle:
                'Privacy-first wellness tracking with verified sources, user custom foods, and reviewed AI estimates.',
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
          NovaCard(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: 'Account',
                  subtitle: 'Email, profile, login, and secure token session',
                ),
                _SettingsTile(
                  icon: Icons.straighten,
                  title: 'Units',
                  subtitle:
                      'Metric defaults: kilograms, centimeters, grams, ml',
                ),
                _SettingsTile(
                  icon: Icons.track_changes,
                  title: 'Nutrition targets',
                  subtitle:
                      'Calories, protein, carbs, fat, water, and goal progress',
                ),
                _SettingsTile(
                  icon: Icons.download_outlined,
                  title: 'Data export',
                  subtitle:
                      'Export meals, habits, body metrics, recipes, and foods',
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy',
                  subtitle:
                      'Private custom foods, user-owned logs, and data controls',
                ),
                _SettingsTile(
                  icon: Icons.dataset_outlined,
                  title: 'About data sources',
                  subtitle:
                      'USDA FDC, Open Food Facts, Indian sources, user custom, AI estimates',
                ),
                const _SettingsTile(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Health disclaimer',
                  subtitle: 'Wellness tracking only. Not medical diagnosis.',
                ),
                const _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'App version',
                  subtitle: 'NutriNova AI mobile 0.1.0',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: config.mockMode,
                  onChanged: null,
                  title: const Text('Mock mode'),
                  subtitle: Text(config.mockMode ? 'Enabled' : 'Disabled'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link),
                  title: const Text('API base URL'),
                  subtitle: Text(config.apiBaseUrl),
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
