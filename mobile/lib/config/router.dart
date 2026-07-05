import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../screens/screens.dart';
import 'theme.dart';

/// Route names
class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String setup = '/setup';
  static const String firstShelf = '/first-shelf';
  static const String welcome = '/welcome';
  static const String emailSignIn = '/email-sign-in';
  static const String home = '/home';
  static const String journal = '/journal';
  static const String shelf = '/shelf';
  static const String discover = '/discover';
  static const String trades = '/trades';
  static const String messages = '/messages';
  static const String profile = '/profile';
  static const String bookDetail = '/book/:id';
  static const String tradeDetail = '/trade/:id';
  static const String chat = '/chat/:id';
  static const String addBook = '/add-book';
  static const String scanShelf = '/scan-shelf';
  static const String scanReview = '/scan-review';
  static const String editBook = '/edit-book/:id';
  static const String editProfile = '/edit-profile';
  static const String proposeSwap = '/propose-swap/:bookId';
}

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final tourState = ref.watch(onboardingNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final isAuthenticated = authState.isAuthenticated;
      final currentPath = state.matchedLocation;

      final isOnAuthPage = currentPath == AppRoutes.welcome ||
                           currentPath == AppRoutes.emailSignIn;
      final isOnSplash = currentPath == AppRoutes.splash;
      final isOnOnboarding = currentPath == AppRoutes.onboarding ||
                             currentPath == AppRoutes.setup ||
                             currentPath == AppRoutes.firstShelf;

      // Show splash while loading
      if (isLoading) {
        return isOnSplash ? null : AppRoutes.splash;
      }

      if (isAuthenticated) {
        // Onboarding gate (spec §2): tour once, then neighborhood setup.
        // Server truth (profile.hasCompletedSetup), not just a local flag.
        final needsSetup = authState.needsNeighborhoodSetup;
        if (needsSetup) {
          final tourSeen = tourState.value ?? true; // don't gate while loading
          final target =
              tourSeen ? AppRoutes.setup : AppRoutes.onboarding;
          return isOnOnboarding ? null : target;
        }

        if (isOnAuthPage || isOnSplash) {
          return AppRoutes.home;
        }
        return null;
      }

      // Not authenticated - go to the welcome screen
      if (!isOnAuthPage) {
        return AppRoutes.welcome;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.setup,
        builder: (context, state) => const NeighborhoodSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.firstShelf,
        builder: (context, state) => const FirstShelfScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailSignIn,
        builder: (context, state) => const EmailSignInScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.journal,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: JournalScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.messages,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MessagesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.shelf,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      // Pushed screens (not tabs): My trades via the points badge (spec §2),
      // map/discover until Phase G folds it into Home.
      GoRoute(
        path: AppRoutes.trades,
        builder: (context, state) => const TradesScreen(),
      ),
      GoRoute(
        path: AppRoutes.discover,
        builder: (context, state) => const DiscoverScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookDetail,
        builder: (context, state) {
          final bookId = state.pathParameters['id']!;
          return BookDetailScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: AppRoutes.tradeDetail,
        builder: (context, state) {
          final tradeId = state.pathParameters['id']!;
          return TradeDetailScreen(tradeId: tradeId);
        },
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) {
          final conversationId = state.pathParameters['id']!;
          final otherUserId = state.uri.queryParameters['userId'];
          final bookId = state.uri.queryParameters['bookId'];
          return ChatScreen(
            conversationId: conversationId,
            otherUserId: otherUserId,
            bookId: bookId,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.addBook,
        builder: (context, state) => const AddBookScreen(),
      ),
      GoRoute(
        path: AppRoutes.scanShelf,
        builder: (context, state) => const ScanShelfScreen(),
      ),
      GoRoute(
        path: AppRoutes.scanReview,
        builder: (context, state) {
          final books = (state.extra as List<DetectedBook>?) ?? const [];
          return ScanReviewScreen(books: books);
        },
      ),
      GoRoute(
        path: AppRoutes.editBook,
        builder: (context, state) {
          final bookId = state.pathParameters['id']!;
          return EditBookScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.proposeSwap,
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          return ProposeSwapScreen(bookId: bookId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Page not found: ${state.matchedLocation}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.welcome),
              child: const Text('Back to start'),
            ),
          ],
        ),
      ),
    ),
  );
});
