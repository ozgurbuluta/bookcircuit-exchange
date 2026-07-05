import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turtle_turning_pages/config/theme.dart';
import 'package:turtle_turning_pages/models/models.dart';
import 'package:turtle_turning_pages/providers/auth_provider.dart';
import 'package:turtle_turning_pages/screens/onboarding/neighborhood_setup_screen.dart';
import 'package:turtle_turning_pages/screens/onboarding/onboarding_screen.dart';
import 'package:turtle_turning_pages/services/neighborhood_service.dart';

class _FakeNeighborhoodService extends NeighborhoodService {
  @override
  Future<NeighborhoodResult?> resolvePostalCode(String postalCode) async {
    if (postalCode.trim() == '34710') {
      return const NeighborhoodResult(
        postalCode: '34710',
        areaLabel: 'Moda, Kadıköy',
        lat: 40.9822,
        lng: 29.0257,
      );
    }
    return null;
  }
}

class _StubAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _StubAuthNotifier()
      : super(AuthState(
          isLoading: false,
          profile: Profile(id: 'u1', fullName: 'Ayşe Demir'),
        ));

  Profile? savedProfile;

  @override
  Future<bool> updateProfile(Profile profile) async {
    savedProfile = profile;
    state = state.copyWith(profile: profile);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Tour (mocks #3b-#3d)', () {
    Future<void> pumpTour(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const OnboardingScreen(),
          ),
        ),
      );
    }

    testWidgets('renders the first card with spec copy and Piri quote',
        (tester) async {
      await pumpTour(tester);

      expect(find.text("Shelve what you've finished"), findsOneWidget);
      expect(find.textContaining('Four books is a fine start'), findsOneWidget);
      expect(find.text('Skip the tour'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('last card says Join the club (spec #3d)', (tester) async {
      await pumpTour(tester);

      await tester.tap(find.byKey(const Key('tour_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tour_next')));
      await tester.pumpAndSettle();

      expect(find.text('Every book is a flat 50 pts'), findsOneWidget);
      expect(find.text('Join the club'), findsOneWidget);
      expect(find.textContaining('Spend them slowly'), findsOneWidget);
    });

    testWidgets('skip is available on every card (spec §5)', (tester) async {
      await pumpTour(tester);
      for (var i = 0; i < 3; i++) {
        expect(find.text('Skip the tour'), findsOneWidget);
        if (i < 2) {
          await tester.tap(find.byKey(const Key('tour_next')));
          await tester.pumpAndSettle();
        }
      }
    });
  });

  group('Neighborhood setup (mock #3e)', () {
    late _StubAuthNotifier stub;

    Future<void> pumpSetup(WidgetTester tester) async {
      stub = _StubAuthNotifier();
      final router = GoRouter(
        initialLocation: '/setup',
        routes: [
          GoRoute(
            path: '/setup',
            builder: (context, state) => const NeighborhoodSetupScreen(),
          ),
          GoRoute(
            path: '/first-shelf',
            builder: (context, state) =>
                const Scaffold(body: Text('first shelf')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => stub),
            neighborhoodServiceProvider
                .overrideWithValue(_FakeNeighborhoodService()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
    }

    testWidgets('renders headline, postal field, languages, privacy note',
        (tester) async {
      await pumpSetup(tester);

      expect(find.text('Your corner of the city'), findsOneWidget);
      expect(find.byKey(const Key('postal_field')), findsOneWidget);
      expect(find.text('Use my location'), findsOneWidget);
      expect(find.text('Languages you read'), findsOneWidget);
      expect(find.textContaining('never your street'), findsOneWidget);
    });

    testWidgets('continue is disabled until postal code resolves',
        (tester) async {
      await pumpSetup(tester);

      final button = tester
          .widget<ElevatedButton>(find.byKey(const Key('setup_continue')));
      expect(button.onPressed, isNull);
    });

    testWidgets('valid postal code enables continue and saves profile',
        (tester) async {
      await pumpSetup(tester);

      await tester.enterText(find.byKey(const Key('postal_field')), '34710');
      await tester.pumpAndSettle();

      // Area label appears in the privacy preview (rendered as a rich span)
      expect(
        find.textContaining('Moda, Kadıköy', findRichText: true),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('setup_continue')));
      await tester.pumpAndSettle();

      expect(stub.savedProfile, isNotNull);
      expect(stub.savedProfile!.postalCode, '34710');
      expect(stub.savedProfile!.areaLabel, 'Moda, Kadıköy');
      expect(stub.savedProfile!.languages, isNotEmpty);
      expect(stub.savedProfile!.centroidLat, closeTo(40.98, 0.01));
    });

    testWidgets('deselecting every language disables continue (≥1 required)',
        (tester) async {
      await pumpSetup(tester);

      await tester.enterText(find.byKey(const Key('postal_field')), '34710');
      await tester.pumpAndSettle();

      // The device locale in tests is 'en' → English preselected. Deselect it.
      await tester.tap(find.byKey(const Key('language_English')));
      await tester.pumpAndSettle();

      final button = tester
          .widget<ElevatedButton>(find.byKey(const Key('setup_continue')));
      expect(button.onPressed, isNull);
    });

    testWidgets('junk postal code never enables continue', (tester) async {
      await pumpSetup(tester);

      await tester.enterText(
          find.byKey(const Key('postal_field')), 'not a postal code');
      await tester.pumpAndSettle();

      final button = tester
          .widget<ElevatedButton>(find.byKey(const Key('setup_continue')));
      expect(button.onPressed, isNull);
    });
  });
}
