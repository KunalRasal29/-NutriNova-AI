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
                  subtitle:
                      'Calories, protein, carbs, fat, water, and goal progress',
                  onTap: () => _showSettingsSheet(
                    context,
                    title: 'Nutrition targets',
                    subtitle: 'Targets are calculated from your profile.',
                    children: const [
                      _InfoRow('Calories', 'Shown on Dashboard and Diary'),
                      _InfoRow('Protein', 'Tracked daily and weekly'),
                      _InfoRow('Carbs and fat', 'Tracked in macro split'),
                      _InfoRow('Water', 'Connected to checklist water habits'),
                    ],
                  ),
                ),
                _SettingsTile(
                  icon: Icons.download_outlined,
                  title: 'Data export',
                  subtitle:
                      'Export meals, habits, body metrics, recipes, and foods',
                  onTap: () => _showSettingsSheet(
                    context,
                    title: 'Data export',
                    subtitle: 'Local MVP status',
                    children: const [
                      Text(
                        'Your data is stored in the local backend database. CSV/PDF export is not wired yet, but the backend already owns meals, habits, foods, body metrics, and recipes per user.',
                      ),
                    ],
                  ),
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy',
                  subtitle:
                      'Private custom foods, user-owned logs, and data controls',
                  onTap: () => _showSettingsSheet(
                    context,
                    title: 'Privacy',
                    subtitle: 'Local development mode',
                    children: const [
                      _InfoRow('Custom foods', 'Private to your user account'),
                      _InfoRow('Meal logs', 'User-owned'),
                      _InfoRow('Photo scans', 'Review before saving'),
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
                  title: 'Health disclaimer',
                  subtitle: 'Wellness tracking only. Not medical diagnosis.',
                  onTap: () => _showSettingsSheet(
                    context,
                    title: 'Health disclaimer',
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
