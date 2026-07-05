import 'firestore_helpers.dart';
import 'book.dart';
import 'profile.dart';

/// Trade status — the 6 spec values (spec §3).
enum TradeStatus {
  requested('requested'),
  accepted('accepted'),
  swapped('swapped'),
  cancelled('cancelled'),
  declined('declined'),
  expired('expired');

  final String value;
  const TradeStatus(this.value);

  /// Terminal statuses can never transition again.
  bool get isTerminal =>
      this == swapped || this == cancelled || this == declined || this == expired;

  static TradeStatus fromString(String? raw) {
    if (raw == null) return TradeStatus.requested;
    for (final s in TradeStatus.values) {
      if (s.value == raw) return s;
    }
    // Legacy statuses (pre-redesign data)
    switch (raw) {
      case 'request_pending':
      case 'pending':
        return TradeStatus.requested;
      case 'rejected':
        return TradeStatus.declined;
      case 'completed':
        return TradeStatus.swapped;
      default:
        return TradeStatus.requested;
    }
  }

  String get displayName {
    switch (this) {
      case TradeStatus.requested:
        return 'Requested';
      case TradeStatus.accepted:
        return 'Accepted';
      case TradeStatus.swapped:
        return 'Swapped';
      case TradeStatus.cancelled:
        return 'Cancelled';
      case TradeStatus.declined:
        return 'Declined';
      case TradeStatus.expired:
        return 'Expired';
    }
  }

  // Legacy aliases so pre-redesign screens compile until Phase H.
  @Deprecated('Use TradeStatus.requested')
  static const TradeStatus pending = TradeStatus.requested;
  @Deprecated('Use TradeStatus.requested')
  static const TradeStatus requestPending = TradeStatus.requested;
  @Deprecated('Use TradeStatus.declined')
  static const TradeStatus rejected = TradeStatus.declined;
  @Deprecated('Use TradeStatus.swapped')
  static const TradeStatus completed = TradeStatus.swapped;
}

/// What the requester offers: a flat 50 pts or one of their books (spec §4).
enum TradeOffer {
  points50('points_50'),
  book('book');

  final String value;
  const TradeOffer(this.value);

  static TradeOffer fromString(String? raw) =>
      raw == 'book' ? TradeOffer.book : TradeOffer.points50;
}

/// Single-book trade (spec §3, amended by decision D7 — two-sided swap
/// confirmation with `swapConfirmedBy`).
class Trade {
  /// Every book costs a flat 50 pts. No negotiation anywhere (spec §4.1).
  static const int pointsPrice = 50;

  /// Requested trades expire after 7 days without an owner response
  /// (spec §4.9); a warning notification goes out on day 6.
  static const Duration expiryWindow = Duration(days: 7);

  final String id;
  final String bookId;
  final String requesterId;
  final String ownerId;
  final TradeOffer offer;

  /// The requester's offered book — required iff [offer] is [TradeOffer.book].
  final String? offeredBookId;
  final String? note;
  final TradeStatus status;

  /// Free-text meeting info both parties can see.
  final String? meetInfo;

  /// True while 50 pts are held from the requester (points offers only).
  final bool escrowed;

  /// D7: userIds who tapped "Mark as swapped". The trade completes when both
  /// parties are present.
  final List<String> swapConfirmedBy;

  /// When the first party confirmed — drives the +12h/+24h reminder pushes.
  final DateTime? firstConfirmAt;

  // Timestamps per transition (spec §3)
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? swappedAt;
  final DateTime? closedAt;
  final DateTime? updatedAt;

  /// Hydrated objects (not serialized).
  final Profile? requester;
  final Profile? owner;
  final Book? book;
  final Book? offeredBook;

  Trade({
    required this.id,
    required this.bookId,
    required this.requesterId,
    required this.ownerId,
    required this.offer,
    this.offeredBookId,
    this.note,
    this.status = TradeStatus.requested,
    this.meetInfo,
    this.escrowed = false,
    this.swapConfirmedBy = const [],
    this.firstConfirmAt,
    required this.requestedAt,
    this.acceptedAt,
    this.swappedAt,
    this.closedAt,
    this.updatedAt,
    this.requester,
    this.owner,
    this.book,
    this.offeredBook,
  });

  bool isParticipant(String userId) =>
      userId == requesterId || userId == ownerId;

  String otherPartyId(String userId) =>
      userId == requesterId ? ownerId : requesterId;

  /// A book offer without an offered book is invalid (spec §4.4).
  bool get hasValidOffer =>
      offer == TradeOffer.points50 || (offeredBookId?.isNotEmpty ?? false);

  // ---- Two-sided swap confirmation (D7) ----

  bool hasConfirmedSwap(String userId) => swapConfirmedBy.contains(userId);

  bool get bothConfirmedSwap =>
      swapConfirmedBy.contains(requesterId) &&
      swapConfirmedBy.contains(ownerId);

  /// The participant who still needs to confirm, or null if none/complete.
  String? get awaitingConfirmationFrom {
    if (swapConfirmedBy.isEmpty || bothConfirmedSwap) return null;
    return swapConfirmedBy.contains(requesterId) ? ownerId : requesterId;
  }

