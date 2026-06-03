import 'book.dart';
import 'profile.dart';

/// Trade status enum
enum TradeStatus {
  requestPending('request_pending'),
  pending('pending'),
  accepted('accepted'),
  rejected('rejected'),
  completed('completed'),
  cancelled('cancelled');

  final String value;
  const TradeStatus(this.value);

  static TradeStatus fromString(String value) {
    return TradeStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => TradeStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case TradeStatus.requestPending:
        return 'Request';
      case TradeStatus.pending:
        return 'Pending';
      case TradeStatus.accepted:
        return 'Accepted';
      case TradeStatus.rejected:
        return 'Declined';
      case TradeStatus.completed:
        return 'Completed';
      case TradeStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Trade item model (book in a trade)
class TradeItem {
  final String id;
  final String tradeId;
  final String bookId;
  final String ownerId;
  final String recipientId;
  final DateTime createdAt;
  final String? interestId;
  final String itemType;
  final Book? book;
  final Profile? owner;
  final Profile? recipient;

  TradeItem({
    required this.id,
    required this.tradeId,
    required this.bookId,
    required this.ownerId,
    required this.recipientId,
    required this.createdAt,
    this.interestId,
    this.itemType = 'book',
    this.book,
    this.owner,
    this.recipient,
  });

  factory TradeItem.fromJson(Map<String, dynamic> json) {
    return TradeItem(
      id: json['id'] as String,
      tradeId: json['trade_id'] as String,
      bookId: json['book_id'] as String,
      ownerId: json['owner_id'] as String,
      recipientId: json['recipient_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      interestId: json['interest_id'] as String?,
      itemType: json['item_type'] as String? ?? 'book',
      book: json['book'] != null
          ? Book.fromJson(json['book'] as Map<String, dynamic>)
          : null,
      owner: json['owner'] != null
          ? Profile.fromJson(json['owner'] as Map<String, dynamic>)
          : null,
      recipient: json['recipient'] != null
          ? Profile.fromJson(json['recipient'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trade_id': tradeId,
      'book_id': bookId,
      'owner_id': ownerId,
      'recipient_id': recipientId,
      'created_at': createdAt.toIso8601String(),
      'interest_id': interestId,
      'item_type': itemType,
    };
  }
}

/// Trade model
class Trade {
  final String id;
  final String initiatorId;
  final String recipientId;
  final TradeStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? initiatorMessage;
  final String? recipientMessage;
  final bool isDirectRequest;
  final bool isCounteroffered;
  final Profile? initiator;
  final Profile? recipient;
  final List<TradeItem> items;

  Trade({
    required this.id,
    required this.initiatorId,
    required this.recipientId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.initiatorMessage,
    this.recipientMessage,
    this.isDirectRequest = false,
    this.isCounteroffered = false,
    this.initiator,
    this.recipient,
    this.items = const [],
  });

  /// Check if this trade is incoming for the given user
  bool isIncoming(String userId) => recipientId == userId;

  /// Get the partner profile (the other user in the trade)
  Profile? getPartner(String currentUserId) {
    if (initiatorId == currentUserId) {
      return recipient;
    }
    return initiator;
  }

  /// Get books being offered by the initiator
  List<Book> get initiatorBooks {
    return items
        .where((item) => item.ownerId == initiatorId)
        .map((item) => item.book)
        .whereType<Book>()
        .toList();
  }

  /// Get books being offered by the recipient
  List<Book> get recipientBooks {
    return items
        .where((item) => item.ownerId == recipientId)
        .map((item) => item.book)
        .whereType<Book>()
        .toList();
  }

  /// Get "their" books from the perspective of a user
  List<Book> getTheirBooks(String currentUserId) {
    return items
        .where((item) => item.ownerId != currentUserId)
        .map((item) => item.book)
        .whereType<Book>()
        .toList();
  }

  /// Get "my" books from the perspective of a user
  List<Book> getMyBooks(String currentUserId) {
    return items
        .where((item) => item.ownerId == currentUserId)
        .map((item) => item.book)
        .whereType<Book>()
        .toList();
  }

  factory Trade.fromJson(Map<String, dynamic> json) {
    return Trade(
      id: json['id'] as String,
      initiatorId: json['initiator_id'] as String,
      recipientId: json['recipient_id'] as String,
      status: TradeStatus.fromString(json['status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      initiatorMessage: json['initiator_message'] as String?,
      recipientMessage: json['recipient_message'] as String?,
      isDirectRequest: json['is_direct_request'] as bool? ?? false,
      isCounteroffered: json['is_counteroffered'] as bool? ?? false,
      initiator: json['initiator'] != null
          ? Profile.fromJson(json['initiator'] as Map<String, dynamic>)
          : null,
      recipient: json['recipient'] != null
          ? Profile.fromJson(json['recipient'] as Map<String, dynamic>)
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => TradeItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'initiator_id': initiatorId,
      'recipient_id': recipientId,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'initiator_message': initiatorMessage,
      'recipient_message': recipientMessage,
      'is_direct_request': isDirectRequest,
      'is_counteroffered': isCounteroffered,
    };
  }
}

/// Trade history entry
class TradeHistory {
  final String id;
  final String tradeId;
  final String action;
  final String actorId;
  final String? details;
  final DateTime createdAt;
  final Profile? actor;

  TradeHistory({
    required this.id,
    required this.tradeId,
    required this.action,
    required this.actorId,
    this.details,
    required this.createdAt,
    this.actor,
  });

  factory TradeHistory.fromJson(Map<String, dynamic> json) {
    return TradeHistory(
      id: json['id'] as String,
      tradeId: json['trade_id'] as String,
      action: json['action'] as String,
      actorId: json['actor_id'] as String,
      details: json['details'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      actor: json['actor'] != null
          ? Profile.fromJson(json['actor'] as Map<String, dynamic>)
          : null,
    );
  }
}
