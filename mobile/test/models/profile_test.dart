import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_turning_pages/models/models.dart';

void main() {
  group('Profile (spec User)', () {
    Profile makeProfile() => Profile(
          id: 'u1',
          email: 'ayse@example.com',
          fullName: 'Ayşe Demir',
          postalCode: '34710',
          areaLabel: 'Moda, Kadıköy',
          languages: const ['Turkish', 'English'],
          points: 200,
          pointsGranted: true,
          ratingAvg: 4.5,
          ratingCount: 8,
          tradeCount: 12,
          createdAt: DateTime.utc(2026, 1, 1),
        );

    test('defaults for a bare profile: no points until granted', () {
      final p = Profile(id: 'u2');
      expect(p.points, 0);
      expect(p.pointsGranted, isFalse);
      expect(p.languages, isEmpty);
      expect(p.ratingAvg, 0);
      expect(p.ratingCount, 0);
      expect(p.tradeCount, 0);
    });

    test('avatarInitials derives from name', () {
      expect(makeProfile().avatarInitials, 'AD');
      expect(Profile(id: 'x', fullName: 'Piri').avatarInitials, 'P');
      expect(Profile(id: 'x').avatarInitials, 'U');
    });

    test('onboarding is complete only with postal code and a language', () {
      expect(makeProfile().hasCompletedSetup, isTrue);
      expect(Profile(id: 'x', postalCode: '34710').hasCompletedSetup, isFalse);
      expect(
        Profile(id: 'x', languages: const ['Turkish']).hasCompletedSetup,
        isFalse,
      );
    });

    test('firestore round trip preserves spec fields', () {
      final map = makeProfile().toFirestore();
      final back = Profile.fromFirestore(map, 'u1');

      expect(back.postalCode, '34710');
      expect(back.areaLabel, 'Moda, Kadıköy');
      expect(back.languages, ['Turkish', 'English']);
      expect(back.points, 200);
      expect(back.pointsGranted, isTrue);
      expect(back.ratingAvg, 4.5);
      expect(back.ratingCount, 8);
      expect(back.tradeCount, 12);
    });

    test('notification prefs default to opt-out (spec §8 opt-ins)', () {
      final p = Profile(id: 'u3');
      expect(p.notifyNewBookNearby, isFalse);
      expect(p.notifyJournal, isFalse);
    });

    test('GPS coordinates are never part of the new serialization (spec §5)',
        () {
      final map = makeProfile().toFirestore();
      expect(map.containsKey('locationLat'), isFalse);
      expect(map.containsKey('locationLng'), isFalse);
    });
  });
}
