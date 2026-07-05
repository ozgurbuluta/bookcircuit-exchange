import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turtle_turning_pages/config/theme.dart';
import 'package:turtle_turning_pages/providers/auth_provider.dart';
import 'package:turtle_turning_pages/screens/auth/welcome_screen.dart';

/// Auth notifier stub that never touches Firebase.
class _StubAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _StubAuthNotifier() : super(const AuthState(isLoading: false));

  final List<String> calls = [];

  @override
  Future<bool> signInWithApple() async {
    calls.add('apple');
    return true;
  }

  @override
  Future<bool> signInWithGoogle() async {
    calls.add('google');
    return true;
  }

  @override
  Future<bool> sendEmailLink(String email) async {
    calls.add('email:$email');
    state = state.copyWith(awaitingEmailLink: true);
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

  Future<_StubAuthNotifier> pumpWelcome(WidgetTester tester) async {
    final stub = _StubAuthNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => stub),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const WelcomeScreen(),
        ),
      ),
    );
    return stub;
  }

  group('WelcomeScreen (mock #3a)', () {
    testWidgets('renders brand, Piri copy, and all three auth options',
        (tester) async {
      await pumpWelcome(tester);

      expect(find.text('Turtle Turning Pages'), findsOneWidget);
      expect(find.text('Good books travel slowly.'), findsOneWidget);
      expect(find.textContaining("I'm Piri"), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Use email instead'), findsOneWidget);
    });

    testWidgets('club rules footer has no exclamation marks (spec §10)',
        (tester) async {
      await pumpWelcome(tester);
      expect(find.textContaining('club rules'), findsOneWidget);
      final footer = tester
          .widget<Text>(find.textContaining('club rules'))
          .data!;
      expect(footer.contains('!'), isFalse);
    });

    testWidgets('apple button calls signInWithApple', (tester) async {
      final stub = await pumpWelcome(tester);

      await tester.tap(find.byKey(const Key('apple_sign_in')));
      await tester.pump();

      expect(stub.calls, ['apple']);
    });

    testWidgets('google button calls signInWithGoogle', (tester) async {
      final stub = await pumpWelcome(tester);

      await tester.tap(find.byKey(const Key('google_sign_in')));
      await tester.pump();

      expect(stub.calls, ['google']);
    });
  });
}
