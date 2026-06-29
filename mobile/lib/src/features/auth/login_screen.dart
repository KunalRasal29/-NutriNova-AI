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
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(NovaSpacing.xl),
          children: [
            const SizedBox(height: NovaSpacing.xxl),
            const Icon(Icons.bolt_rounded, size: 48, color: NovaColors.mint),
            const SizedBox(height: NovaSpacing.lg),
            Text(
              'NutriNova AI',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: NovaSpacing.sm),
            const Text(
              'Track food, habits, progress, and AI-assisted meal reviews.',
              style: TextStyle(color: NovaColors.graphite),
            ),
            const SizedBox(height: NovaSpacing.xl),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: NovaSpacing.md),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: NovaSpacing.xl),
            NovaButton.primary(
              label: auth.isLoading ? 'Signing in...' : 'Sign in',
              icon: Icons.login,
              onPressed: auth.isLoading
                  ? null
                  : () => ref
                      .read(authControllerProvider.notifier)
                      .login(_email.text.trim(), _password.text),
            ),
            const SizedBox(height: NovaSpacing.md),
            NovaButton.secondary(
              label: 'Create account',
              icon: Icons.person_add_alt,
              onPressed: () => context.go('/register'),
            ),
            if (auth.hasError) ...[
              const SizedBox(height: NovaSpacing.lg),
              ErrorBanner(message: auth.error.toString()),
            ],
          ],
        ),
      ),
    );
  }
}
