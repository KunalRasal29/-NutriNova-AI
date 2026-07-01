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
      body: ListView(
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
                const SizedBox(height: NovaSpacing.md),
                TextField(
                  controller: _weight,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Weight kg',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                  ),
                ),
                const SizedBox(height: NovaSpacing.lg),
                NovaButton.primary(
                  label: _saving ? 'Saving...' : 'Save weight',
                  icon: Icons.check,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final value = double.tryParse(_weight.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    if (value == null || value <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid weight in kg.')),
      );
      return;
    }
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
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
