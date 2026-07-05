import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Error codes for trade transitions.
enum TradeErrorCode {
  insufficientPoints,
  ownBook,
  duplicateRequest,
  bookNotRequestable,
  invalidOfferedBook,
  notAllowed,
  invalidStatus,
  alreadyConfirmed,
  notFound,
}

class TradeEngineException implements Exception {
  final TradeErrorCode code;
  final String message;

  TradeEngineException(this.code, this.message);

  @override
  String toString() => 'TradeEngineException(${code.name}): $message';
}

/// Result of a swap confirmation (decision D7).
class SwapConfirmation {
  /// True when this was the second confirmation and the trade completed.
  final bool completed;

  const SwapConfirmation({required this.completed});
}

/// The points economy (spec §4, amended by D7) — every transition is a single
/// Firestore transaction so escrow, refunds, locks, and transfers can never
/// half-apply. This is the ONLY code path that moves points or book status.
///
/// Architecture note (decision D1 "hybrid"): transitions run client-side for
/// the closed TestFlight; scheduled work (expiry sweeps, reminder pushes)
/// lives in Cloud Functions. Move these transitions into callables before a
/// public launch.
class TradeEngine {
  final FirebaseFirestore db;

  TradeEngine(this.db);

  CollectionReference<Map<String, dynamic>> get _trades =>
      db.collection('trades');
  CollectionReference<Map<String, dynamic>> get _books =>
      db.collection('books');
  CollectionReference<Map<String, dynamic>> get _users =>
      db.collection('users');

  // ---------------------------------------------------------------------
  // Create request (spec §4.3-4.5)
  // ---------------------------------------------------------------------

