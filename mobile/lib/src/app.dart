import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/nova_theme.dart';
import 'router/app_router.dart';

class NutriNovaApp extends ConsumerWidget {
  const NutriNovaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'NutriNova AI',
      debugShowCheckedModeBanner: false,
      theme: NovaTheme.light(),
      darkTheme: NovaTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
