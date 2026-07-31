import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import 'auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return NovaAuthScaffold(
      title: 'Build your daily rhythm',
      subtitle:
          'Create a private profile for meals, habits, weight, and progress.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Already have an account?',
            style: TextStyle(color: NovaColors.graphite),
          ),
          TextButton(
            onPressed: auth.isLoading ? null : () => context.go('/login'),
            child: const Text('Sign in'),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create account',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: NovaSpacing.xs),
              const Text(
                'It only takes a minute. You can adjust your goals later.',
                style: TextStyle(color: NovaColors.graphite),
              ),
              const SizedBox(height: NovaSpacing.xl),
              TextFormField(
                controller: _name,
                enabled: !auth.isLoading,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'What should we call you?',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  if ((value?.trim().length ?? 0) < 2) {
                    return 'Enter at least 2 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: NovaSpacing.md),
              TextFormField(
                controller: _email,
                enabled: !auth.isLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: NovaSpacing.md),
              TextFormField(
                controller: _password,
                enabled: !auth.isLoading,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'Use at least 8 characters.',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip:
                        _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if ((value?.length ?? 0) < 8) {
                    return 'Use at least 8 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: NovaSpacing.md),
              TextFormField(
                controller: _confirmPassword,
                enabled: !auth.isLoading,
                obscureText: _obscureConfirmation,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  suffixIcon: IconButton(
                    tooltip: _obscureConfirmation
                        ? 'Show confirmation'
                        : 'Hide confirmation',
                    onPressed: () => setState(
                      () => _obscureConfirmation = !_obscureConfirmation,
                    ),
                    icon: Icon(
                      _obscureConfirmation
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value != _password.text) {
                    return 'The passwords do not match.';
                  }
                  return null;
                },
              ),
              if (auth.hasError) ...[
                const SizedBox(height: NovaSpacing.lg),
                ErrorBanner(message: friendlyErrorMessage(auth.error!)),
              ],
              const SizedBox(height: NovaSpacing.xl),
              NovaButton.primary(
                label: auth.isLoading ? 'Creating account…' : 'Create account',
                icon:
                    auth.isLoading ? Icons.hourglass_top : Icons.arrow_forward,
                onPressed: auth.isLoading ? null : _submit,
              ),
              const SizedBox(height: NovaSpacing.md),
              const Text(
                'By continuing, you acknowledge that nutrition and photo estimates are for wellness tracking and should be reviewed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NovaColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(authControllerProvider.notifier).register(
          _email.text.trim(),
          _password.text,
          _name.text.trim(),
        );
  }
}
