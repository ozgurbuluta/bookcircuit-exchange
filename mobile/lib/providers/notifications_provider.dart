import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';

/// The user's notifications, newest first (mock #1k).
final notificationsProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final userId = ref.watch(currentUserProvider)?.uid;
  if (userId == null) return Stream.value(const []);

  return FirebaseService.db
      .collection('notifications')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc.data(), doc.id))
          .toList());
});

/// Unread count for the bell badge.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).maybeWhen(
        data: (items) => items.where((n) => !n.read).length,
        orElse: () => 0,
      );
});

/// Mark read / clear actions.
class NotificationActions {
  final dynamic db;

  NotificationActions(this.db);

  Future<void> markRead(String id) async {
    await db.collection('notifications').doc(id).update({'read': true});
  }

  Future<void> markAllRead(List<AppNotification> items) async {
    for (final item in items.where((n) => !n.read)) {
      await markRead(item.id);
    }
  }
}

final notificationActionsProvider = Provider<NotificationActions>(
    (ref) => NotificationActions(FirebaseService.db));
