import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Conversations list provider
final conversationsProvider =
    FutureProvider.autoDispose<List<Conversation>>((ref) async {
  return SupabaseService.getConversations();
});

/// Unread messages count provider (for badge)
final unreadMessagesCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final conversations = await SupabaseService.getConversations();
  return conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
});

/// Single conversation provider
final conversationProvider =
    FutureProvider.autoDispose.family<Conversation?, String>((ref, id) async {
  final conversations = await SupabaseService.getConversations();
  return conversations.where((c) => c.id == id).firstOrNull;
});

/// Messages for a conversation
final messagesProvider =
    FutureProvider.autoDispose.family<List<Message>, String>((ref, conversationId) async {
  return SupabaseService.getMessages(conversationId);
});

/// Chat state for a conversation
class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final RealtimeChannel? subscription;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.subscription,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    RealtimeChannel? subscription,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      subscription: subscription ?? this.subscription,
    );
  }
}

/// Chat notifier for managing real-time messages
class ChatNotifier extends StateNotifier<ChatState> {
  final String conversationId;

  ChatNotifier(this.conversationId) : super(const ChatState(isLoading: true)) {
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await SupabaseService.getMessages(conversationId);
      state = state.copyWith(
        messages: messages.reversed.toList(),
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
    final channel = SupabaseService.subscribeToMessages(
      conversationId,
      (message) {
        // Check if message already exists (avoid duplicates)
        if (!state.messages.any((m) => m.id == message.id)) {
          state = state.copyWith(
            messages: [...state.messages, message],
          );
        }
      },
    );
    state = state.copyWith(subscription: channel);
  }

  /// Send a message
  Future<bool> sendMessage(String content, {String? relatedBookId}) async {
    if (content.trim().isEmpty) return false;

    state = state.copyWith(isSending: true);

    try {
      final message = await SupabaseService.sendMessage(
        conversationId: conversationId,
        content: content.trim(),
        relatedBookId: relatedBookId,
      );

      // Add message locally (it will also arrive via realtime, but this is faster)
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
    if (state.subscription != null) {
      SupabaseService.unsubscribe(state.subscription!);
    }
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
      final conversation = await SupabaseService.startConversation(
        otherUserId: otherUserId,
        initialMessage: initialMessage,
        bookId: bookId,
      );
      state = const AsyncValue.data(null);
      return conversation;
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
