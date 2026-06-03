import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Auth state model
class AuthState {
  final User? user;
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
    User? user,
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
  StreamSubscription<AuthState>? _authSubscription;

  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _init();
  }

  void _init() {
    // Check current session
    final session = SupabaseService.currentSession;
    if (session != null) {
      _loadProfile(session.user);
    } else {
      state = const AuthState(isLoading: false);
    }

    // Listen to auth changes
    SupabaseService.authStateChanges.listen((authState) {
      if (authState.event == AuthChangeEvent.signedIn) {
        _loadProfile(authState.session?.user);
      } else if (authState.event == AuthChangeEvent.signedOut) {
        state = const AuthState(isLoading: false);
      }
    });
  }

  Future<void> _loadProfile(User? user) async {
    if (user == null) {
      state = const AuthState(isLoading: false);
      return;
    }

    state = state.copyWith(user: user, isLoading: true);

    try {
      var profile = await SupabaseService.getProfile(user.id);

      // Create profile if it doesn't exist
      profile ??= await SupabaseService.createProfile(Profile(
        id: user.id,
        email: user.email,
        fullName: user.userMetadata?['full_name'] as String?,
      ));

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
      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (response.user != null) {
        await _loadProfile(response.user);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Sign up failed. Please check your email for verification.',
        );
        return false;
      }
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
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
      final response = await SupabaseService.signIn(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _loadProfile(response.user);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Sign in failed',
        );
        return false;
      }
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
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
      await SupabaseService.signOut();
      state = const AuthState(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Sign out failed: $e');
    }
  }

  /// Update profile
  Future<bool> updateProfile(Profile profile) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedProfile = await SupabaseService.updateProfile(profile);
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
final currentUserProvider = Provider<User?>((ref) {
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
