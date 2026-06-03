import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? otherUserId;
  final String? bookId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.otherUserId,
    this.bookId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatNotifier = ref.read(chatProvider(widget.conversationId).notifier);
    final success = await chatNotifier.sendMessage(text);

    if (success) {
      _messageController.clear();
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.conversationId));
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final bookAsync = widget.bookId != null
        ? ref.watch(bookProvider(widget.bookId!))
        : null;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper.withValues(alpha: 0.92),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.rust),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            UserAvatar(size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chat',
                    style: AppTypography.serifSemiBold.copyWith(
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    'Active now',
                    style: AppTypography.sansSemiBold.copyWith(
                      fontSize: 11.5,
                      color: AppColors.sage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Book context card
          if (bookAsync != null)
            bookAsync.when(
              data: (book) => book != null
                  ? GestureDetector(
                      onTap: () => context.push('/book/${book.id}'),
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.paper2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.line, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            BookCover(
                              imageUrl: book.coverImgUrl,
                              title: book.title,
                              author: book.author,
                              width: 40,
                              borderRadius: 4,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ABOUT THIS BOOK',
                                    style: AppTypography.sansBold.copyWith(
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                      color: AppColors.ink3,
                                    ),
                                  ),
                                  Text(
                                    book.title,
                                    style: AppTypography.serifSemiBold.copyWith(
                                      fontSize: 15,
                                      color: AppColors.ink,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            ConditionBadge(condition: book.condition, small: true),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

          // Messages
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatState.messages[index];
                      final isMe = message.userId == currentUserId;
                      return _MessageBubble(
                        message: message,
                        isMe: isMe,
                      );
                    },
                  ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: const BoxDecoration(
              color: AppColors.paper,
              border: Border(top: BorderSide(color: AppColors.line, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.paper3,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.line, width: 0.5),
                    ),
                    child: const Icon(Icons.camera_alt_outlined, size: 20, color: AppColors.ink2),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.paper2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.line, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              onSubmitted: (_) => _sendMessage(),
                              decoration: InputDecoration(
                                hintText: 'Message...',
                                hintStyle: AppTypography.sansRegular.copyWith(
                                  fontSize: 14.5,
                                  color: AppColors.ink3,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                              ),
                              style: AppTypography.sansRegular.copyWith(
                                fontSize: 14.5,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: _messageController.text.trim().isNotEmpty
                                    ? AppColors.rust
                                    : AppColors.paper3,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.send,
                                size: 16,
                                color: _messageController.text.trim().isNotEmpty
                                    ? Colors.white
                                    : AppColors.ink3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final dynamic message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: isMe
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.rust, Color(0xFF9A3F22)],
                  )
                : null,
            color: isMe ? null : AppColors.paper2,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 5),
              bottomRight: Radius.circular(isMe ? 5 : 18),
            ),
            border: isMe ? null : Border.all(color: AppColors.line, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.06),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            message.content,
            style: AppTypography.sansRegular.copyWith(
              fontSize: 14.5,
              height: 1.4,
              color: isMe ? AppColors.paper2 : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
