import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/user_bootstrap_service.dart';

/// Auth state model
class AuthState {
  final fb.User? user;
  final Profile? profile;
  final bool isLoading;
  final String? error;

  /// Set after a sign-in link is emailed — drives the "check your email" UI.
  final bool awaitingEmailLink;

  const AuthState({
    this.user,
    this.profile,
    this.isLoading = false,
    this.error,
    this.awaitingEmailLink = false,
  });

  bool get isAuthenticated => user != null;

  /// Onboarding gate (plan Phase D): server truth, not a local flag.
  bool get needsNeighborhoodSetup =>
      isAuthenticated && profile != null && !profile!.hasCompletedSetup;

  AuthState copyWith({
    fb.User? user,
    Profile? profile,
    bool? isLoading,
    String? error,
    bool? awaitingEmailLink,
  }) {
    return AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      awaitingEmailLink: awaitingEmailLink ?? this.awaitingEmailLink,
    );
  }
}

/// Auth state notifier — Apple / Google / email link only (spec §5).
class AuthNotifier extends StateNotifier<AuthState> {
  StreamSubscription<fb.User?>? _authSubscription;
  StreamSubscription<Uri>? _linkSubscription;
  final UserBootstrapService _bootstrap;

  AuthNotifier({UserBootstrapService? bootstrap})
      : _bootstrap = bootstrap ?? UserBootstrapService(FirebaseService.db),
        super(const AuthState(isLoading: true)) {
    _init();
  }

  void _init() {
    final currentUser = FirebaseService.currentUser;
    if (currentUser != null) {
      _loadProfile(currentUser);
    } else {
      state = const AuthState(isLoading: false);
    }

    _authSubscription = FirebaseService.authStateChanges.listen((user) {
      if (user != null) {
        _loadProfile(user);
      } else {
        state = const AuthState(isLoading: false);
      }
    });

    _listenForEmailLinks();
  }

  /// Email-link completion arrives as a universal link (docs/SETUP_AUTH.md).
  void _listenForEmailLinks() {
    final appLinks = AppLinks();

    Future<void> handle(Uri? uri) async {
      if (uri == null) return;
      final link = uri.toString();
      if (!AuthService.isSignInLink(link)) return;
      try {
        final credential = await AuthService.completeSignInWithLink(link);
        if (credential == null) {
          state = state.copyWith(
            isLoading: false,
            error:
                'Open the link on the device you signed up with, or enter your email again.',
          );
          return;
        }
        await _afterSignIn(credential.user);
      } catch (e) {
        state = state.copyWith(isLoading: false, error: 'Sign-in failed: $e');
      }
    }

    appLinks.getInitialLink().then(handle);
    _linkSubscription = appLinks.uriLinkStream.listen(handle);
  }

  /// Shared post-credential path: bootstrap the user doc, apply the one-time
  /// welcome grant, then load the profile.
  Future<void> _afterSignIn(fb.User? user, {String? displayName}) async {
    if (user == null) return;
    state = state.copyWith(user: user, isLoading: true, awaitingEmailLink: false);

    await _bootstrap.ensureUserDocument(
      uid: user.uid,
      email: user.email,
      displayName: displayName ?? user.displayName,
      avatarUrl: user.photoURL,
    );
    await _bootstrap.grantWelcomePointsIfNeeded(user.uid);
    await _loadProfile(user);
  }

  Future<void> _loadProfile(fb.User? user) async {
    if (user == null) {
      state = const AuthState(isLoading: false);
      return;
    }

    state = state.copyWith(user: user, isLoading: true);

    try {
      var profile = await FirebaseService.getProfile(user.uid);
      // Sessions predating the bootstrap path (or racing it) self-heal here.
      if (profile == null) {
        profile = await _bootstrap.ensureUserDocument(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          avatarUrl: user.photoURL,
        );
        await _bootstrap.grantWelcomePointsIfNeeded(user.uid);
        profile = await FirebaseService.getProfile(user.uid);
      }

      state = AuthState(user: user, profile: profile, isLoading: false);
      // Best-effort push registration (D12) — never blocks sign-in.
      NotificationService().registerForUser(user.uid);
    } catch (e) {
      state = AuthState(
        user: user,
        isLoading: false,
        error: 'Failed to load profile: $e',
      );
    }
  }

  // ---- Sign-in entries (welcome screen #3a) ----

  Future<bool> signInWithApple() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await AuthService.signInWithApple();
      await _afterSignIn(result.credential.user,
          displayName: result.displayName);
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.code == AuthorizationErrorCode.canceled
            ? null
            : 'Apple sign-in failed. Try again.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'Apple sign-in failed. Try again.');
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final credential = await AuthService.signInWithGoogle();
      await _afterSignIn(credential.user);
      return true;
    } on GoogleSignInException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.code == GoogleSignInExceptionCode.canceled
            ? null
            : 'Google sign-in failed. Try again.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'Google sign-in failed. Try again.');
      return false;
    }
  }

  Future<bool> sendEmailLink(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await AuthService.sendSignInLink(email.trim());
      state = state.copyWith(isLoading: false, awaitingEmailLink: true);
      return true;
    } on fb.FirebaseAuthException catch (e) {
      String message = 'Could not send the link. Try again.';
      if (e.code == 'invalid-email') {
        message = 'That email address does not look right.';
      }
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'Could not send the link. Try again.');
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      final uid = state.user?.uid;
      if (uid != null) {
        await NotificationService().unregister(uid);
      }
      await AuthService.signOut();
      state = const AuthState(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Sign out failed: $e');
    }
  }

  /// Update profile
  Future<bool> updateProfile(Profile profile) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedProfile = await FirebaseService.updateProfile(profile);
      state = state.copyWith(profile: updatedProfile, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update profile: $e',
      );
      return false;
    }
  }

  /// Refresh profile
  Future<void> refreshProfile() async {
    if (state.user != null) {
      final profile = await FirebaseService.getProfile(state.user!.uid);
      state = state.copyWith(profile: profile);
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Current user provider (convenience)
final currentUserProvider = Provider<fb.User?>((ref) {
  return ref.watch(authProvider).user;
});

/// Current profile provider (convenience)
final currentProfileProvider = Provider<Profile?>((ref) {
  return ref.watch(authProvider).profile;
});

/// Is authenticated provider (convenience)
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});
