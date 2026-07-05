import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../screens/screens.dart';
import 'theme.dart';

/// Route names
class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String emailSignIn = '/email-sign-in';
  static const String home = '/home';
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

      // Show splash while loading
      if (isLoading) {
        return isOnSplash ? null : AppRoutes.splash;
      }

      // Authenticated users go to home
      if (isAuthenticated) {
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
            path: AppRoutes.discover,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DiscoverScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.trades,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TradesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.messages,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MessagesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
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
