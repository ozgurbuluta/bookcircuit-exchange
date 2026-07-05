import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_turning_pages/models/models.dart';

void main() {
  group('BookCondition', () {
    test('has exactly the 4 spec values', () {
      expect(BookCondition.values.map((c) => c.value), [
        'like_new',
        'very_good',
        'good',
        'well_read',
      ]);
    });

    test('display names are sentence case (spec §10)', () {
      expect(BookCondition.likeNew.displayName, 'Like new');
      expect(BookCondition.veryGood.displayName, 'Very good');
      expect(BookCondition.good.displayName, 'Good');
      expect(BookCondition.wellRead.displayName, 'Well read');
    });

    test('parses spec values', () {
      expect(BookCondition.fromString('like_new'), BookCondition.likeNew);
      expect(BookCondition.fromString('well_read'), BookCondition.wellRead);
    });

    test('maps legacy 6-value conditions (plan §3 migration table)', () {
      expect(BookCondition.fromString('New'), BookCondition.likeNew);
      expect(BookCondition.fromString('Like New'), BookCondition.likeNew);
      expect(BookCondition.fromString('Very Good'), BookCondition.veryGood);
      expect(BookCondition.fromString('Good'), BookCondition.good);
      expect(BookCondition.fromString('Acceptable'), BookCondition.good);
      expect(BookCondition.fromString('Poor'), BookCondition.wellRead);
    });

    test('unknown falls back to good', () {
      expect(BookCondition.fromString('???'), BookCondition.good);
    });
  });

  group('BookStatus', () {
    test('has exactly the 3 spec values', () {
      expect(BookStatus.values.map((s) => s.value), [
        'on_shelf',
        'in_trade',
        'traded_away',
      ]);
    });

    test('maps legacy statuses', () {
      expect(BookStatus.fromString('available'), BookStatus.onShelf);
      expect(BookStatus.fromString('requested'), BookStatus.inTrade);
      expect(BookStatus.fromString('trading'), BookStatus.inTrade);
      expect(BookStatus.fromString('completed'), BookStatus.tradedAway);
      expect(BookStatus.fromString('on_shelf'), BookStatus.onShelf);
    });
  });

  group('Book model', () {
    final now = DateTime.utc(2026, 7, 5, 12);

    Book makeBook() => Book(
          id: 'b1',
          ownerId: 'u1',
          title: 'Piranesi',
          author: 'Susanna Clarke',
          condition: BookCondition.veryGood,
          language: 'English',
          year: 2020,
          pages: 245,
          publisher: 'Bloomsbury',
          isbn: '9781635575637',
          visible: true,
          status: BookStatus.onShelf,
          source: BookSource.scan,
          postalCode: '34710',
          createdAt: now,
          updatedAt: now,
        );

    test('defaults: visible on, on_shelf, manual source, zero requests', () {
      final book = Book(
        id: 'b2',
        ownerId: 'u1',
        title: 'X',
        author: 'Y',
        condition: BookCondition.good,
        createdAt: now,
        updatedAt: now,
      );
      expect(book.visible, isTrue);
      expect(book.status, BookStatus.onShelf);
      expect(book.source, BookSource.manual);
      expect(book.requestCount, 0);
    });

    test('firestore round trip preserves all spec fields', () {
      final book = makeBook();
      final map = book.toFirestore();
      final back = Book.fromFirestore(map, 'b1');

      expect(back.ownerId, 'u1');
      expect(back.title, 'Piranesi');
      expect(back.condition, BookCondition.veryGood);
      expect(back.language, 'English');
      expect(back.year, 2020);
      expect(back.visible, isTrue);
      expect(back.status, BookStatus.onShelf);
      expect(back.source, BookSource.scan);
      expect(back.postalCode, '34710');
    });

    test('is requestable only when visible and on shelf', () {
      final book = makeBook();
      expect(book.isRequestable, isTrue);
      expect(book.copyWith(status: BookStatus.inTrade).isRequestable, isFalse);
      expect(book.copyWith(visible: false).isRequestable, isFalse);
    });

    test('coverColorKey is stable and from the 7-colorway palette', () {
      final book = makeBook();
      const palette = [
        'honey', 'plum', 'slate', 'deepGreen', 'forest', 'terracotta', 'brick'
      ];
      expect(palette, contains(book.coverColorKey));
      expect(book.coverColorKey, makeBook().coverColorKey);
    });

    test('legacy userId alias still resolves to ownerId', () {
      // ignore: deprecated_member_use_from_same_package
      expect(makeBook().userId, 'u1');
    });
  });
}
