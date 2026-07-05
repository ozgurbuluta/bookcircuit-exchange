import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_turning_pages/services/neighborhood_service.dart';

void main() {
  group('NeighborhoodService.composeAreaLabel', () {
    test('joins neighborhood and district ("Moda, Kadıköy")', () {
      expect(
        NeighborhoodService.composeAreaLabel(
            subLocality: 'Moda', locality: 'Kadıköy'),
        'Moda, Kadıköy',
      );
    });

    test('falls back to locality alone', () {
      expect(
        NeighborhoodService.composeAreaLabel(subLocality: '', locality: 'Kadıköy'),
        'Kadıköy',
      );
      expect(
        NeighborhoodService.composeAreaLabel(
            subLocality: null, locality: 'Kadıköy'),
        'Kadıköy',
      );
    });

    test('falls back to admin area when locality is missing', () {
      expect(
        NeighborhoodService.composeAreaLabel(
            subLocality: null, locality: null, adminArea: 'İstanbul'),
        'İstanbul',
      );
    });

    test('returns null when nothing usable', () {
      expect(
        NeighborhoodService.composeAreaLabel(subLocality: '', locality: ''),
        isNull,
      );
    });

    test('never leaks street-level detail', () {
      final label = NeighborhoodService.composeAreaLabel(
        subLocality: 'Moda',
        locality: 'Kadıköy',
      );
      // Label is built exclusively from area parts — no street/number inputs exist.
      expect(label, isNot(contains(RegExp(r'\d'))));
    });
  });

  group('NeighborhoodService.isPlausiblePostalCode', () {
    test('accepts common formats', () {
      expect(NeighborhoodService.isPlausiblePostalCode('34710'), isTrue); // TR
      expect(NeighborhoodService.isPlausiblePostalCode('10115'), isTrue); // DE
      expect(NeighborhoodService.isPlausiblePostalCode('75004'), isTrue); // FR
      expect(NeighborhoodService.isPlausiblePostalCode('EC1A 1BB'), isTrue); // UK
      expect(NeighborhoodService.isPlausiblePostalCode('1012 AB'), isTrue); // NL
    });

    test('rejects junk', () {
      expect(NeighborhoodService.isPlausiblePostalCode(''), isFalse);
      expect(NeighborhoodService.isPlausiblePostalCode('1'), isFalse);
      expect(NeighborhoodService.isPlausiblePostalCode('hello world 42 street'),
          isFalse);
    });
  });

  group('NeighborhoodService.preselectLanguages (spec §5 device locale)', () {
    test('maps known locales to their display languages', () {
      expect(NeighborhoodService.preselectLanguages(const Locale('tr')),
          ['Türkçe']);
      expect(NeighborhoodService.preselectLanguages(const Locale('de')),
          ['Deutsch']);
      expect(NeighborhoodService.preselectLanguages(const Locale('fr')),
          ['Français']);
      expect(NeighborhoodService.preselectLanguages(const Locale('en', 'US')),
          ['English']);
    });

    test('unknown locales fall back to English', () {
      expect(NeighborhoodService.preselectLanguages(const Locale('ja')),
          ['English']);
    });
  });
}
