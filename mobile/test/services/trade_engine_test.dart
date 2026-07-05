import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_turning_pages/models/models.dart';
import 'package:turtle_turning_pages/services/trade_engine.dart';

/// Transition-matrix tests for the points economy (spec §4, decision D7).
/// Every rule that moves points or locks books is covered here.
void main() {
  late FakeFirebaseFirestore db;
  late TradeEngine engine;

  const requester = 'requester';
  const owner = 'owner';
  const third = 'third';

  setUp(() async {
    db = FakeFirebaseFirestore();
    engine = TradeEngine(db);

    for (final entry in {
      requester: 200,
      owner: 200,
      third: 200,
    }.entries) {
      await db.collection('users').doc(entry.key).set({
        'fullName': entry.key,
        'points': entry.value,
        'pointsGranted': true,
        'tradeCount': 0,
        'ratingAvg': 0,
        'ratingCount': 0,
      });
    }

    await db.collection('books').doc('book1').set({
      'ownerId': owner,
      'title': 'Piranesi',
      'author': 'Susanna Clarke',
      'condition': 'very_good',
      'visible': true,
      'status': 'on_shelf',
      'source': 'manual',
      'requestCount': 0,
    });

    await db.collection('books').doc('offered1').set({
      'ownerId': requester,
      'title': 'Norwegian Wood',
      'author': 'Haruki Murakami',
      'condition': 'good',
      'visible': true,
      'status': 'on_shelf',
      'source': 'manual',
      'requestCount': 0,
    });
  });

  Future<int> pointsOf(String uid) async =>
      (await db.collection('users').doc(uid).get()).data()!['points'] as int;

  Future<Map<String, dynamic>> tradeDoc(String id) async =>
      (await db.collection('trades').doc(id).get()).data()!;

  Future<Map<String, dynamic>> bookDoc(String id) async =>
      (await db.collection('books').doc(id).get()).data()!;

  group('createRequest — points offer (spec §4.3)', () {
    test('escrows 50 pts immediately and bumps requestCount', () async {
      final trade = await engine.createRequest(
        requesterId: requester,
        bookId: 'book1',
        offer: TradeOffer.points50,
        note: 'Been hunting for this.',
      );

      expect(await pointsOf(requester), 150);
      final doc = await tradeDoc(trade.id);
      expect(doc['status'], 'requested');
      expect(doc['escrowed'], true);
      expect((await bookDoc('book1'))['requestCount'], 1);
      // Book stays on the shelf until accept (spec §4.5)
      expect((await bookDoc('book1'))['status'], 'on_shelf');
    });

    test('rejects when balance is under 50 (spec §4.10)', () async {
      await db.collection('users').doc(requester).update({'points': 40});

      expect(
        () => engine.createRequest(
          requesterId: requester,
          bookId: 'book1',
          offer: TradeOffer.points50,
        ),
        throwsA(isA<TradeEngineException>().having(
            (e) => e.code, 'code', TradeErrorCode.insufficientPoints)),
      );
      expect(await pointsOf(requester), 40);
    });

    test('rejects requesting your own book', () async {
      expect(
        () => engine.createRequest(
          requesterId: owner,
          bookId: 'book1',
          offer: TradeOffer.points50,
        ),
        throwsA(isA<TradeEngineException>()
            .having((e) => e.code, 'code', TradeErrorCode.ownBook)),
      );
    });

    test('rejects a second active request from the same requester (spec §4.5)',
        () async {
      await engine.createRequest(
          requesterId: requester, bookId: 'book1', offer: TradeOffer.points50);

      expect(
        () => engine.createRequest(
            requesterId: requester,
            bookId: 'book1',
            offer: TradeOffer.points50),
        throwsA(isA<TradeEngineException>().having(
            (e) => e.code, 'code', TradeErrorCode.duplicateRequest)),
      );
      expect(await pointsOf(requester), 150); // only one escrow
    });

    test('rejects a book that is not requestable', () async {
      await db.collection('books').doc('book1').update({'visible': false});

      expect(
        () => engine.createRequest(
            requesterId: requester,
            bookId: 'book1',
            offer: TradeOffer.points50),
        throwsA(isA<TradeEngineException>().having(
            (e) => e.code, 'code', TradeErrorCode.bookNotRequestable)),
      );
    });

    test('allows multiple pending requests from different neighbors', () async {
      await engine.createRequest(
          requesterId: requester, bookId: 'book1', offer: TradeOffer.points50);
      await engine.createRequest(
          requesterId: third, bookId: 'book1', offer: TradeOffer.points50);

      expect((await bookDoc('book1'))['requestCount'], 2);
    });
  });

  group('createRequest — book offer (spec §4.4, D9)', () {
    test('no points move and the offered book stays unlocked', () async {
      final trade = await engine.createRequest(
        requesterId: requester,
        bookId: 'book1',
        offer: TradeOffer.book,
        offeredBookId: 'offered1',
      );

      expect(await pointsOf(requester), 200);
      expect((await tradeDoc(trade.id))['escrowed'], false);
      // Lock only at accept (D9 / spec §12.3)
      expect((await bookDoc('offered1'))['status'], 'on_shelf');
    });

    test('rejects offering a book you do not own or that is locked', () async {
      await expectLater(
        () => engine.createRequest(
          requesterId: third,
          bookId: 'book1',
          offer: TradeOffer.book,
          offeredBookId: 'offered1', // requester's book, not third's
        ),
        throwsA(isA<TradeEngineException>().having(
            (e) => e.code, 'code', TradeErrorCode.invalidOfferedBook)),
      );
    });
  });

  group('accept (spec §4.5-4.6)', () {
    test('locks the book, auto-declines competitors with refunds', () async {
      final winner = await engine.createRequest(
          requesterId: requester, bookId: 'book1', offer: TradeOffer.points50);
      final loser = await engine.createRequest(
          requesterId: third, bookId: 'book1', offer: TradeOffer.points50);
      expect(await pointsOf(third), 150);

      await engine.accept(tradeId: winner.id, actorId: owner);

      expect((await tradeDoc(winner.id))['status'], 'accepted');
      expect((await bookDoc('book1'))['status'], 'in_trade');
      // Loser auto-declined and refunded (spec §4.5)
      expect((await tradeDoc(loser.id))['status'], 'declined');
      expect(await pointsOf(third), 200);
    });

    test('book-for-book: offered book locks at accept (D9)', () async {
      final trade = await engine.createRequest(
        requesterId: requester,
        bookId: 'book1',
        offer: TradeOffer.book,
        offeredBookId: 'offered1',
      );

      await engine.accept(tradeId: trade.id, actorId: owner);

      expect((await bookDoc('book1'))['status'], 'in_trade');
      expect((await bookDoc('offered1'))['status'], 'in_trade');
    });

    test('only the owner can accept', () async {
      final trade = await engine.createRequest(
          requesterId: requester, bookId: 'book1', offer: TradeOffer.points50);

      expect(
        () => engine.accept(tradeId: trade.id, actorId: requester),
        throwsA(isA<TradeEngineException>()
            .having((e) => e.code, 'code', TradeErrorCode.notAllowed)),
      );
    });

    test('cannot accept a trade that is not requested', () async {
      final trade = await engine.createRequest(
          requesterId: requester, bookId: 'book1', offer: TradeOffer.points50);
      await engine.accept(tradeId: trade.id, actorId: owner);

      expect(
        () => engine.accept(tradeId: trade.id, actorId: owner),
        throwsA(isA<TradeEngineException>()
            .having((e) => e.code, 'code', TradeErrorCode.invalidStatus)),
      );
    });
  });

  group('decline and cancel (spec §4.8)', () {
    test('decline refunds escrow in full', () async {
      final trade = await engine.createRequest(
          requesterId: requester, bookId: 'book1', offer: TradeOffer.points50);

      await engine.decline(tradeId: trade.id, actorId: owner);

      expect((await tradeDoc(trade.id))['status'], 'declined');
      expect(await pointsOf(requester), 200);
      expect((await bookDoc('book1'))['requestCount'], 0);
    });

    test('cancel after accept unlocks both books and refunds', () async {
      final trade = await engine.createRequest(
        requesterId: requester,
        bookId: 'book1',
        offer: TradeOffer.book,
        offeredBookId: 'offered1',
      );
      await engine.accept(tradeId: trade.id, actorId: owner);

      await engine.cancel(tradeId: trade.id, actorId: requester);

      expect((await tradeDoc(trade.id))['status'], 'cancelled');
      expect((await bookDoc('book1'))['status'], 'on_shelf');
      expect((await bookDoc('offered1'))['status'], 'on_shelf');
    });

    test('either party may cancel; strangers may not', () async {
      final trade = await engine.createRequest(
          requesterId: requester, bookId: 'book1', offer: TradeOffer.points50);

      expect(
        () => engine.cancel(tradeId: trade.id, actorId: third),
        throwsA(isA<TradeEngineException>()
            .having((e) => e.code, 'code', TradeErrorCode.notAllowed)),
      );

      await engine.cancel(tradeId: trade.id, actorId: owner);
      expect(await pointsOf(requester), 200);
    });

    test('terminal trades are frozen', () async {
      final trade = await engine.createRequest(
          requesterId: requester, bookId: 'book1', offer: TradeOffer.points50);
      await engine.cancel(tradeId: trade.id, actorId: requester);

      expect(
        () => engine.cancel(tradeId: trade.id, actorId: requester),
        throwsA(isA<TradeEngineException>()
            .having((e) => e.code, 'code', TradeErrorCode.invalidStatus)),
      );
      expect(await pointsOf(requester), 200); // no double refund
    });
  });

  group('confirmSwap — two-sided (decision D7)', () {
    Future<Trade> acceptedPointsTrade() async {
      final trade = await engine.createRequest(
          requesterId: requester, bookId: 'book1', offer: TradeOffer.points50);
      await engine.accept(tradeId: trade.id, actorId: owner);
      return trade;
    }

    test('first confirm records but does not complete', () async {
      final trade = await acceptedPointsTrade();

      final result =
          await engine.confirmSwap(tradeId: trade.id, actorId: owner);

      expect(result.completed, isFalse);
      final doc = await tradeDoc(trade.id);
      expect(doc['status'], 'accepted');
      expect(doc['swapConfirmedBy'], ['owner']);
      expect(doc['firstConfirmAt'], isNotNull);
      // No points moved yet
      expect(await pointsOf(owner), 200);
    });

    test('double-confirm by the same person is rejected', () async {
      final trade = await acceptedPointsTrade();
      await engine.confirmSwap(tradeId: trade.id, actorId: owner);

      expect(
        () => engine.confirmSwap(tradeId: trade.id, actorId: owner),
        throwsA(isA<TradeEngineException>().having(
            (e) => e.code, 'code', TradeErrorCode.alreadyConfirmed)),
      );
    });

    test('second confirm completes: points release + ownership transfer',
        () async {
      final trade = await acceptedPointsTrade();
      await engine.confirmSwap(tradeId: trade.id, actorId: owner);

      final result =
          await engine.confirmSwap(tradeId: trade.id, actorId: requester);

      expect(result.completed, isTrue);
      final doc = await tradeDoc(trade.id);
      expect(doc['status'], 'swapped');
      expect(doc['swappedAt'], isNotNull);

      // Owner receives the 50 escrowed points (spec §4.7)
      expect(await pointsOf(owner), 250);
      expect(await pointsOf(requester), 150);

      // Book moves to the requester's shelf
      final book = await bookDoc('book1');
      expect(book['ownerId'], requester);
      expect(book['status'], 'on_shelf');

      // Trade counters increment for both
      final requesterDoc =
          (await db.collection('users').doc(requester).get()).data()!;
      final ownerDoc = (await db.collection('users').doc(owner).get()).data()!;
      expect(requesterDoc['tradeCount'], 1);
      expect(ownerDoc['tradeCount'], 1);
    });

    test('book-for-book completion transfers both, no points move', () async {
      final trade = await engine.createRequest(
        requesterId: requester,
        bookId: 'book1',
        offer: TradeOffer.book,
        offeredBookId: 'offered1',
      );
      await engine.accept(tradeId: trade.id, actorId: owner);
      await engine.confirmSwap(tradeId: trade.id, actorId: owner);
      await engine.confirmSwap(tradeId: trade.id, actorId: requester);

      expect(await pointsOf(owner), 200);
      expect(await pointsOf(requester), 200);
      expect((await bookDoc('book1'))['ownerId'], requester);
      expect((await bookDoc('offered1'))['ownerId'], owner);
      expect((await bookDoc('book1'))['status'], 'on_shelf');
      expect((await bookDoc('offered1'))['status'], 'on_shelf');
    });

    test('confirm requires accepted status', () async {
      final trade = await engine.createRequest(
          requesterId: requester, bookId: 'book1', offer: TradeOffer.points50);

      expect(
        () => engine.confirmSwap(tradeId: trade.id, actorId: owner),
        throwsA(isA<TradeEngineException>()
            .having((e) => e.code, 'code', TradeErrorCode.invalidStatus)),
      );
    });
  });

  group('expiry (spec §4.9)', () {
    test('expireIfStale refunds and closes 7-day-old requests', () async {
      final trade = await engine.createRequest(
          requesterId: requester, bookId: 'book1', offer: TradeOffer.points50);
      // Backdate the request
      await db.collection('trades').doc(trade.id).update({
        'requestedAt': DateTime.now().subtract(const Duration(days: 8)),
      });

      final expired = await engine.expireIfStale(trade.id);

      expect(expired, isTrue);
      expect((await tradeDoc(trade.id))['status'], 'expired');
      expect(await pointsOf(requester), 200);
    });

    test('fresh requests are untouched and expiry is idempotent', () async {
      final trade = await engine.createRequest(
          requesterId: requester, bookId: 'book1', offer: TradeOffer.points50);

      expect(await engine.expireIfStale(trade.id), isFalse);

      await db.collection('trades').doc(trade.id).update({
        'requestedAt': DateTime.now().subtract(const Duration(days: 8)),
      });
      expect(await engine.expireIfStale(trade.id), isTrue);
      expect(await engine.expireIfStale(trade.id), isFalse); // already closed
      expect(await pointsOf(requester), 200); // single refund
    });
  });

  group('side-channel records', () {
    test('transitions write system messages into the trade thread', () async {
      final trade = await engine.createRequest(
          requesterId: requester, bookId: 'book1', offer: TradeOffer.points50);
      await engine.accept(tradeId: trade.id, actorId: owner);

      final messages = await db
          .collection('trades')
          .doc(trade.id)
          .collection('messages')
          .get();
      final types =
          messages.docs.map((d) => d.data()['type']).toSet();
      expect(messages.docs.length, greaterThanOrEqualTo(2));
      expect(types, {'system'});
    });

    test('transitions notify the right people', () async {
      final trade = await engine.createRequest(
          requesterId: requester, bookId: 'book1', offer: TradeOffer.points50);
      await engine.accept(tradeId: trade.id, actorId: owner);

      final notifications = await db.collection('notifications').get();
      final byType = {
        for (final d in notifications.docs)
          d.data()['type']: d.data()['userId'],
      };
      expect(byType['request_received'], owner);
      expect(byType['request_accepted'], requester);
    });
  });
}
