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
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return NovaScaffold(
      title: 'Create account',
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.xl),
        children: [
          Text(
            'Start with a clean health record.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: NovaSpacing.xl),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Display name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: NovaSpacing.md),
          TextField(
            controller: _email,
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
            label: auth.isLoading ? 'Creating...' : 'Create account',
            icon: Icons.arrow_forward,
            onPressed: auth.isLoading
                ? null
                : () => ref.read(authControllerProvider.notifier).register(
                      _email.text.trim(),
                      _password.text,
                      _name.text.trim().isEmpty ? 'NutriNova user' : _name.text,
                    ),
          ),
          if (auth.hasError) ...[
            const SizedBox(height: NovaSpacing.lg),
            ErrorBanner(message: auth.error.toString()),
          ],
          const SizedBox(height: NovaSpacing.md),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('I already have an account'),
          ),
        ],
      ),
    );
  }
}
