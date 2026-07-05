import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_turning_pages/models/models.dart';

void main() {
  final now = DateTime.utc(2026, 7, 5, 12);

  Trade makeTrade({
    TradeOffer offer = TradeOffer.points50,
    TradeStatus status = TradeStatus.requested,
    List<String> swapConfirmedBy = const [],
    String? offeredBookId,
  }) =>
      Trade(
        id: 't1',
        bookId: 'b1',
        requesterId: 'requester',
        ownerId: 'owner',
        offer: offer,
        offeredBookId: offeredBookId,
        note: 'Been hunting for this all spring.',
        status: status,
        escrowed: offer == TradeOffer.points50,
        swapConfirmedBy: swapConfirmedBy,
        requestedAt: now,
      );

  group('TradeStatus', () {
    test('has exactly the 6 spec values', () {
      expect(TradeStatus.values.map((s) => s.value), [
        'requested',
        'accepted',
        'swapped',
        'cancelled',
        'declined',
        'expired',
      ]);
    });

    test('terminal vs active statuses', () {
      expect(TradeStatus.requested.isTerminal, isFalse);
      expect(TradeStatus.accepted.isTerminal, isFalse);
      expect(TradeStatus.swapped.isTerminal, isTrue);
      expect(TradeStatus.cancelled.isTerminal, isTrue);
      expect(TradeStatus.declined.isTerminal, isTrue);
      expect(TradeStatus.expired.isTerminal, isTrue);
    });
  });

  group('TradeOffer', () {
    test('spec values', () {
      expect(TradeOffer.points50.value, 'points_50');
      expect(TradeOffer.book.value, 'book');
    });

    test('flat price constant is 50 (spec §4.1)', () {
      expect(Trade.pointsPrice, 50);
    });
  });

  group('Trade model', () {
    test('firestore round trip preserves all fields', () {
      final trade = makeTrade(
        offer: TradeOffer.book,
        offeredBookId: 'b9',
        status: TradeStatus.accepted,
        swapConfirmedBy: ['requester'],
      );
      final back = Trade.fromFirestore(trade.toFirestore(), 't1');

      expect(back.bookId, 'b1');
      expect(back.requesterId, 'requester');
      expect(back.ownerId, 'owner');
      expect(back.offer, TradeOffer.book);
      expect(back.offeredBookId, 'b9');
      expect(back.status, TradeStatus.accepted);
      expect(back.swapConfirmedBy, ['requester']);
      expect(back.note, 'Been hunting for this all spring.');
    });

    test('participants and counterparty resolution', () {
      final trade = makeTrade();
      expect(trade.isParticipant('requester'), isTrue);
      expect(trade.isParticipant('owner'), isTrue);
      expect(trade.isParticipant('stranger'), isFalse);
      expect(trade.otherPartyId('requester'), 'owner');
      expect(trade.otherPartyId('owner'), 'requester');
    });

    group('two-sided swap confirmation (D7)', () {
      test('no confirmations initially', () {
        final trade = makeTrade(status: TradeStatus.accepted);
        expect(trade.hasConfirmedSwap('requester'), isFalse);
        expect(trade.bothConfirmedSwap, isFalse);
        expect(trade.awaitingConfirmationFrom, isNull);
      });

      test('half-confirmed exposes who is awaited', () {
        final trade = makeTrade(
          status: TradeStatus.accepted,
          swapConfirmedBy: ['owner'],
        );
        expect(trade.hasConfirmedSwap('owner'), isTrue);
        expect(trade.hasConfirmedSwap('requester'), isFalse);
        expect(trade.bothConfirmedSwap, isFalse);
        expect(trade.awaitingConfirmationFrom, 'requester');
      });

      test('both confirmed completes the pair', () {
        final trade = makeTrade(
          status: TradeStatus.accepted,
          swapConfirmedBy: ['owner', 'requester'],
        );
        expect(trade.bothConfirmedSwap, isTrue);
        expect(trade.awaitingConfirmationFrom, isNull);
      });
    });

    group('expiry (spec §4.9)', () {
      test('requested trade expires after 7 days', () {
        final trade = makeTrade();
        expect(trade.isExpiredAt(now.add(const Duration(days: 6))), isFalse);
        expect(
          trade.isExpiredAt(now.add(const Duration(days: 7, minutes: 1))),
          isTrue,
        );
      });

      test('accepted trades never expire', () {
        final trade = makeTrade(status: TradeStatus.accepted);
        expect(
          trade.isExpiredAt(now.add(const Duration(days: 30))),
          isFalse,
        );
      });
    });

    test('book offer requires offeredBookId to be valid', () {
      expect(makeTrade(offer: TradeOffer.points50).hasValidOffer, isTrue);
      expect(makeTrade(offer: TradeOffer.book).hasValidOffer, isFalse);
      expect(
        makeTrade(offer: TradeOffer.book, offeredBookId: 'b9').hasValidOffer,
        isTrue,
      );
    });
  });
}
