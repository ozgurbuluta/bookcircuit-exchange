import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turtle_turning_pages/config/theme.dart';
import 'package:turtle_turning_pages/models/models.dart';
import 'package:turtle_turning_pages/providers/auth_provider.dart';
import 'package:turtle_turning_pages/providers/books_provider.dart';
import 'package:turtle_turning_pages/screens/trades/trade_request_sheet.dart';

class _StubAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _StubAuthNotifier(int points)
      : super(AuthState(
          isLoading: false,
          profile: Profile(id: 'me', fullName: 'Ayşe', points: points),
        ));

  @override
  Future<void> refreshProfile() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Book _target() => Book(
      id: 'b1',
      ownerId: 'owner',
      title: 'Piranesi',
      author: 'Susanna Clarke',
      condition: BookCondition.veryGood,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

Book _mine(String id) => Book(
      id: id,
      ownerId: 'me',
      title: 'Mine $id',
      author: 'Me',
      condition: BookCondition.good,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    required int points,
    List<Book> myBooks = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _StubAuthNotifier(points)),
          myBooksProvider.overrideWith((ref) async => myBooks),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: TradeRequestSheet(book: _target())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('TradeRequestSheet (mock #2b, spec §4)', () {
    testWidgets('points offer is default with escrow reassurance copy',
        (tester) async {
      await pumpSheet(tester, points: 200, myBooks: [_mine('m1')]);

      expect(find.text('Send request · 50 pts'), findsOneWidget);
      expect(find.byKey(const Key('escrow_copy')), findsOneWidget);
      expect(find.textContaining('returned in full'), findsOneWidget);
    });

    testWidgets('book offer requires picking exactly one of my books',
        (tester) async {
      await pumpSheet(tester, points: 200, myBooks: [_mine('m1'), _mine('m2')]);

      await tester.tap(find.byKey(const Key('offer_book')));
      await tester.pumpAndSettle();

      ElevatedButton send() =>
          tester.widget<ElevatedButton>(find.byKey(const Key('send_request')));
      expect(send().onPressed, isNull, reason: 'no book picked yet');

      await tester.tap(find.byKey(const Key('pick_m1')));
      await tester.pumpAndSettle();
      expect(send().onPressed, isNotNull);
      expect(find.text('Send request'), findsOneWidget);
    });

    testWidgets(
        'under 50 pts with no books shows the shelve-a-book hint (spec §4.10)',
        (tester) async {
      await pumpSheet(tester, points: 20, myBooks: const []);

      expect(find.byKey(const Key('blocked_hint')), findsOneWidget);
      expect(find.text('Shelve a book to earn points'), findsOneWidget);
      final send =
          tester.widget<ElevatedButton>(find.byKey(const Key('send_request')));
      expect(send.onPressed, isNull);
    });

    testWidgets(
        'under 50 pts but with books: points disabled, book offer available',
        (tester) async {
      await pumpSheet(tester, points: 20, myBooks: [_mine('m1')]);

      expect(find.byKey(const Key('blocked_hint')), findsNothing);
      expect(find.text('not enough points'), findsOneWidget);
    });
  });
}
