// Basic Flutter widget test for Turtle Turning Pages

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turtle_turning_pages/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: TurtleTurningPagesApp(),
      ),
    );

    // Verify the app starts (will show splash or auth screen)
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Basic smoke test - app should render something
    expect(find.byType(TurtleTurningPagesApp), findsOneWidget);
  });
}