  // ---- Expiry (spec §4.9) ----

  /// Whether this trade counts as expired at [when]: only `requested` trades
  /// expire, 7 days after they were sent.
  bool isExpiredAt(DateTime when) =>
      status == TradeStatus.requested &&
      when.isAfter(requestedAt.add(expiryWindow));

  factory Trade.fromFirestore(Map<String, dynamic> data, String id) {
    return Trade(
      id: id,
      bookId: data['bookId'] as String? ?? '',
      requesterId: data['requesterId'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      offer: TradeOffer.fromString(data['offer'] as String?),
      offeredBookId: data['offeredBookId'] as String?,
      note: data['note'] as String?,
      status: TradeStatus.fromString(data['status'] as String?),
      meetInfo: data['meetInfo'] as String?,
      escrowed: data['escrowed'] as bool? ?? false,
      swapConfirmedBy:
          (data['swapConfirmedBy'] as List<dynamic>?)?.cast<String>() ??
              const [],
      firstConfirmAt: dateFromFirestore(data['firstConfirmAt']),
      requestedAt: dateFromFirestore(data['requestedAt']) ??
          dateFromFirestore(data['createdAt']) ??
          DateTime.now(),
      acceptedAt: dateFromFirestore(data['acceptedAt']),
      swappedAt: dateFromFirestore(data['swappedAt']),
      closedAt: dateFromFirestore(data['closedAt']),
      updatedAt: dateFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookId': bookId,
      'requesterId': requesterId,
      'ownerId': ownerId,
      'offer': offer.value,
      'offeredBookId': offeredBookId,
      'note': note,
      'status': status.value,
      'meetInfo': meetInfo,
      'escrowed': escrowed,
      'swapConfirmedBy': swapConfirmedBy,
      'firstConfirmAt': firstConfirmAt,
      'requestedAt': requestedAt,
      'acceptedAt': acceptedAt,
      'swappedAt': swappedAt,
      'closedAt': closedAt,
      'updatedAt': updatedAt,
    };
  }

  Trade copyWith({
    String? id,
    String? bookId,
    String? requesterId,
    String? ownerId,
    TradeOffer? offer,
    String? offeredBookId,
    String? note,
    TradeStatus? status,
    String? meetInfo,
    bool? escrowed,
    List<String>? swapConfirmedBy,
    DateTime? firstConfirmAt,
    DateTime? requestedAt,
    DateTime? acceptedAt,
    DateTime? swappedAt,
    DateTime? closedAt,
    DateTime? updatedAt,
    Profile? requester,
    Profile? owner,
    Book? book,
    Book? offeredBook,
  }) {
    return Trade(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      requesterId: requesterId ?? this.requesterId,
      ownerId: ownerId ?? this.ownerId,
      offer: offer ?? this.offer,
      offeredBookId: offeredBookId ?? this.offeredBookId,
      note: note ?? this.note,
      status: status ?? this.status,
      meetInfo: meetInfo ?? this.meetInfo,
      escrowed: escrowed ?? this.escrowed,
      swapConfirmedBy: swapConfirmedBy ?? this.swapConfirmedBy,
      firstConfirmAt: firstConfirmAt ?? this.firstConfirmAt,
      requestedAt: requestedAt ?? this.requestedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      swappedAt: swappedAt ?? this.swappedAt,
      closedAt: closedAt ?? this.closedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      requester: requester ?? this.requester,
      owner: owner ?? this.owner,
      book: book ?? this.book,
      offeredBook: offeredBook ?? this.offeredBook,
    );
  }

  // ---------------------------------------------------------------------------
  // Legacy compatibility — pre-redesign screens (rebuilt in Phase H) only.
  // ---------------------------------------------------------------------------

  @Deprecated('Use requesterId')
  String get initiatorId => requesterId;

  @Deprecated('Use ownerId')
  String get recipientId => ownerId;

  @Deprecated('Use requester')
  Profile? get initiator => requester;

  @Deprecated('Use owner')
  Profile? get recipient => owner;

  @Deprecated('Use note')
  String? get initiatorMessage => note;

  @Deprecated('Trades are single-book in v1')
  DateTime get createdAt => requestedAt;

  /// Whether this trade is incoming for [userId] (they own the book).
  bool isIncoming(String userId) => ownerId == userId;

  /// The counterparty profile from [currentUserId]'s perspective.
  Profile? getPartner(String currentUserId) =>
      currentUserId == requesterId ? owner : requester;

  /// Books the counterparty brings, from [currentUserId]'s perspective.
  List<Book> getTheirBooks(String currentUserId) {
    if (currentUserId == requesterId) {
      return [if (book != null) book!];
    }
    return [if (offeredBook != null) offeredBook!];
  }

  /// Books [currentUserId] brings to this trade.
  List<Book> getMyBooks(String currentUserId) {
    if (currentUserId == requesterId) {
      return [if (offeredBook != null) offeredBook!];
    }
    return [if (book != null) book!];
  }
}
