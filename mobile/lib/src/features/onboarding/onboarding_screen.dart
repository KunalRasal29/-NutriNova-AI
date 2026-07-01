import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../auth/auth_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _displayName = TextEditingController();
  final _height = TextEditingController(text: '175');
  final _weight = TextEditingController(text: '73');
  String _goalType = 'improve_health';
  String _diet = 'non_vegetarian';
  String _activity = 'moderate';
  bool _acceptedHealthDisclaimer = false;
  bool _saving = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _displayName.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NovaScaffold(
      title: 'Profile setup',
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.lg),
        children: [
          const NovaBadge(
            label: 'Private by default',
            icon: Icons.lock_outline,
            color: NovaColors.mint,
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Health disclaimer'),
                const SizedBox(height: NovaSpacing.sm),
                const Text(
                  'NutriNova AI is for wellness tracking only. It is not medical diagnosis, treatment, or emergency guidance. Confirm AI and food database estimates before relying on them.',
                ),
                const SizedBox(height: NovaSpacing.md),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _acceptedHealthDisclaimer,
                  onChanged: (value) => setState(
                    () => _acceptedHealthDisclaimer = value ?? false,
                  ),
                  title: const Text('I understand and accept this disclaimer'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          TextField(
            controller: _displayName,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          const SizedBox(height: NovaSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height cm'),
                ),
              ),
              const SizedBox(width: NovaSpacing.md),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight kg'),
                ),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _goalType,
            decoration: const InputDecoration(labelText: 'Goal'),
            items: const [
              DropdownMenuItem(
                value: 'lose_weight',
                child: Text('Lose weight'),
              ),
              DropdownMenuItem(value: 'maintain', child: Text('Maintain')),
              DropdownMenuItem(
                value: 'gain_muscle',
                child: Text('Gain muscle'),
              ),
              DropdownMenuItem(
                value: 'improve_health',
                child: Text('Improve health'),
              ),
            ],
            onChanged: (value) =>
                setState(() => _goalType = value ?? _goalType),
          ),
          const SizedBox(height: NovaSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _diet,
            decoration: const InputDecoration(labelText: 'Dietary preference'),
            items: const [
              DropdownMenuItem(value: 'vegetarian', child: Text('Vegetarian')),
              DropdownMenuItem(value: 'vegan', child: Text('Vegan')),
              DropdownMenuItem(value: 'eggetarian', child: Text('Eggetarian')),
              DropdownMenuItem(
                value: 'non_vegetarian',
                child: Text('Non vegetarian'),
              ),
              DropdownMenuItem(value: 'jain', child: Text('Jain')),
              DropdownMenuItem(value: 'keto', child: Text('Keto')),
              DropdownMenuItem(
                  value: 'high_protein', child: Text('High protein')),
              DropdownMenuItem(value: 'custom', child: Text('Custom')),
            ],
            onChanged: (value) => setState(() => _diet = value ?? _diet),
          ),
          const SizedBox(height: NovaSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _activity,
            decoration: const InputDecoration(labelText: 'Activity level'),
            items: const [
              DropdownMenuItem(value: 'light', child: Text('Light')),
              DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
            ],
            onChanged: (value) =>
                setState(() => _activity = value ?? _activity),
          ),
          const SizedBox(height: NovaSpacing.xl),
          if (_errorMessage.isNotEmpty) ...[
            ErrorBanner(message: _errorMessage),
            const SizedBox(height: NovaSpacing.md),
          ],
          NovaButton.primary(
            label: _saving ? 'Saving...' : 'Finish setup',
            icon: Icons.check,
            onPressed:
                _acceptedHealthDisclaimer && !_saving ? _finishSetup : null,
          ),
        ],
      ),
    );
  }

  Future<void> _finishSetup() async {
    setState(() {
      _saving = true;
      _errorMessage = '';
    });
    try {
      await ref.read(authControllerProvider.notifier).completeOnboarding({
        'display_name': _displayName.text.trim(),
        'height_cm': _height.text,
        'weight_kg': _weight.text,
        'goal_type': _goalType,
        'dietary_preference': _diet,
        'activity_level': _activity,
        'has_completed_onboarding': true,
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = error.toString();
      });
    }
  }
}
