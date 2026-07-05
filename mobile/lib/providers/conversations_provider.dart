import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

/// Conversations list provider
final conversationsProvider =
    FutureProvider.autoDispose<List<Conversation>>((ref) async {
  return FirebaseService.getConversations();
});

/// Unread messages count provider (for badge)
/// Chats-tab badge: incoming requests waiting on you (v1 proxy for unread —
/// per-thread read tracking is a v1.1 follow-up).
final unreadMessagesCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = FirebaseService.currentUser?.uid;
  if (userId == null) return 0;
  final trades = await FirebaseService.getUserTrades();
  return trades
      .where((t) => t.ownerId == userId && t.status.value == 'requested')
      .length;
});

/// Single conversation provider
final conversationProvider =
    FutureProvider.autoDispose.family<Conversation?, String>((ref, id) async {
  final conversations = await FirebaseService.getConversations();
  return conversations.where((c) => c.id == id).firstOrNull;
});

/// Messages for a conversation
final messagesProvider =
    FutureProvider.autoDispose.family<List<Message>, String>((ref, conversationId) async {
  return FirebaseService.getMessages(conversationId);
});

/// Chat state for a conversation
class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

/// Chat notifier for managing real-time messages
class ChatNotifier extends StateNotifier<ChatState> {
  final String conversationId;
  StreamSubscription<List<Message>>? _subscription;

  ChatNotifier(this.conversationId) : super(const ChatState(isLoading: true)) {
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await FirebaseService.getMessages(conversationId);
      state = state.copyWith(
        messages: messages,
        isLoading: false,
      );
      _subscribeToMessages();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load messages: $e',
      );
    }
  }

  void _subscribeToMessages() {
    _subscription?.cancel();
    _subscription = FirebaseService.subscribeToMessages(conversationId).listen(
      (messages) {
        state = state.copyWith(messages: messages);
      },
      onError: (e) {
        state = state.copyWith(error: 'Real-time subscription error: $e');
      },
    );
  }

  /// Send a message
  Future<bool> sendMessage(String content, {String? relatedBookId}) async {
    if (content.trim().isEmpty) return false;

    state = state.copyWith(isSending: true);

    try {
      final message = await FirebaseService.sendMessage(
        conversationId: conversationId,
        content: content.trim(),
        relatedBookId: relatedBookId,
      );

      // Add message locally (it will also arrive via stream, but this is faster)
      if (!state.messages.any((m) => m.id == message.id)) {
        state = state.copyWith(
          messages: [...state.messages, message],
          isSending: false,
        );
      } else {
        state = state.copyWith(isSending: false);
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: 'Failed to send message: $e',
      );
      return false;
    }
  }

  /// Refresh messages
  Future<void> refresh() async {
    await _loadMessages();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Chat provider factory
final chatProvider =
    StateNotifierProvider.autoDispose.family<ChatNotifier, ChatState, String>(
  (ref, conversationId) => ChatNotifier(conversationId),
);

/// Conversation actions
class ConversationActionsNotifier extends StateNotifier<AsyncValue<void>> {
  ConversationActionsNotifier() : super(const AsyncValue.data(null));

  /// Start a new conversation
  Future<Conversation?> startConversation({
    required String otherUserId,
    String? initialMessage,
    String? bookId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = FirebaseService.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      // Check for existing conversation
      final existingConversations = await FirebaseService.getConversations();
      final existing = existingConversations.where(
        (c) => c.otherUser?.id == otherUserId,
      ).firstOrNull;

      if (existing != null) {
        // Send initial message if provided
        if (initialMessage != null && initialMessage.isNotEmpty) {
          await FirebaseService.sendMessage(
            conversationId: existing.id,
            content: initialMessage,
            relatedBookId: bookId,
          );
        }
        state = const AsyncValue.data(null);
        return existing;
      }

      // Create new conversation
      final conversationRef = await FirebaseService.db.collection('conversations').add({
        'participantIds': [currentUser.uid, otherUserId],
        'bookId': bookId,
        'lastMessage': initialMessage,
        'lastMessageAt': DateTime.now(),
        'lastMessageSenderId': currentUser.uid,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });

      // Add participants
      await conversationRef.collection('participants').add({
        'userId': currentUser.uid,
        'unreadCount': 0,
        'createdAt': DateTime.now(),
      });

      await conversationRef.collection('participants').add({
        'userId': otherUserId,
        'unreadCount': 1,
        'createdAt': DateTime.now(),
      });

      // Send initial message if provided
      if (initialMessage != null && initialMessage.isNotEmpty) {
        await conversationRef.collection('messages').add({
          'userId': currentUser.uid,
          'content': initialMessage,
          'relatedBookId': bookId,
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        });
      }

      // Fetch the created conversation
      final conversations = await FirebaseService.getConversations();
      final newConversation = conversations.where(
        (c) => c.id == conversationRef.id,
      ).firstOrNull;

      state = const AsyncValue.data(null);
      return newConversation;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final conversationActionsProvider =
    StateNotifierProvider<ConversationActionsNotifier, AsyncValue<void>>((ref) {
  return ConversationActionsNotifier();
});
