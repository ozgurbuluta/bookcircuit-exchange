import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_service.dart';

/// Push notifications (decision D12): FCM token registration + tap routing.
/// The server side lives in functions/src/index.ts (pushFanout) — every
/// `notifications` document becomes a push.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _initialized = false;

  /// Where taps should land: '/trade-chat/:id', '/notifications', etc.
  /// Set by the router owner at startup.
  void Function(String route)? onOpenRoute;

  /// Call after sign-in: asks permission, stores the token on the user doc,
  /// keeps it fresh, and wires tap handling.
  Future<void> registerForUser(String userId) async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await messaging.getToken();
      if (token != null) {
        await FirebaseService.db.collection('users').doc(userId).update({
          'fcmToken': token,
        });
      }

      if (!_initialized) {
        _initialized = true;

        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          FirebaseService.db
              .collection('users')
              .doc(userId)
              .update({'fcmToken': newToken});
        });

        // Cold-start tap
        final initial = await messaging.getInitialMessage();
        if (initial != null) _route(initial);

        // Background tap
        FirebaseMessaging.onMessageOpenedApp.listen(_route);
      }
    } catch (e) {
      // Push is best-effort; never block sign-in on it.
      debugPrint('FCM registration failed: $e');
    }
  }

  void _route(RemoteMessage message) {
    final type = message.data['type'] as String?;
    final refId = message.data['refId'] as String?;
    if (onOpenRoute == null) return;

    switch (type) {
      case 'request_received':
      case 'request_accepted':
      case 'marked_swapped':
        if (refId != null && refId.isNotEmpty) {
          onOpenRoute!('/trade-chat/$refId');
          return;
        }
      case 'journal_event':
        onOpenRoute!('/journal');
        return;
    }
    onOpenRoute!('/notifications');
  }

  /// Clears the token on sign-out so a shared device stops receiving pushes.
  Future<void> unregister(String userId) async {
    try {
      await FirebaseService.db
          .collection('users')
          .doc(userId)
          .update({'fcmToken': null});
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {/* best effort */}
  }
}
