import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_turning_pages/services/user_bootstrap_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late UserBootstrapService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = UserBootstrapService(db);
  });

  group('ensureUserDocument', () {
    test('creates a fresh user doc with zero points (grant is separate)',
        () async {
      final profile = await service.ensureUserDocument(
        uid: 'u1',
        email: 'piri@example.com',
        displayName: 'Piri Turtle',
      );

      expect(profile.id, 'u1');
      expect(profile.points, 0);
      expect(profile.pointsGranted, isFalse);

      final doc = await db.collection('users').doc('u1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['points'], 0);
      expect(doc.data()!['pointsGranted'], false);
      expect(doc.data()!['email'], 'piri@example.com');
    });

    test('does not overwrite an existing user doc', () async {
      await db.collection('users').doc('u1').set({
        'email': 'piri@example.com',
        'fullName': 'Piri Turtle',
        'postalCode': '34710',
        'languages': ['Turkish'],
        'points': 150,
        'pointsGranted': true,
      });

      final profile = await service.ensureUserDocument(
        uid: 'u1',
        email: 'piri@example.com',
        displayName: 'Renamed By Provider',
      );

      expect(profile.points, 150);
      expect(profile.fullName, 'Piri Turtle');
      expect(profile.postalCode, '34710');
    });
  });

  group('grantWelcomePointsIfNeeded (spec §4.2 — 200 pts exactly once)', () {
    test('grants 200 points to a fresh account', () async {
      await service.ensureUserDocument(uid: 'u1', email: 'a@b.c');

      final granted = await service.grantWelcomePointsIfNeeded('u1');

      expect(granted, isTrue);
      final doc = await db.collection('users').doc('u1').get();
      expect(doc.data()!['points'], 200);
      expect(doc.data()!['pointsGranted'], true);
    });

    test('is idempotent — second call changes nothing', () async {
      await service.ensureUserDocument(uid: 'u1', email: 'a@b.c');
      await service.grantWelcomePointsIfNeeded('u1');

      final grantedAgain = await service.grantWelcomePointsIfNeeded('u1');

      expect(grantedAgain, isFalse);
      final doc = await db.collection('users').doc('u1').get();
      expect(doc.data()!['points'], 200);
    });

    test('never re-grants even if the balance was spent to zero', () async {
      await service.ensureUserDocument(uid: 'u1', email: 'a@b.c');
      await service.grantWelcomePointsIfNeeded('u1');
      await db.collection('users').doc('u1').update({'points': 0});

      final granted = await service.grantWelcomePointsIfNeeded('u1');

      expect(granted, isFalse);
      final doc = await db.collection('users').doc('u1').get();
      expect(doc.data()!['points'], 0);
    });

    test('signing in on a new device does not duplicate the grant', () async {
      // Same uid, repeated bootstrap + grant (e.g. reinstall, second device).
      await service.ensureUserDocument(uid: 'u1', email: 'a@b.c');
      await service.grantWelcomePointsIfNeeded('u1');

      await service.ensureUserDocument(uid: 'u1', email: 'a@b.c');
      final granted = await service.grantWelcomePointsIfNeeded('u1');

      expect(granted, isFalse);
      final doc = await db.collection('users').doc('u1').get();
      expect(doc.data()!['points'], 200);
    });
  });
}