  Future<Trade> createRequest({
    required String requesterId,
    required String bookId,
    required TradeOffer offer,
    String? offeredBookId,
    String? note,
  }) async {
    if (offer == TradeOffer.book &&
        (offeredBookId == null || offeredBookId.isEmpty)) {
      throw TradeEngineException(
          TradeErrorCode.invalidOfferedBook, 'A book offer needs a book.');
    }

    // Max one active request per requester per book (spec §4.5). Queries are
    // not allowed inside transactions, so check first; the rules-side guard
    // and the tiny race window are acceptable for the closed TestFlight.
    final existing = await _trades
        .where('bookId', isEqualTo: bookId)
        .where('requesterId', isEqualTo: requesterId)
        .where('status', whereIn: ['requested', 'accepted']).get();
    if (existing.docs.isNotEmpty) {
      throw TradeEngineException(TradeErrorCode.duplicateRequest,
          'You already have an active request for this book.');
    }

    final tradeRef = _trades.doc();

    final trade = await db.runTransaction<Trade>((tx) async {
      final bookSnap = await tx.get(_books.doc(bookId));
      if (!bookSnap.exists) {
        throw TradeEngineException(TradeErrorCode.notFound, 'Book not found.');
      }
      final book = Book.fromFirestore(bookSnap.data()!, bookId);

      if (book.ownerId == requesterId) {
        throw TradeEngineException(
            TradeErrorCode.ownBook, 'This book is already on your shelf.');
      }
      if (!book.isRequestable) {
        throw TradeEngineException(TradeErrorCode.bookNotRequestable,
            'This book is not on the shelf right now.');
      }

      var escrowed = false;

      if (offer == TradeOffer.points50) {
        final requesterSnap = await tx.get(_users.doc(requesterId));
        final points =
            ((requesterSnap.data()?['points'] as num?) ?? 0).toInt();
        if (points < Trade.pointsPrice) {
          throw TradeEngineException(TradeErrorCode.insufficientPoints,
              'Shelve a book to earn points.');
        }
        // Escrow immediately (spec §4.3)
        tx.update(_users.doc(requesterId), {
          'points': points - Trade.pointsPrice,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        escrowed = true;
      } else {
        final offeredSnap = await tx.get(_books.doc(offeredBookId!));
        if (!offeredSnap.exists) {
          throw TradeEngineException(
              TradeErrorCode.invalidOfferedBook, 'Offered book not found.');
        }
        final offered = Book.fromFirestore(offeredSnap.data()!, offeredBookId);
        if (offered.ownerId != requesterId ||
            offered.status != BookStatus.onShelf) {
          throw TradeEngineException(TradeErrorCode.invalidOfferedBook,
              'Pick one of your on-shelf books to offer.');
        }
        // No lock at request time (decision D9 / spec §12.3)
      }

      final now = DateTime.now();
      tx.set(tradeRef, {
        'bookId': bookId,
        'requesterId': requesterId,
        'ownerId': book.ownerId,
        'offer': offer.value,
        'offeredBookId': offer == TradeOffer.book ? offeredBookId : null,
        'note': note,
        'status': TradeStatus.requested.value,
        'escrowed': escrowed,
        'swapConfirmedBy': <String>[],
        'requestedAt': now,
        'updatedAt': now,
      });

      tx.update(_books.doc(bookId), {
        'requestCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return Trade(
        id: tradeRef.id,
        bookId: bookId,
        requesterId: requesterId,
        ownerId: book.ownerId,
        offer: offer,
        offeredBookId: offer == TradeOffer.book ? offeredBookId : null,
        note: note,
        escrowed: escrowed,
        requestedAt: now,
      );
    });

    await _systemMessage(
      trade.id,
      requesterId,
      offer == TradeOffer.points50
          ? 'You sent ${Trade.pointsPrice} pts — returned if the trade is cancelled'
          : 'You offered one of your books',
    );
    await _notify(trade.ownerId, NotificationType.requestReceived, trade.id);

    return trade;
  }

  // ---------------------------------------------------------------------
  // Accept (spec §4.5-4.6)
  // ---------------------------------------------------------------------

  Future<void> accept({required String tradeId, required String actorId}) async {
    // Competing requests to auto-decline (query outside the transaction,
    // re-checked per doc inside it).
    final tradeSnapPre = await _trades.doc(tradeId).get();
    if (!tradeSnapPre.exists) {
      throw TradeEngineException(TradeErrorCode.notFound, 'Trade not found.');
    }
    final bookId = tradeSnapPre.data()!['bookId'] as String;
    final competitors = await _trades
        .where('bookId', isEqualTo: bookId)
        .where('status', isEqualTo: 'requested')
        .get();

    final declined = <({String tradeId, String requesterId})>[];

    await db.runTransaction((tx) async {
      final tradeSnap = await tx.get(_trades.doc(tradeId));
      final trade = Trade.fromFirestore(tradeSnap.data()!, tradeId);

      if (trade.ownerId != actorId) {
        throw TradeEngineException(
            TradeErrorCode.notAllowed, 'Only the owner can accept.');
      }
      if (trade.status != TradeStatus.requested) {
        throw TradeEngineException(TradeErrorCode.invalidStatus,
            'This request is no longer open.');
      }

      // Read everything first (Firestore transactions: reads before writes).
      final competitorReads =
          <({String id, Map<String, dynamic> data})>[];
      for (final doc in competitors.docs) {
        if (doc.id == tradeId) continue;
        final snap = await tx.get(_trades.doc(doc.id));
        if (snap.exists) {
          competitorReads.add((id: doc.id, data: snap.data()!));
        }
      }

      Map<String, dynamic>? offeredData;
      if (trade.offer == TradeOffer.book) {
        final offeredSnap = await tx.get(_books.doc(trade.offeredBookId!));
        offeredData = offeredSnap.data();
      }

      final competitorRefunds = <String, int>{};
      for (final competitor in competitorReads) {
        final data = competitor.data;
        if (data['status'] != 'requested') continue;
        final requesterId = data['requesterId'] as String;
        if (data['escrowed'] == true) {
          final requesterSnap = await tx.get(_users.doc(requesterId));
          final points =
              ((requesterSnap.data()?['points'] as num?) ?? 0).toInt();
          competitorRefunds[requesterId] = points + Trade.pointsPrice;
        }
        declined.add((tradeId: competitor.id, requesterId: requesterId));
      }

      // Writes.
      final now = DateTime.now();
      tx.update(_trades.doc(tradeId), {
        'status': TradeStatus.accepted.value,
        'acceptedAt': now,
        'updatedAt': now,
      });
      tx.update(_books.doc(trade.bookId), {
        'status': BookStatus.inTrade.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (trade.offer == TradeOffer.book) {
        final offered = offeredData == null
            ? null
            : Book.fromFirestore(offeredData, trade.offeredBookId!);
        if (offered == null ||
            offered.ownerId != trade.requesterId ||
            offered.status != BookStatus.onShelf) {
          throw TradeEngineException(TradeErrorCode.invalidOfferedBook,
              'The offered book is no longer available.');
        }
        tx.update(_books.doc(trade.offeredBookId!), {
          'status': BookStatus.inTrade.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      for (final competitor in declined) {
        tx.update(_trades.doc(competitor.tradeId), {
          'status': TradeStatus.declined.value,
          'escrowed': false,
          'closedAt': now,
          'updatedAt': now,
        });
      }
      for (final refund in competitorRefunds.entries) {
        tx.update(_users.doc(refund.key), {
          'points': refund.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (declined.isNotEmpty) {
        tx.update(_books.doc(trade.bookId), {
          'requestCount': FieldValue.increment(-declined.length),
        });
      }
    });

    final trade = Trade.fromFirestore(
        (await _trades.doc(tradeId).get()).data()!, tradeId);
    await _systemMessage(tradeId, actorId, 'Accepted');
    await _notify(trade.requesterId, NotificationType.requestAccepted, tradeId);
    for (final competitor in declined) {
      await _systemMessage(competitor.tradeId, actorId,
          'The owner accepted another request — your points are back');
      await _notify(competitor.requesterId, NotificationType.requestDeclined,
          competitor.tradeId);
    }
  }

  // ---------------------------------------------------------------------
  // Decline / cancel (spec §4.8)
  // ---------------------------------------------------------------------

  Future<void> decline(
      {required String tradeId, required String actorId}) async {
    await _close(
      tradeId: tradeId,
      actorId: actorId,
      toStatus: TradeStatus.declined,
      allowedActor: _AllowedActor.ownerOnly,
      fromStatuses: const [TradeStatus.requested],
    );
    final trade = Trade.fromFirestore(
        (await _trades.doc(tradeId).get()).data()!, tradeId);
    await _systemMessage(tradeId, actorId, 'Declined');
    await _notify(trade.requesterId, NotificationType.requestDeclined, tradeId);
  }

  Future<void> cancel({required String tradeId, required String actorId}) async {
    await _close(
      tradeId: tradeId,
      actorId: actorId,
      toStatus: TradeStatus.cancelled,
      allowedActor: _AllowedActor.participant,
      fromStatuses: const [TradeStatus.requested, TradeStatus.accepted],
    );
    final trade = Trade.fromFirestore(
        (await _trades.doc(tradeId).get()).data()!, tradeId);
    await _systemMessage(tradeId, actorId, 'Cancelled — points returned');
    await _notify(trade.otherPartyId(actorId),
        NotificationType.tradeCancelled, tradeId);
  }

  /// Shared close path: refund escrow, unlock books, set the terminal status.
  Future<void> _close({
    required String tradeId,
    required String actorId,
    required TradeStatus toStatus,
    required _AllowedActor allowedActor,
    required List<TradeStatus> fromStatuses,
  }) async {
    await db.runTransaction((tx) async {
      final tradeSnap = await tx.get(_trades.doc(tradeId));
      if (!tradeSnap.exists) {
        throw TradeEngineException(TradeErrorCode.notFound, 'Trade not found.');
      }
      final trade = Trade.fromFirestore(tradeSnap.data()!, tradeId);

      final allowed = switch (allowedActor) {
        _AllowedActor.ownerOnly => trade.ownerId == actorId,
        _AllowedActor.participant => trade.isParticipant(actorId),
      };
      if (!allowed) {
        throw TradeEngineException(
            TradeErrorCode.notAllowed, 'Not your trade.');
      }
      if (!fromStatuses.contains(trade.status)) {
        throw TradeEngineException(
            TradeErrorCode.invalidStatus, 'This trade is already closed.');
      }

      // Reads before writes
      int? refundedPoints;
      if (trade.escrowed) {
        final requesterSnap = await tx.get(_users.doc(trade.requesterId));
        refundedPoints =
            ((requesterSnap.data()?['points'] as num?) ?? 0).toInt() +
                Trade.pointsPrice;
      }

      final now = DateTime.now();
      tx.update(_trades.doc(tradeId), {
        'status': toStatus.value,
        'escrowed': false,
        'closedAt': now,
        'updatedAt': now,
      });

      if (refundedPoints != null) {
        tx.update(_users.doc(trade.requesterId), {
          'points': refundedPoints,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Unlock books that were locked at accept
      if (trade.status == TradeStatus.accepted) {
        tx.update(_books.doc(trade.bookId), {
          'status': BookStatus.onShelf.value,
          'requestCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (trade.offer == TradeOffer.book && trade.offeredBookId != null) {
          tx.update(_books.doc(trade.offeredBookId!), {
            'status': BookStatus.onShelf.value,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Pending request going away: drop its request count
        tx.update(_books.doc(trade.bookId), {
          'requestCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ---------------------------------------------------------------------
  // Two-sided swap confirmation (decision D7)
  // ---------------------------------------------------------------------

  Future<SwapConfirmation> confirmSwap(
      {required String tradeId, required String actorId}) async {
    var completed = false;
    String? otherPartyId;

    await db.runTransaction((tx) async {
      final tradeSnap = await tx.get(_trades.doc(tradeId));
      if (!tradeSnap.exists) {
        throw TradeEngineException(TradeErrorCode.notFound, 'Trade not found.');
      }
      final trade = Trade.fromFirestore(tradeSnap.data()!, tradeId);

      if (!trade.isParticipant(actorId)) {
        throw TradeEngineException(
            TradeErrorCode.notAllowed, 'Not your trade.');
      }
      if (trade.status != TradeStatus.accepted) {
        throw TradeEngineException(TradeErrorCode.invalidStatus,
            'Only accepted trades can be marked as swapped.');
      }
      if (trade.hasConfirmedSwap(actorId)) {
        throw TradeEngineException(TradeErrorCode.alreadyConfirmed,
            'You already marked this as swapped.');
      }

      otherPartyId = trade.otherPartyId(actorId);
      final confirmations = [...trade.swapConfirmedBy, actorId];
      final bothConfirmed = confirmations.contains(trade.requesterId) &&
          confirmations.contains(trade.ownerId);
      final now = DateTime.now();

      if (!bothConfirmed) {
        tx.update(_trades.doc(tradeId), {
          'swapConfirmedBy': confirmations,
          'firstConfirmAt': trade.firstConfirmAt ?? now,
          'updatedAt': now,
        });
        return;
      }

      // ---- Completion (spec §4.7) ----
      completed = true;

      // Reads before writes
      int? ownerNewPoints;
      if (trade.offer == TradeOffer.points50 && trade.escrowed) {
        final ownerSnap = await tx.get(_users.doc(trade.ownerId));
        ownerNewPoints =
            ((ownerSnap.data()?['points'] as num?) ?? 0).toInt() +
                Trade.pointsPrice;
      }

      tx.update(_trades.doc(tradeId), {
        'swapConfirmedBy': confirmations,
        'status': TradeStatus.swapped.value,
        'escrowed': false,
        'swappedAt': now,
        'closedAt': now,
        'updatedAt': now,
      });

      // Points release
      if (ownerNewPoints != null) {
        tx.update(_users.doc(trade.ownerId), {
          'points': ownerNewPoints,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Ownership transfer: the traded book joins the requester's shelf
      tx.update(_books.doc(trade.bookId), {
        'ownerId': trade.requesterId,
        'status': BookStatus.onShelf.value,
        'requestCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Book-for-book: the offered book joins the owner's shelf
      if (trade.offer == TradeOffer.book && trade.offeredBookId != null) {
        tx.update(_books.doc(trade.offeredBookId!), {
          'ownerId': trade.ownerId,
          'status': BookStatus.onShelf.value,
          'requestCount': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Trade counters
      tx.update(_users.doc(trade.requesterId), {
        'tradeCount': FieldValue.increment(1),
      });
      tx.update(_users.doc(trade.ownerId), {
        'tradeCount': FieldValue.increment(1),
      });
    });

    if (completed) {
      await _systemMessage(tradeId, actorId, 'Swapped — enjoy the read');
    } else {
      await _systemMessage(tradeId, actorId, 'Marked as swapped — waiting for the other side to confirm');
      if (otherPartyId != null) {
        await _notify(otherPartyId!, NotificationType.markedSwapped, tradeId);
      }
    }

    return SwapConfirmation(completed: completed);
  }

  // ---------------------------------------------------------------------
  // Expiry (spec §4.9) — also run server-side by the scheduled function
  // ---------------------------------------------------------------------

  /// Expires a stale request (7 days without an owner response), refunding
  /// escrow. Returns true when this call performed the expiry. Idempotent.
  Future<bool> expireIfStale(String tradeId) async {
    var didExpire = false;

    await db.runTransaction((tx) async {
      final tradeSnap = await tx.get(_trades.doc(tradeId));
      if (!tradeSnap.exists) return;
      final trade = Trade.fromFirestore(tradeSnap.data()!, tradeId);

      if (!trade.isExpiredAt(DateTime.now())) return;

      int? refundedPoints;
      if (trade.escrowed) {
        final requesterSnap = await tx.get(_users.doc(trade.requesterId));
        refundedPoints =
            ((requesterSnap.data()?['points'] as num?) ?? 0).toInt() +
                Trade.pointsPrice;
      }

      final now = DateTime.now();
      tx.update(_trades.doc(tradeId), {
        'status': TradeStatus.expired.value,
        'escrowed': false,
        'closedAt': now,
        'updatedAt': now,
      });
      if (refundedPoints != null) {
        tx.update(_users.doc(trade.requesterId), {
          'points': refundedPoints,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.update(_books.doc(trade.bookId), {
        'requestCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      didExpire = true;
    });

    if (didExpire) {
      final trade = Trade.fromFirestore(
          (await _trades.doc(tradeId).get()).data()!, tradeId);
      await _notify(
          trade.requesterId, NotificationType.expiredRefunded, tradeId);
    }
    return didExpire;
  }

  // ---------------------------------------------------------------------
  // Side channels: per-trade system messages + notifications
  // ---------------------------------------------------------------------

  Future<void> _systemMessage(
      String tradeId, String senderId, String text) async {
    await _trades.doc(tradeId).collection('messages').add({
      'senderId': senderId,
      'text': text,
      'type': MessageType.system.value,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _notify(
      String userId, NotificationType type, String refId) async {
    await db.collection('notifications').add({
      'userId': userId,
      'type': type.value,
      'refId': refId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

enum _AllowedActor { ownerOnly, participant }
