import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class LogWeightScreen extends ConsumerStatefulWidget {
  const LogWeightScreen({super.key});

  @override
  ConsumerState<LogWeightScreen> createState() => _LogWeightScreenState();
}

class _LogWeightScreenState extends ConsumerState<LogWeightScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weight = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NovaScaffold(
      title: 'Log weight',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(NovaSpacing.lg),
          children: [
            const PageIntro(
              title: 'Weight check-in',
              subtitle: 'Log today’s body weight to build your progress trend.',
              icon: Icons.monitor_weight_outlined,
            ),
            const SizedBox(height: NovaSpacing.lg),
            NovaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Today'),
                  const SizedBox(height: NovaSpacing.sm),
                  const Text(
                    'Use the same scale and a similar time of day for a more useful trend.',
                    style: TextStyle(color: NovaColors.graphite, height: 1.4),
                  ),
                  const SizedBox(height: NovaSpacing.lg),
                  TextFormField(
                    controller: _weight,
                    autofocus: true,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      labelText: 'Current weight',
                      suffixText: 'kg',
                      prefixIcon: Icon(Icons.monitor_weight_outlined),
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(value?.trim() ?? '');
                      if (parsed == null) {
                        return 'Enter your weight in kilograms.';
                      }
                      if (parsed < 25 || parsed > 350) {
                        return 'Enter a weight between 25 and 350 kg.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: NovaSpacing.lg),
                  NovaButton.primary(
                    label: _saving ? 'Saving…' : 'Save weight',
                    icon: _saving ? Icons.hourglass_top : Icons.check,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = double.tryParse(_weight.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    if (value == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(nutritionRepositoryProvider).logBodyMetric(
            weightKg: value,
          );
      ref.invalidate(dashboardProvider);
      ref.invalidate(progressReportProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${value.toStringAsFixed(1)} kg saved')),
      );
      context.go('/analytics');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }
}
