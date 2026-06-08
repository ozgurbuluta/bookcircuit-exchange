import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
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

/// Listenable that notifies when auth state changes
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

final _authChangeProvider = Provider((ref) => AuthChangeNotifier(ref));

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = ref.watch(_authChangeProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      final isLoading = authState.isLoading;
      final isAuthenticated = authState.isAuthenticated;
      final currentPath = state.matchedLocation;

      final isOnAuthPage = currentPath == AppRoutes.signIn ||
                           currentPath == AppRoutes.signUp;
      final isOnSplash = currentPath == AppRoutes.splash;
      final isOnOnboarding = currentPath == AppRoutes.onboarding;

      // Show splash while loading
      if (isLoading) {
        return isOnSplash ? null : AppRoutes.splash;
      }

      // Authenticated users go to home
      if (isAuthenticated) {
        if (isOnAuthPage || isOnSplash || isOnOnboarding) {
          return AppRoutes.home;
        }
        return null;
      }

      // Not authenticated - go to sign in (skip onboarding for now to debug)
      if (!isOnAuthPage) {
        return AppRoutes.signIn;
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
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
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
              onPressed: () => context.go(AppRoutes.signIn),
              child: const Text('Go to Sign In'),
            ),
          ],
        ),
      ),
    ),
  );
});
