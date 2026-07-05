import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_turning_pages/utils/geohash.dart';

void main() {
  group('Geohash.encode', () {
    test('encodes known reference points', () {
      // Reference values from geohash.org
      expect(Geohash.encode(57.64911, 10.40744, precision: 11), 'u4pruydqqvj');
      expect(Geohash.encode(40.9822, 29.0257, precision: 7), 'sxk9hkx');
      expect(Geohash.encode(0, 0, precision: 5), 's0000');
    });

    test('neighbors share prefixes at coarser precision', () {
      final moda = Geohash.encode(40.9822, 29.0257, precision: 5);
      final fenerbahce = Geohash.encode(40.9689, 29.0365, precision: 5);
      expect(moda.substring(0, 3), fenerbahce.substring(0, 3));
    });

    test('default precision is 9 (≈5m cell, plenty for postal centroids)', () {
      expect(Geohash.encode(40.9822, 29.0257).length, 9);
    });
  });

  group('Geohash.neighborsOf / coverRadius', () {
    test('returns the cell and its 8 neighbors', () {
      final cells = Geohash.neighborsOf('sxk9g');
      expect(cells.length, 9);
      expect(cells, contains('sxk9g'));
      // All cells are the same precision
      expect(cells.every((c) => c.length == 5), isTrue);
    });

    test('precisionForRadiusKm picks sensible cell sizes', () {
      // ~1 km radius → precision 5 cells (±2.4 km) are the right cover
      expect(Geohash.precisionForRadiusKm(1), 5);
      expect(Geohash.precisionForRadiusKm(0.5), 6);
      expect(Geohash.precisionForRadiusKm(20), 4);
    });
  });
}
