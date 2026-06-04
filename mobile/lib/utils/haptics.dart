import 'package:flutter/services.dart';

/// Haptic feedback utilities for iOS-native feel
class Haptics {
  /// Light impact - for subtle interactions (toggles, selections)
  static void light() => HapticFeedback.lightImpact();

  /// Medium impact - for confirmations (button taps)
  static void medium() => HapticFeedback.mediumImpact();

  /// Heavy impact - for significant actions (send, delete)
  static void heavy() => HapticFeedback.heavyImpact();

  /// Selection tick - for scrolling/picking items
  static void selection() => HapticFeedback.selectionClick();

  /// Success feedback
  static void success() => HapticFeedback.mediumImpact();

  /// Error/warning feedback
  static void error() => HapticFeedback.heavyImpact();

  /// Vibrate - for notifications
  static void vibrate() => HapticFeedback.vibrate();
}
