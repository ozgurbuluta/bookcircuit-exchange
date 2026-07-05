import 'firestore_helpers.dart';

/// Notification triggers (spec §8). The last two are opt-in.
enum NotificationType {
  requestReceived('request_received'),
  requestAccepted('request_accepted'),
  requestDeclined('request_declined'),
  tradeCancelled('trade_cancelled'),
  expiryWarning('expiry_warning'),
  expiredRefunded('expired_refunded'),
  markedSwapped('marked_swapped'),
  ratingReceived('rating_received'),
  newBookNearby('new_book_nearby'),
  journalEvent('journal_event'),
  unknown('unknown');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String? raw) {
    for (final t in NotificationType.values) {
      if (t.value == raw) return t;
    }
    return NotificationType.unknown;
  }

  /// Request notifications carry inline Accept / Decline / Chat (mock #1k).
  bool get hasInlineActions => this == NotificationType.requestReceived;
}

/// In-app notification (spec §3). `refId` points at the trade, rating, book,
/// or journal entry the notification is about, depending on [type].
class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String refId;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.refId,
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(Map<String, dynamic> data, String id) {
    return AppNotification(
      id: id,
      userId: data['userId'] as String? ?? '',
      type: NotificationType.fromString(data['type'] as String?),
      refId: data['refId'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: dateFromFirestore(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.value,
      'refId': refId,
      'read': read,
      'createdAt': createdAt,
    };
  }

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      refId: refId,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }
}
