import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

/// First-sign-in bootstrap (plan Phase C.6).
///
/// Social sign-in (Apple/Google/email link) fires the same code path on every
/// login, so both steps here must be safe to repeat:
/// - [ensureUserDocument] creates the user doc once, with ZERO points;
/// - [grantWelcomePointsIfNeeded] applies the one-time 200-pt welcome grant
///   (spec §4.2) inside a transaction guarded by `pointsGranted`.
///
/// Firestore rules mirror this shape: user docs must be created with
/// `points: 0, pointsGranted: false`, and the only allowed self-serve points
/// update is the +200 grant flipping `pointsGranted` to true.
class UserBootstrapService {
  final FirebaseFirestore db;

  UserBootstrapService(this.db);

  /// The welcome gift for a new account (spec §4.2).
  static const int welcomeGrant = 200;

  /// Creates the user document if it doesn't exist yet. Never overwrites an
  /// existing profile (provider display names must not clobber user edits).
  Future<Profile> ensureUserDocument({
    required String uid,
    String? email,
    String? displayName,
    String? avatarUrl,
  }) async {
    final ref = db.collection('users').doc(uid);
    final snapshot = await ref.get();

    if (snapshot.exists) {
      return Profile.fromFirestore(snapshot.data()!, uid);
    }

    await ref.set({
      'id': uid,
      'email': email ?? '',
      'fullName': displayName ?? '',
      'name': displayName ?? '',
      'avatarUrl': avatarUrl ?? '',
      'languages': <String>[],
      'points': 0,
      'pointsGranted': false,
      'ratingAvg': 0,
      'ratingCount': 0,
      'tradeCount': 0,
      'notifyNewBookNearby': false,
      'notifyJournal': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final created = await ref.get();
    return Profile.fromFirestore(created.data()!, uid);
  }

  /// Applies the one-time 200-pt welcome grant. Returns true if the grant
  /// happened on this call, false if it had already been granted (idempotent
  /// across reinstalls, second devices, and repeated sign-ins).
  Future<bool> grantWelcomePointsIfNeeded(String uid) async {
    final ref = db.collection('users').doc(uid);

    return db.runTransaction<bool>((tx) async {
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) return false;

      final data = snapshot.data()!;
      if (data['pointsGranted'] == true) return false;

      final current = (data['points'] as num?)?.toInt() ?? 0;
      tx.update(ref, {
        'points': current + welcomeGrant,
        'pointsGranted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }
}
