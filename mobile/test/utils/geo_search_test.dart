import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_turning_pages/models/models.dart';
import 'package:turtle_turning_pages/utils/geo_search.dart';

Book _book(
  String id, {
  String owner = 'other',
  double? lat,
  double? lng,
  String? language = 'English',
  bool visible = true,
  BookStatus status = BookStatus.onShelf,
  int requestCount = 0,
  DateTime? createdAt,
  String title = 'Title',
}) {
  return Book(
    id: id,
    ownerId: owner,
    title: title,
    author: 'Author',
    condition: BookCondition.good,
    visible: visible,
    status: status,
    requestCount: requestCount,
    language: language,
    locationLat: lat,
    locationLng: lng,
    createdAt: createdAt ?? DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}

void main() {
  // Moda centroid
  const lat = 40.9822, lng = 29.0257;

  group('GeoSearch.nearby (spec §7)', () {
    test('keeps books within the radius, sorted nearest first', () {
      final books = [
        _book('far', lat: 41.05, lng: 29.03), // ~7.5 km
        _book('near', lat: 40.9830, lng: 29.0260), // ~0.1 km
        _book('mid', lat: 40.9890, lng: 29.0300), // ~0.8 km
      ];

      final results =
          GeoSearch.nearby(books: books, centerLat: lat, centerLng: lng);

      expect(results.map((b) => b.id), ['near', 'mid']);
      expect(results.first.distanceKm, lessThan(0.2));
    });

    test('default radius is 1 km', () {
      final books = [_book('at1.2km', lat: 40.9930, lng: 29.0257)];
      final results =
          GeoSearch.nearby(books: books, centerLat: lat, centerLng: lng);
      expect(results, isEmpty);
    });

    test('excludes own books (Build 8 behavior preserved)', () {
      final books = [
        _book('mine', owner: 'me', lat: lat, lng: lng),
        _book('theirs', lat: lat, lng: lng),
      ];
      final results = GeoSearch.nearby(
        books: books,
        centerLat: lat,
        centerLng: lng,
        excludeOwnerId: 'me',
      );
      expect(results.map((b) => b.id), ['theirs']);
    });

    test('excludes hidden and in-trade books (spec §4.6)', () {
      final books = [
        _book('hidden', visible: false, lat: lat, lng: lng),
        _book('locked', status: BookStatus.inTrade, lat: lat, lng: lng),
        _book('open', lat: lat, lng: lng),
      ];
      final results =
          GeoSearch.nearby(books: books, centerLat: lat, centerLng: lng);
      expect(results.map((b) => b.id), ['open']);
    });

    test('language filter and text query', () {
      final books = [
        _book('tr', language: 'Türkçe', lat: lat, lng: lng, title: 'Tutunamayanlar'),
        _book('en', language: 'English', lat: lat, lng: lng, title: 'Piranesi'),
      ];

      expect(
        GeoSearch.nearby(
                books: books,
                centerLat: lat,
                centerLng: lng,
                language: 'Türkçe')
            .map((b) => b.id),
        ['tr'],
      );
      expect(
        GeoSearch.nearby(
                books: books, centerLat: lat, centerLng: lng, query: 'pira')
            .map((b) => b.id),
        ['en'],
      );
    });
  });

  group('GeoSearch.languageCounts (mock #1b chips)', () {
    test('counts per language', () {
      final counts = GeoSearch.languageCounts([
        _book('1', language: 'Türkçe'),
        _book('2', language: 'Türkçe'),
        _book('3', language: 'English'),
        _book('4', language: null),
      ]);
      expect(counts, {'Türkçe': 2, 'English': 1});
    });
  });

  group('GeoSearch.mostLoved (spec §7)', () {
    test('sorts by request count, ignores unrequested books', () {
      final loved = GeoSearch.mostLoved([
        _book('quiet'),
        _book('popular', requestCount: 12),
        _book('liked', requestCount: 7),
      ]);
      expect(loved.map((b) => b.id), ['popular', 'liked']);
    });
  });

  group('GeoSearch.newNearby (spec §7)', () {
    test('latest first, limited', () {
      final results = GeoSearch.newNearby([
        _book('old', createdAt: DateTime(2026, 1, 1)),
        _book('new', createdAt: DateTime(2026, 7, 1)),
        _book('mid', createdAt: DateTime(2026, 4, 1)),
      ], limit: 2);
      expect(results.map((b) => b.id), ['new', 'mid']);
    });
  });
}
