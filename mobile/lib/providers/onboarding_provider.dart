import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_completed') ?? false;
});

final onboardingNotifierProvider =
    StateNotifierProvider<OnboardingNotifier, AsyncValue<bool>>((ref) {
  return OnboardingNotifier();
});

class OnboardingNotifier extends StateNotifier<AsyncValue<bool>> {
  OnboardingNotifier() : super(const AsyncValue.loading()) {
    _loadOnboardingStatus();
  }

  Future<void> _loadOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool('onboarding_completed') ?? false;
      state = AsyncValue.data(completed);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    state = const AsyncValue.data(true);
  }
}

/// Welcome-gift banner (mock #3f): shows until the first book is added OR
/// the user dismisses it (spec §5). Dismissal persists across launches.
final welcomeBannerDismissedProvider =
    StateNotifierProvider<WelcomeBannerNotifier, AsyncValue<bool>>((ref) {
  return WelcomeBannerNotifier();
});

class WelcomeBannerNotifier extends StateNotifier<AsyncValue<bool>> {
  WelcomeBannerNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AsyncValue.data(prefs.getBool('welcome_banner_dismissed') ?? false);
  }

  Future<void> dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('welcome_banner_dismissed', true);
    state = const AsyncValue.data(true);
  }
}
