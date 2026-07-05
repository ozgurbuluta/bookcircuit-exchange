import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turtle_turning_pages/config/theme.dart';
import 'package:turtle_turning_pages/providers/conversations_provider.dart';
import 'package:turtle_turning_pages/screens/main_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpShell(WidgetTester tester, {int unread = 0}) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            for (final path in ['/home', '/journal', '/messages', '/shelf'])
              GoRoute(
                path: path,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: Scaffold(body: Text('page:$path')),
                ),
              ),
          ],
        ),
        GoRoute(
          path: '/add-book',
          builder: (context, state) =>
              const Scaffold(body: Text('page:/add-book')),
        ),
        GoRoute(
          path: '/scan-shelf',
          builder: (context, state) =>
              const Scaffold(body: Text('page:/scan-shelf')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unreadMessagesCountProvider.overrideWith((ref) async => unread),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('MainShell (spec §2 tab bar)', () {
    testWidgets('shows Home · Journal · Add book · Chats · Shelf',
        (tester) async {
      await pumpShell(tester);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Add book'), findsOneWidget);
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Shelf'), findsOneWidget);
      expect(find.byKey(const Key('add_book_fab')), findsOneWidget);
    });

    testWidgets('tab taps navigate between the four tab pages',
        (tester) async {
      await pumpShell(tester);
      expect(find.text('page:/home'), findsOneWidget);

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();
      expect(find.text('page:/journal'), findsOneWidget);

      await tester.tap(find.text('Shelf'));
      await tester.pumpAndSettle();
      expect(find.text('page:/shelf'), findsOneWidget);

      await tester.tap(find.text('Chats'));
      await tester.pumpAndSettle();
      expect(find.text('page:/messages'), findsOneWidget);
    });

    testWidgets('center button opens the add-book options sheet',
        (tester) async {
      await pumpShell(tester);

      await tester.tap(find.byKey(const Key('add_book_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Scan a book'), findsOneWidget);
      expect(find.text('Scan a shelf'), findsOneWidget);
      expect(find.text('Enter manually'), findsOneWidget);
    });

    testWidgets('unread badge shows on Chats', (tester) async {
      await pumpShell(tester, unread: 3);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
