import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return NovaAuthScaffold(
      title: 'Welcome back',
      subtitle:
          'Log meals, review nutrition, and keep your daily momentum going.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'New here?',
            style: TextStyle(color: NovaColors.graphite),
          ),
          TextButton(
            onPressed: auth.isLoading ? null : () => context.go('/register'),
            child: const Text('Create an account'),
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
                'Sign in',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: NovaSpacing.xs),
              const Text(
                'Use the account you created for this local beta.',
                style: TextStyle(color: NovaColors.graphite),
              ),
              const SizedBox(height: NovaSpacing.xl),
              TextFormField(
                controller: _email,
                enabled: !auth.isLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
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
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
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
                  if (value == null || value.isEmpty) {
                    return 'Enter your password.';
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
                label: auth.isLoading ? 'Signing in…' : 'Sign in',
                icon: auth.isLoading ? Icons.hourglass_top : Icons.login,
                onPressed: auth.isLoading ? null : _submit,
              ),
              const SizedBox(height: NovaSpacing.md),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 15,
                    color: NovaColors.muted,
                  ),
                  SizedBox(width: NovaSpacing.xs),
                  Flexible(
                    child: Text(
                      'Your meals and progress stay private to your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: NovaColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
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
    ref.read(authControllerProvider.notifier).login(
          _email.text.trim(),
          _password.text,
        );
  }
}
