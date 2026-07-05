import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_turning_pages/models/models.dart';

void main() {
  group('AppNotification', () {
    test('all spec §8 trigger types exist', () {
      final specTypes = NotificationType.values
          .where((t) => t != NotificationType.unknown)
          .map((t) => t.value);
      expect(specTypes, [
        'request_received',
        'request_accepted',
        'request_declined',
        'trade_cancelled',
        'expiry_warning',
        'expired_refunded',
        'marked_swapped',
        'rating_received',
        'new_book_nearby',
        'journal_event',
      ]);
    });

    test('unknown type parses to a safe fallback rather than crashing', () {
      final n = AppNotification.fromFirestore({
        'userId': 'u1',
        'type': 'future_type_we_dont_know',
        'refId': 'x',
        'read': false,
      }, 'n1');
      expect(n.type, NotificationType.unknown);
    });

    test('request notifications carry inline actions (mock #1k)', () {
      expect(NotificationType.requestReceived.hasInlineActions, isTrue);
      expect(NotificationType.ratingReceived.hasInlineActions, isFalse);
    });

    test('firestore round trip, unread by default', () {
      final n = AppNotification(
        id: 'n1',
        userId: 'u1',
        type: NotificationType.requestReceived,
        refId: 't1',
        createdAt: DateTime.utc(2026, 7, 5),
      );
      expect(n.read, isFalse);

      final back = AppNotification.fromFirestore(n.toFirestore(), 'n1');
      expect(back.userId, 'u1');
      expect(back.type, NotificationType.requestReceived);
      expect(back.refId, 't1');
      expect(back.read, isFalse);
    });
  });
}
