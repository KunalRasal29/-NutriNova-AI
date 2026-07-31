import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrinova_ai/src/core/repositories/nutrition_repository.dart';
import 'package:nutrinova_ai/src/core/repositories/providers.dart';
import 'package:nutrinova_ai/src/core/theme/nova_theme.dart';
import 'package:nutrinova_ai/src/core/widgets/nova_widgets.dart';
import 'package:nutrinova_ai/src/features/community/friends_beta_screen.dart';

void main() {
  testWidgets('add sheet fits a laptop-height viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const NovaScaffold(
            title: 'Today',
            body: SizedBox.expand(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: NovaTheme.dark(),
        routerConfig: router,
      ),
    );

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add to today'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('friend group dialog closes without a disposed controller', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const FriendsBetaScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nutritionRepositoryProvider.overrideWithValue(
            MockNutritionRepository(),
          ),
        ],
        child: MaterialApp.router(
          theme: NovaTheme.dark(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Weekend Crew');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('No friend group yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
