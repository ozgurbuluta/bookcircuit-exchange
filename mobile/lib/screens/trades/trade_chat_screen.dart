import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/router.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/firebase_service.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/system_message_pill.dart';

/// Messages stream for a trade thread (spec §9).
final tradeMessagesProvider =
    StreamProvider.autoDispose.family<List<Message>, String>((ref, tradeId) {
  return FirebaseService.db
      .collection('trades')
      .doc(tradeId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Message.fromFirestore(doc.data(), doc.id))
          .toList());
});

/// Trade chat (mock #2d): header trade card with status + actions, user
/// bubbles, system events as honey pills, quick replies (spec §9).
class TradeChatScreen extends ConsumerStatefulWidget {
  final String tradeId;

  const TradeChatScreen({super.key, required this.tradeId});

  @override
  ConsumerState<TradeChatScreen> createState() => _TradeChatScreenState();
}

class _TradeChatScreenState extends ConsumerState<TradeChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  static const _quickReplies = ['Share meeting spot', 'Running late'];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _messageController.text).trim();
    if (text.isEmpty) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    _messageController.clear();
    await FirebaseService.db
        .collection('trades')
        .doc(widget.tradeId)
        .collection('messages')
        .add({
      'senderId': uid,
      'text': text,
      'type': MessageType.user.value,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final tradeAsync = ref.watch(tradeProvider(widget.tradeId));
    final messagesAsync = ref.watch(tradeMessagesProvider(widget.tradeId));
    final currentUserId = ref.watch(currentUserProvider)?.uid ?? '';

    ref.listen<AsyncValue<void>>(tradeActionsProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TradeActionsNotifier.describeError(next.error)),
            backgroundColor: AppColors.terracotta,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: tradeAsync.maybeWhen(
          data: (trade) => Text(
              trade?.getPartner(currentUserId)?.displayName ?? 'Trade chat'),
          orElse: () => const Text('Trade chat'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header trade card (mock #2d)
            tradeAsync.maybeWhen(
              data: (trade) => trade == null
                  ? const SizedBox.shrink()
                  : _TradeHeaderCard(
                      trade: trade,
                      currentUserId: currentUserId,
                      onChanged: () {
                        ref.invalidate(tradeProvider(widget.tradeId));
                        ref.invalidate(tradesProvider);
                      },
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            Expanded(
              child: messagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Text('Could not load messages.',
                      style: AppTypography.sansRegular
                          .copyWith(color: AppColors.ink2)),
                ),
                data: (messages) => ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    if (message.isSystem) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: SystemMessagePill(text: message.text),
                      );
                    }
                    final isMe = message.senderId == currentUserId;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.green : AppColors.surface,
                          border: isMe
                              ? null
                              : Border.all(color: AppColors.line),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 5),
                            bottomRight: Radius.circular(isMe ? 5 : 16),
                          ),
                        ),
                        child: Text(
                          message.text,
                          style: AppTypography.sansRegular.copyWith(
                            fontSize: 13.5,
                            height: 1.4,
                            color: isMe
                                ? AppColors.sentBubbleText
                                : AppColors.ink,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Quick replies (spec §9)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _quickReplies
                    .map((reply) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            key: Key('quick_$reply'),
                            onTap: () => _send(reply),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 13, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                reply,
                                style: AppTypography.sansBold.copyWith(
                                  fontSize: 12,
                                  color: AppColors.green,
                                ),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            // Composer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('chat_input'),
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          const InputDecoration(hintText: 'Write a message'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    key: const Key('chat_send'),
                    onTap: _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward,
                          color: AppColors.bg, size: 20),
                    ),
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

class _TradeHeaderCard extends ConsumerWidget {
  final Trade trade;
  final String currentUserId;
  final VoidCallback onChanged;

  const _TradeHeaderCard({
    required this.trade,
    required this.currentUserId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(tradeActionsProvider.notifier);
    final iConfirmed = trade.hasConfirmedSwap(currentUserId);
    final partnerFirst =
        trade.getPartner(currentUserId)?.displayName.split(' ').first;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trade.book?.title ?? 'Book'} · ${trade.offer == TradeOffer.points50 ? '${Trade.pointsPrice} pts' : 'book for book'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.sansBold.copyWith(
                    fontSize: 12.5,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                StatusChip(status: trade.status.value),
              ],
            ),
          ),
          if (trade.status == TradeStatus.accepted) ...[
            if (!iConfirmed)
              ElevatedButton(
                key: const Key('header_swap'),
                onPressed: () async {
                  final result = await actions.confirmSwap(trade.id);
                  onChanged();
                  if (result != null && result.completed && context.mounted) {
                    context.push(
                        AppRoutes.rateSwap.replaceFirst(':id', trade.id));
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Mark as swapped',
                    style: TextStyle(fontSize: 12)),
              )
            else
              Text(
                'Waiting for ${partnerFirst ?? 'them'}',
                style: AppTypography.sansSemiBold.copyWith(
                  fontSize: 11,
                  color: AppColors.honeyDeep,
                ),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              key: const Key('header_cancel'),
              onTap: () async {
                await actions.cancelTrade(trade.id);
                onChanged();
              },
              child: Text(
                'Cancel trade',
                style: AppTypography.sansExtraBold.copyWith(
                  fontSize: 11.5,
                  color: AppColors.terracotta,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
