import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turtle_turning_pages/config/theme.dart';
import 'package:turtle_turning_pages/models/models.dart';
import 'package:turtle_turning_pages/providers/auth_provider.dart';
import 'package:turtle_turning_pages/providers/books_provider.dart';
import 'package:turtle_turning_pages/screens/home/home_screen.dart';

class _StubAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _StubAuthNotifier()
      : super(AuthState(
          isLoading: false,
          profile: Profile(
            id: 'me',
            fullName: 'Ayşe Demir',
            areaLabel: 'Moda, Kadıköy',
            points: 200,
            centroidLat: 40.9822,
            centroidLng: 29.0257,
          ),
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Book _book(String id, String title,
    {int requestCount = 0, double distance = 0.3}) {
  return Book(
    id: id,
    ownerId: 'other',
    title: title,
    author: 'Author',
    condition: BookCondition.good,
    language: 'English',
    requestCount: requestCount,
    distanceKm: distance,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpHome(WidgetTester tester, List<Book> books) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
        for (final path in ['/map', '/notifications', '/trades', '/journal'])
          GoRoute(
            path: path,
            builder: (c, s) => Scaffold(body: Text('page:$path')),
          ),
        GoRoute(
          path: '/book/:id',
          builder: (c, s) => const Scaffold(body: Text('page:book')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _StubAuthNotifier()),
          // Bypass Firestore: the pool is what the geohash query would return.
          nearbyPoolProvider.overrideWith((ref) async => books),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Books positioned ~0.1km from the Moda centroid
  Book nearBook(String id, String title, {int requestCount = 0}) =>
      _book(id, title, requestCount: requestCount).copyWith(
        locationLat: 40.9830,
        locationLng: 29.0260,
      );

  group('Home — The Shelf (mock #1a)', () {
    testWidgets('renders greeting, area, points, sections', (tester) async {
      await pumpHome(tester, [nearBook('b1', 'Piranesi')]);

      expect(find.textContaining('What will you pass on this week?',
              findRichText: true),
          findsOneWidget);
      expect(find.text('200 pts'), findsOneWidget);
      expect(find.text('New nearby'), findsOneWidget);
      expect(find.text('Most loved this month'), findsOneWidget);
      expect(find.text('From the club journal'), findsOneWidget);
    });

    testWidgets('map teaser shows the nearby count within 1 km',
        (tester) async {
      await pumpHome(tester, [
        nearBook('b1', 'Piranesi'),
        nearBook('b2', 'Norwegian Wood'),
      ]);

      expect(find.text('2 books within 1 km'), findsOneWidget);
    });

    testWidgets('own books are excluded (spec §7 + Build 8)', (tester) async {
      final mine = _book('mine', 'My Own Book').copyWith(
        ownerId: 'me',
        locationLat: 40.9830,
        locationLng: 29.0260,
      );
      await pumpHome(tester, [mine, nearBook('b1', 'Piranesi')]);

      expect(find.text('1 books within 1 km'), findsOneWidget);
      expect(find.text('My Own Book'), findsNothing);
    });

    testWidgets('most loved lists requested books with request counts',
        (tester) async {
      await pumpHome(tester, [
        nearBook('b1', 'Piranesi'),
        nearBook('b2', 'Tutunamayanlar', requestCount: 12),
      ]);

      expect(find.text('12 requests'), findsOneWidget);
    });

    testWidgets('bell opens notifications; map teaser opens map',
        (tester) async {
      await pumpHome(tester, []);

      await tester.tap(find.byKey(const Key('bell_button')));
      await tester.pumpAndSettle();
      expect(find.text('page:/notifications'), findsOneWidget);
    });
  });
}
