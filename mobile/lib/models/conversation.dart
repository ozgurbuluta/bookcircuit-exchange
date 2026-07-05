import 'firestore_helpers.dart';
import 'profile.dart';

/// Message type (spec §3): user text or system event (escrowed, accepted,
/// cancelled, swapped — rendered as honey pills, mock #2d).
enum MessageType {
  user('user'),
  system('system');

  final String value;
  const MessageType(this.value);

  static MessageType fromString(String? raw) =>
      raw == 'system' ? MessageType.system : MessageType.user;
}

/// Chat message (spec §3). In v1 threads exist only per trade (plus club
/// groups reserved for v2), so a message points at [tradeId] or [clubId].
class Message {
  final String id;
  final String? tradeId;
  final String? clubId;
  final String senderId;
  final String text;
  final MessageType type;
  final DateTime createdAt;

  /// Hydrated sender profile (not serialized).
  final Profile? sender;

  // -------------------------------------------------------------------------
  // Legacy fields — old conversation-based chat, removed in Phase I.
  // -------------------------------------------------------------------------
  @Deprecated('Messages live under trades in v1')
  final String? conversationId;
  @Deprecated('Removed by the v1 redesign')
  final String? relatedBookId;

  Message({
    required this.id,
    this.tradeId,
    this.clubId,
    required this.senderId,
    required this.text,
    this.type = MessageType.user,
    required this.createdAt,
    this.sender,
    @Deprecated('Messages live under trades in v1') this.conversationId,
    @Deprecated('Removed by the v1 redesign') this.relatedBookId,
  });

  @Deprecated('Use senderId')
  String get userId => senderId;

  @Deprecated('Use text')
  String get content => text;

  @Deprecated('Use sender')
  Profile? get user => sender;

  bool get isSystem => type == MessageType.system;

  bool isFromUser(String currentUserId) => senderId == currentUserId;

  factory Message.fromFirestore(Map<String, dynamic> data, String id) {
    return Message(
      id: id,
      tradeId: data['tradeId'] as String?,
      clubId: data['clubId'] as String?,
      senderId: data['senderId'] as String? ?? data['userId'] as String? ?? '',
      text: data['text'] as String? ?? data['content'] as String? ?? '',
      type: MessageType.fromString(data['type'] as String?),
      createdAt: dateFromFirestore(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (tradeId != null) 'tradeId': tradeId,
      if (clubId != null) 'clubId': clubId,
      'senderId': senderId,
      'text': text,
      'type': type.value,
      'createdAt': createdAt,
    };
  }
}

