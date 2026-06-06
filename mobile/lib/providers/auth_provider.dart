import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../models/models.dart';
import '../services/firebase_service.dart';

/// Auth state model
class AuthState {
  final fb.User? user;
  final Profile? profile;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.profile,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    fb.User? user,
    Profile? profile,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  StreamSubscription<fb.User?>? _authSubscription;

  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _init();
  }

  void _init() {
    // Check current user
    final currentUser = FirebaseService.currentUser;
    if (currentUser != null) {
      _loadProfile(currentUser);
    } else {
      state = const AuthState(isLoading: false);
    }

    // Listen to auth changes
    _authSubscription = FirebaseService.authStateChanges.listen((user) {
      if (user != null) {
        _loadProfile(user);
      } else {
        state = const AuthState(isLoading: false);
      }
    });
  }

  Future<void> _loadProfile(fb.User? user) async {
    if (user == null) {
      state = const AuthState(isLoading: false);
      return;
    }

    state = state.copyWith(user: user, isLoading: true);

    try {
      var profile = await FirebaseService.getProfile(user.uid);

      // Profile should already exist from signup
      // If not, create a basic one
      if (profile == null) {
        await FirebaseService.db.collection('users').doc(user.uid).set({
          'id': user.uid,
          'email': user.email ?? '',
          'fullName': user.displayName ?? '',
          'avatarUrl': user.photoURL ?? '',
          'bio': '',
          'website': '',
          'university': '',
          'locationCity': '',
          'locationState': '',
          'locationCountry': '',
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        });
        profile = await FirebaseService.getProfile(user.uid);
      }

      state = AuthState(
        user: user,
        profile: profile,
        isLoading: false,
      );
    } catch (e) {
      state = AuthState(
        user: user,
        isLoading: false,
        error: 'Failed to load profile: $e',
      );
    }
  }

  /// Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final credential = await FirebaseService.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (credential.user != null) {
        await _loadProfile(credential.user);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Sign up failed.',
        );
        return false;
      }
    } on fb.FirebaseAuthException catch (e) {
      String message = e.message ?? 'Sign up failed';
      if (e.code == 'weak-password') {
        message = 'Password is too weak';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists with this email';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'An error occurred: $e');
      return false;
    }
  }

  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final credential = await FirebaseService.signIn(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _loadProfile(credential.user);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Sign in failed',
        );
        return false;
      }
    } on fb.FirebaseAuthException catch (e) {
      String message = e.message ?? 'Sign in failed';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later';
      }
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'An error occurred: $e');
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await FirebaseService.signOut();
      state = const AuthState(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Sign out failed: $e');
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await FirebaseService.resetPassword(email);
      state = state.copyWith(isLoading: false);
      return true;
    } on fb.FirebaseAuthException catch (e) {
      String message = e.message ?? 'Password reset failed';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email';
      }
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'An error occurred: $e');
      return false;
    }
  }

  /// Update profile
  Future<bool> updateProfile(Profile profile) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedProfile = await FirebaseService.updateProfile(profile);
      state = state.copyWith(
        profile: updatedProfile,
        isLoading: false,
      );
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
