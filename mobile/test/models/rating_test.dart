import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_turning_pages/models/models.dart';

void main() {
  group('Rating', () {
    Rating makeRating({int stars = 5, Set<RatingTag>? tags, String? note}) =>
        Rating(
          id: 'r1',
          tradeId: 't1',
          fromId: 'u1',
          toId: 'u2',
          stars: stars,
          tags: tags ?? {RatingTag.onTime, RatingTag.greatPick},
          note: note,
          createdAt: DateTime.utc(2026, 7, 5),
        );

    test('spec tags exist with wire values', () {
      expect(RatingTag.values.map((t) => t.value), [
        'on_time',
        'as_described',
        'great_pick',
      ]);
    });

    test('tag display labels are sentence case', () {
      expect(RatingTag.onTime.label, 'On time');
      expect(RatingTag.asDescribed.label, 'As described');
      expect(RatingTag.greatPick.label, 'Great pick');
    });

    test('validation: stars 1-5, note max 140 chars', () {
      expect(makeRating(stars: 0).isValid, isFalse);
      expect(makeRating(stars: 6).isValid, isFalse);
      expect(makeRating(stars: 1).isValid, isTrue);
      expect(makeRating(stars: 5, note: 'x' * 140).isValid, isTrue);
      expect(makeRating(stars: 5, note: 'x' * 141).isValid, isFalse);
    });

    test('firestore round trip', () {
      final back = Rating.fromFirestore(makeRating().toFirestore(), 'r1');
      expect(back.tradeId, 't1');
      expect(back.fromId, 'u1');
      expect(back.toId, 'u2');
      expect(back.stars, 5);
      expect(back.tags, {RatingTag.onTime, RatingTag.greatPick});
    });
  });
}
