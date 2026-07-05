import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Post-swap ratings (spec §3, mock #3g).
///
/// Doc IDs follow the `{tradeId}_{fromId}` convention so one rating per
/// direction per trade is structurally guaranteed (and rules-enforced).
/// Submitting transactionally updates the recipient's ratingAvg/ratingCount.
class RatingService {
  final FirebaseFirestore db;

  RatingService(this.db);

  String _docId(String tradeId, String fromId) => '${tradeId}_$fromId';

  Future<bool> hasRated({required String tradeId, required String fromId}) async {
    final doc =
        await db.collection('ratings').doc(_docId(tradeId, fromId)).get();
    return doc.exists;
  }

  /// Submits a rating. Returns false when this direction already rated
  /// (skippable flows may call twice; that is not an error).
  Future<bool> submit({
    required String tradeId,
    required String fromId,
    required String toId,
    required int stars,
    Set<RatingTag> tags = const {},
    String? note,
  }) async {
    if (stars < 1 || stars > 5) {
      throw ArgumentError.value(stars, 'stars', 'must be 1-5');
    }
    if (note != null && note.length > Rating.maxNoteLength) {
      throw ArgumentError.value(
          note, 'note', 'max ${Rating.maxNoteLength} characters');
    }

    final ratingRef = db.collection('ratings').doc(_docId(tradeId, fromId));
    final userRef = db.collection('users').doc(toId);

    return db.runTransaction<bool>((tx) async {
      final existing = await tx.get(ratingRef);
      if (existing.exists) return false;

      final userSnap = await tx.get(userRef);
      final currentAvg =
          ((userSnap.data()?['ratingAvg'] as num?) ?? 0).toDouble();
      final currentCount =
          ((userSnap.data()?['ratingCount'] as num?) ?? 0).toInt();

      final newCount = currentCount + 1;
      final newAvg = ((currentAvg * currentCount) + stars) / newCount;

      tx.set(ratingRef, {
        'tradeId': tradeId,
        'fromId': fromId,
        'toId': toId,
        'stars': stars,
        'tags': tags.map((t) => t.value).toList(),
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.update(userRef, {
        'ratingAvg': newAvg,
        'ratingCount': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    }).then((created) async {
      if (created) {
        await db.collection('notifications').add({
          'userId': toId,
          'type': NotificationType.ratingReceived.value,
          'refId': tradeId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return created;
    });
  }
}
