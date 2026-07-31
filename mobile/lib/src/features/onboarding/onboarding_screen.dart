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
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _dateOfBirth = TextEditingController();
  final _height = TextEditingController(text: '175');
  final _weight = TextEditingController(text: '73');
  final _targetWeight = TextEditingController();
  String _goalType = 'improve_health';
  String _diet = 'non_vegetarian';
  String _activity = 'moderate';
  String _gender = 'prefer_not_to_say';
  bool _acceptedHealthDisclaimer = false;
  bool _saving = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _displayName.dispose();
    _dateOfBirth.dispose();
    _height.dispose();
    _weight.dispose();
    _targetWeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NovaScaffold(
      title: 'Personalise your plan',
      showBottomNavigation: false,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            NovaSpacing.lg,
            NovaSpacing.lg,
            NovaSpacing.lg,
            NovaSpacing.xxl,
          ),
          children: [
            const PageIntro(
              title: 'A plan that fits your day',
              subtitle:
                  'Tell us a little about your routine. You can change these details anytime.',
              icon: Icons.tune_rounded,
            ),
            const SizedBox(height: NovaSpacing.lg),
            const Row(
              children: [
                NovaBadge(
                  label: 'Private by default',
                  icon: Icons.lock_outline,
                  color: NovaColors.mint,
                ),
                SizedBox(width: NovaSpacing.sm),
                NovaBadge(
                  label: 'Step 1 of 1',
                  icon: Icons.checklist_rounded,
                  color: NovaColors.blue,
                ),
              ],
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
                    title:
                        const Text('I understand and accept this disclaimer'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            const SizedBox(height: NovaSpacing.lg),
            TextFormField(
              controller: _displayName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if ((value?.trim().length ?? 0) < 2) {
                  return 'Enter at least 2 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: NovaSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dateOfBirth,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Date of birth (optional)',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    onTap: _pickDateOfBirth,
                  ),
                ),
                const SizedBox(width: NovaSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender (optional)',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'prefer_not_to_say',
                        child: Text('Prefer not to say'),
                      ),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(
                        value: 'non_binary',
                        child: Text('Non-binary'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) =>
                        setState(() => _gender = value ?? _gender),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NovaSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _height,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Height',
                      suffixText: 'cm',
                    ),
                    validator: (value) => _validateMeasurement(
                      value,
                      label: 'height',
                      minimum: 80,
                      maximum: 250,
                    ),
                  ),
                ),
                const SizedBox(width: NovaSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      suffixText: 'kg',
                    ),
                    validator: (value) => _validateMeasurement(
                      value,
                      label: 'weight',
                      minimum: 25,
                      maximum: 350,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NovaSpacing.md),
            TextFormField(
              controller: _targetWeight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Target weight (optional)',
                suffixText: 'kg',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return null;
                return _validateMeasurement(
                  value,
                  label: 'target weight',
                  minimum: 25,
                  maximum: 350,
                );
              },
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
              decoration:
                  const InputDecoration(labelText: 'Dietary preference'),
              items: const [
                DropdownMenuItem(
                    value: 'vegetarian', child: Text('Vegetarian')),
                DropdownMenuItem(value: 'vegan', child: Text('Vegan')),
                DropdownMenuItem(
                    value: 'eggetarian', child: Text('Eggetarian')),
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
                DropdownMenuItem(value: 'sedentary', child: Text('Sedentary')),
                DropdownMenuItem(value: 'light', child: Text('Light')),
                DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'athlete', child: Text('Athlete')),
              ],
              onChanged: (value) =>
                  setState(() => _activity = value ?? _activity),
            ),
            const SizedBox(height: NovaSpacing.xl),
            if (_errorMessage.isNotEmpty) ...[
              ErrorBanner(message: friendlyErrorMessage(_errorMessage)),
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
      ),
    );
  }

  Future<void> _finishSetup() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _errorMessage = '';
    });
    try {
      await ref.read(authControllerProvider.notifier).completeOnboarding({
        'display_name': _displayName.text.trim(),
        if (_dateOfBirth.text.isNotEmpty)
          'date_of_birth': _dateOfBirth.text.trim(),
        'gender_optional': _gender,
        'height_cm': _height.text,
        'weight_kg': _weight.text,
        if (_targetWeight.text.trim().isNotEmpty)
          'target_weight_kg': _targetWeight.text.trim(),
        'goal_type': _goalType,
        'dietary_preference': _diet,
        'activity_level': _activity,
        'has_completed_onboarding': true,
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = friendlyErrorMessage(error);
      });
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 13),
    );
    if (selected == null) return;
    _dateOfBirth.text =
        '${selected.year}-${selected.month.toString().padLeft(2, '0')}-'
        '${selected.day.toString().padLeft(2, '0')}';
  }

  String? _validateMeasurement(
    String? value, {
    required String label,
    required double minimum,
    required double maximum,
  }) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) return 'Enter a valid $label.';
    if (parsed < minimum || parsed > maximum) {
      return 'Check your $label.';
    }
    return null;
  }
}
