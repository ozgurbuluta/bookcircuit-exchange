import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turtle_turning_pages/config/theme.dart';
import 'package:turtle_turning_pages/models/models.dart';
import 'package:turtle_turning_pages/providers/auth_provider.dart';
import 'package:turtle_turning_pages/providers/books_provider.dart';
import 'package:turtle_turning_pages/screens/profile/profile_screen.dart';

class _StubAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _StubAuthNotifier()
      : super(AuthState(
          isLoading: false,
          profile: Profile(
            id: 'u1',
            fullName: 'Ayşe Demir',
            areaLabel: 'Moda, Kadıköy',
            points: 150,
            ratingAvg: 4.8,
            ratingCount: 9,
            tradeCount: 9,
            createdAt: DateTime(2026, 5, 1),
          ),
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Book _book(String id, String title, BookStatus status, {bool visible = true}) {
  return Book(
    id: id,
    ownerId: 'u1',
    title: title,
    author: 'Author',
    condition: BookCondition.good,
    status: status,
    visible: visible,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpShelf(WidgetTester tester, List<Book> books) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/shelf',
      routes: [
        GoRoute(
          path: '/shelf',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/trades',
          builder: (context, state) => const Scaffold(body: Text('my trades')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _StubAuthNotifier()),
          myBooksProvider.overrideWith((ref) async => books),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('My shelf (mock #1h)', () {
    testWidgets('header shows name, area, points, and rating', (tester) async {
      await pumpShelf(tester, []);

      expect(find.text('Ayşe Demir'), findsOneWidget);
      expect(find.textContaining('Moda, Kadıköy'), findsOneWidget);
      expect(find.textContaining('member since May 2026'), findsOneWidget);
      expect(find.text('150 pts'), findsOneWidget);
      expect(find.text('4.8 from 9 trades'), findsOneWidget);
    });

    testWidgets('filter chips count on-shelf vs in-trade books',
        (tester) async {
      await pumpShelf(tester, [
        _book('b1', 'Piranesi', BookStatus.onShelf),
        _book('b2', 'Norwegian Wood', BookStatus.onShelf),
        _book('b3', 'Küçük Prens', BookStatus.inTrade),
        _book('b4', 'Traded Away', BookStatus.tradedAway),
      ]);

      expect(find.text('My shelf · 2'), findsOneWidget);
      expect(find.text('In trades · 1'), findsOneWidget);
      // Default filter shows on-shelf books only (title appears on the
      // generated cover AND the caption, so expect at least one)
      expect(find.text('Piranesi'), findsWidgets);
      expect(find.text('Küçük Prens'), findsNothing);
      expect(find.text('Traded Away'), findsNothing);
    });

    testWidgets('in-trade filter shows the In trade overlay', (tester) async {
      await pumpShelf(tester, [
        _book('b3', 'Küçük Prens', BookStatus.inTrade),
      ]);

      await tester.tap(find.byKey(const Key('filter_in_trade')));
      await tester.pumpAndSettle();

      expect(find.text('Küçük Prens'), findsWidgets);
      expect(find.byKey(const Key('in_trade_b3')), findsOneWidget);
    });

    testWidgets('points badge navigates to My trades (spec §2)',
        (tester) async {
      await pumpShelf(tester, []);

      await tester.tap(find.text('150 pts'));
      await tester.pumpAndSettle();

      expect(find.text('my trades'), findsOneWidget);
    });

    testWidgets('on-shelf books expose a visibility toggle', (tester) async {
      await pumpShelf(tester, [
        _book('b1', 'Piranesi', BookStatus.onShelf),
      ]);

      expect(find.byKey(const Key('visibility_b1')), findsOneWidget);
    });
  });
}
