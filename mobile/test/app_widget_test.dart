import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrinova_ai/src/app.dart';

void main() {
  testWidgets('renders NutriNova app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NutriNovaApp()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('NutriNova AI'), findsWidgets);
  });
}
