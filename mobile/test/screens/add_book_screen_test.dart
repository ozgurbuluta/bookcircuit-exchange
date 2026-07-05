import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turtle_turning_pages/config/theme.dart';
import 'package:turtle_turning_pages/models/models.dart';
import 'package:turtle_turning_pages/providers/auth_provider.dart';
import 'package:turtle_turning_pages/screens/books/add_book_screen.dart';
import 'package:turtle_turning_pages/services/open_library_service.dart';

class _FakeOpenLibrary extends OpenLibraryService {
  @override
  Future<List<OpenLibraryBook>> searchBooks(String query) async {
    if (query.toLowerCase().contains('norwegian')) {
      return const [
        OpenLibraryBook(
          title: 'Norwegian Wood',
          author: 'Haruki Murakami',
          isbn: '9780099448822',
          publishYear: 1987,
          pages: 296,
          publisher: 'Vintage',
        ),
      ];
    }
    return const [];
  }
}

class _StubAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _StubAuthNotifier()
      : super(AuthState(
          isLoading: false,
          profile: Profile(
            id: 'u1',
            fullName: 'Ayşe Demir',
            postalCode: '34710',
            areaLabel: 'Moda, Kadıköy',
            languages: const ['Türkçe', 'English'],
            centroidLat: 40.9822,
            centroidLng: 29.0257,
          ),
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpAddBook(WidgetTester tester) async {
    // Tall viewport so the whole form is built (ListView children are lazy).
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _StubAuthNotifier()),
          openLibraryServiceProvider.overrideWithValue(_FakeOpenLibrary()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AddBookScreen(),
        ),
      ),
    );
  }

  group('AddBookScreen (mock #1d, spec §6)', () {
    testWidgets('search shows an Open Library match and prefills the card',
        (tester) async {
      await pumpAddBook(tester);

      await tester.enterText(
          find.byKey(const Key('lookup_field')), 'Norwegian Wood');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('match_Norwegian Wood')));
      await tester.pumpAndSettle();

      expect(find.text('We found it — Open Library match'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('title_field')))
            .controller!
            .text,
        'Norwegian Wood',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('author_field')))
            .controller!
            .text,
        'Haruki Murakami',
      );
    });

    testWidgets(
        'add button stays disabled until language AND condition are confirmed',
        (tester) async {
      await pumpAddBook(tester);

      await tester.enterText(
          find.byKey(const Key('lookup_field')), 'Norwegian Wood');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('match_Norwegian Wood')));
      await tester.pumpAndSettle();

      ElevatedButton saveButton() => tester
          .widget<ElevatedButton>(find.byKey(const Key('add_to_shelf')));

      expect(saveButton().onPressed, isNull);

      await tester.ensureVisible(find.byKey(const Key('add_language_Türkçe')));
      await tester.tap(find.byKey(const Key('add_language_Türkçe')));
      await tester.pump();
      expect(saveButton().onPressed, isNull,
          reason: 'condition still missing');

      await tester
          .ensureVisible(find.byKey(const Key('condition_very_good')));
      await tester.tap(find.byKey(const Key('condition_very_good')));
      await tester.pump();
      expect(saveButton().onPressed, isNotNull);
    });

    testWidgets('shows exactly the 4 spec conditions', (tester) async {
      await pumpAddBook(tester);

      await tester.tap(find.byKey(const Key('enter_manually')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('condition_like_new')), findsOneWidget);
      expect(find.byKey(const Key('condition_very_good')), findsOneWidget);
      expect(find.byKey(const Key('condition_good')), findsOneWidget);
      expect(find.byKey(const Key('condition_well_read')), findsOneWidget);
    });

    testWidgets('visibility toggle defaults ON (spec §6)', (tester) async {
      await pumpAddBook(tester);

      await tester.tap(find.byKey(const Key('enter_manually')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('visible_toggle')));

      final toggle = tester
          .widget<SwitchListTile>(find.byKey(const Key('visible_toggle')));
      expect(toggle.value, isTrue);
    });

    testWidgets('user languages appear first among the language chips',
        (tester) async {
      await pumpAddBook(tester);

      await tester.tap(find.byKey(const Key('enter_manually')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_language_Türkçe')), findsOneWidget);
      expect(find.byKey(const Key('add_language_English')), findsOneWidget);
    });
  });
}
