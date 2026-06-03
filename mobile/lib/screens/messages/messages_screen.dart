import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Messages',
                    style: AppTypography.serifSemiBold.copyWith(
                      fontSize: 32,
                      letterSpacing: -0.4,
                      color: AppColors.ink,
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.edit_outlined,
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Conversations list
            Expanded(
              child: conversationsAsync.when(
                data: (conversations) => conversations.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final conv = conversations[index];
                          return _ConversationTile(
                            conversation: conv,
                            onTap: () => context.push('/chat/${conv.id}'),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 34, color: AppColors.ink3),
          const SizedBox(height: 12),
          Text(
            'No messages yet',
            style: AppTypography.serifSemiBold.copyWith(
              fontSize: 17,
              color: AppColors.ink2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start a conversation from a book page',
            style: AppTypography.sansRegular.copyWith(
              fontSize: 13.5,
              color: AppColors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final dynamic conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final otherUser = conversation.otherUser;
    final hasUnread = conversation.unreadCount > 0;
    final lastMessageTime = conversation.lastMessageAt != null
        ? timeago.format(conversation.lastMessageAt!)
        : '';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line2, width: 0.5)),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar(profile: otherUser, size: 50),
                if (conversation.book != null)
                  Positioned(
                    bottom: -3,
                    right: -4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.paper, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: BookCover(
                          imageUrl: conversation.book?.coverImgUrl,
                          title: conversation.book?.title ?? '',
                          author: conversation.book?.author ?? '',
                          width: 18,
                          borderRadius: 0,
                          showShadow: false,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          otherUser?.displayName ?? 'Unknown',
                          style: AppTypography.serifSemiBold.copyWith(
                            fontSize: 16,
                            color: AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        lastMessageTime,
                        style: AppTypography.sansRegular.copyWith(
                          fontSize: 12,
                          color: hasUnread ? AppColors.rust : AppColors.ink3,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (conversation.book != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        're: ${conversation.book!.title}',
                        style: AppTypography.sansRegular.copyWith(
                          fontSize: 11.5,
                          color: AppColors.ink3,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage ?? '',
                          style: AppTypography.sansRegular.copyWith(
                            fontSize: 13.5,
                            color: hasUnread ? AppColors.ink : AppColors.ink2,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          decoration: BoxDecoration(
                            color: AppColors.rust,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Center(
                            child: Text(
                              conversation.unreadCount.toString(),
                              style: AppTypography.sansBold.copyWith(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
