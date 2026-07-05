import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_turning_pages/models/models.dart';
import 'package:turtle_turning_pages/services/rating_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late RatingService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = RatingService(db);

    await db.collection('users').doc('owner').set({
      'fullName': 'Mert',
      'ratingAvg': 0,
      'ratingCount': 0,
    });
    await db.collection('trades').doc('t1').set({
      'bookId': 'b1',
      'requesterId': 'requester',
      'ownerId': 'owner',
      'status': 'swapped',
    });
  });

  group('RatingService.submit (spec §3, mock #3g)', () {
    test('stores the rating under {tradeId}_{fromId} and updates aggregates',
        () async {
      await service.submit(
        tradeId: 't1',
        fromId: 'requester',
        toId: 'owner',
        stars: 5,
        tags: {RatingTag.onTime, RatingTag.greatPick},
        note: 'Lovely swap at the pier.',
      );

      final doc = await db.collection('ratings').doc('t1_requester').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['stars'], 5);
      expect(doc.data()!['tags'], containsAll(['on_time', 'great_pick']));

      final owner = await db.collection('users').doc('owner').get();
      expect(owner.data()!['ratingAvg'], 5.0);
      expect(owner.data()!['ratingCount'], 1);
    });

    test('running average across multiple ratings', () async {
      await db.collection('trades').doc('t2').set({
        'requesterId': 'third',
        'ownerId': 'owner',
        'status': 'swapped',
      });

      await service.submit(
          tradeId: 't1', fromId: 'requester', toId: 'owner', stars: 5);
      await service.submit(
          tradeId: 't2', fromId: 'third', toId: 'owner', stars: 4);

      final owner = await db.collection('users').doc('owner').get();
      expect(owner.data()!['ratingAvg'], closeTo(4.5, 0.001));
      expect(owner.data()!['ratingCount'], 2);
    });

    test('one rating per direction — resubmit is rejected quietly', () async {
      await service.submit(
          tradeId: 't1', fromId: 'requester', toId: 'owner', stars: 5);
      final again = await service.submit(
          tradeId: 't1', fromId: 'requester', toId: 'owner', stars: 1);

      expect(again, isFalse);
      final owner = await db.collection('users').doc('owner').get();
      expect(owner.data()!['ratingAvg'], 5.0);
      expect(owner.data()!['ratingCount'], 1);
    });

    test('rejects invalid stars and over-long notes', () async {
      expect(
        () => service.submit(
            tradeId: 't1', fromId: 'requester', toId: 'owner', stars: 0),
        throwsArgumentError,
      );
      expect(
        () => service.submit(
            tradeId: 't1',
            fromId: 'requester',
            toId: 'owner',
            stars: 5,
            note: 'x' * 141),
        throwsArgumentError,
      );
    });

    test('hasRated reflects submissions', () async {
      expect(await service.hasRated(tradeId: 't1', fromId: 'requester'),
          isFalse);
      await service.submit(
          tradeId: 't1', fromId: 'requester', toId: 'owner', stars: 4);
      expect(
          await service.hasRated(tradeId: 't1', fromId: 'requester'), isTrue);
    });
  });
}
