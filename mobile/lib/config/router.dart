import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../screens/screens.dart';
import 'theme.dart';

/// Route names
class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String home = '/home';
  static const String discover = '/discover';
  static const String trades = '/trades';
  static const String messages = '/messages';
  static const String profile = '/profile';
  static const String bookDetail = '/book/:id';
  static const String tradeDetail = '/trade/:id';
  static const String chat = '/chat/:id';
  static const String addBook = '/add-book';
  static const String editBook = '/edit-book/:id';
  static const String editProfile = '/edit-profile';
  static const String proposeSwap = '/propose-swap/:bookId';
}

/// Notifier that triggers router refresh when auth or onboarding state changes
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
    ref.listen(onboardingNotifierProvider, (_, __) => notifyListeners());
  }
}

final routerRefreshProvider = Provider((ref) => RouterRefreshNotifier(ref));

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final onboardingState = ref.read(onboardingNotifierProvider);

      final isLoading = authState.isLoading;
      final isAuthenticated = authState.isAuthenticated;
      final isOnAuthPage = state.matchedLocation == AppRoutes.signIn ||
          state.matchedLocation == AppRoutes.signUp;
      final isOnSplash = state.matchedLocation == AppRoutes.splash;
      final isOnOnboarding = state.matchedLocation == AppRoutes.onboarding;

      final onboardingCompleted = onboardingState.valueOrNull ?? false;
      final onboardingLoading = onboardingState.isLoading;

      // Show splash while loading auth or onboarding state
      if (isLoading || onboardingLoading) {
        return isOnSplash ? null : AppRoutes.splash;
      }

      // If authenticated, go to home (skip onboarding for existing users)
      if (isAuthenticated) {
        if (isOnAuthPage || isOnSplash || isOnOnboarding) {
          return AppRoutes.home;
        }
        return null;
      }

      // Not authenticated: show onboarding first if not completed
      if (!onboardingCompleted && !isOnOnboarding) {
        return AppRoutes.onboarding;
      }

      // Not authenticated and onboarding done: go to sign in
      if (!isOnAuthPage) {
        return AppRoutes.signIn;
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Onboarding
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Auth routes
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),

      // Main shell with bottom navigation
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

      // Detail routes (push on top of shell)
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
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
});
