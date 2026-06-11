import 'book.dart';
import 'profile.dart';

/// Conversation participant model
class ConversationParticipant {
  final String userId;
  final String conversationId;
  final DateTime createdAt;
  final Profile? user;

  ConversationParticipant({
    required this.userId,
    required this.conversationId,
    required this.createdAt,
    this.user,
  });

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) {
    return ConversationParticipant(
      userId: json['user_id'] as String,
      conversationId: json['conversation_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      user: json['user'] != null
          ? Profile.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Conversation model
class Conversation {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final int unreadCount;
  final List<ConversationParticipant> participants;
  final Profile? otherUser;
  final String? bookId;
  final Book? book;

  Conversation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.participants = const [],
    this.otherUser,
    this.bookId,
    this.book,
  });

  /// Check if this conversation has unread messages
  bool get hasUnread => unreadCount > 0;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) =>
                  ConversationParticipant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      otherUser: json['other_user'] != null
          ? Profile.fromJson(json['other_user'] as Map<String, dynamic>)
          : null,
      bookId: json['book_id'] as String?,
      book: json['book'] != null
          ? Book.fromJson(json['book'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_message': lastMessage,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'last_message_sender_id': lastMessageSenderId,
      'unread_count': unreadCount,
      'book_id': bookId,
    };
  }
}

/// Message model
class Message {
  final String id;
  final String conversationId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;
  final Profile? user;
  final String? relatedBookId;
  final Book? relatedBook;

  Message({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.isEdited = false,
    this.user,
    this.relatedBookId,
    this.relatedBook,
  });

  /// Check if this message is from the current user
  bool isFromUser(String currentUserId) => userId == currentUserId;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isEdited: json['is_edited'] as bool? ?? false,
      user: json['user'] != null
          ? Profile.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      relatedBookId: json['related_book_id'] as String?,
      relatedBook: json['related_book'] != null
          ? Book.fromJson(json['related_book'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_edited': isEdited,
      'related_book_id': relatedBookId,
    };
  }
}
