import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/router.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/firebase_service.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/status_chip.dart';

/// A trade thread row for the chat list: the trade + its latest message.
class TradeThread {
  final Trade trade;
  final Message? lastMessage;

  const TradeThread({required this.trade, this.lastMessage});

  DateTime get lastActivity =>
      lastMessage?.createdAt ?? trade.updatedAt ?? trade.requestedAt;
}

/// Chat list (mock #1i, spec §9): threads exist only per trade. Sorted by
/// most recent activity. No price talk in previews — there is nothing to
/// negotiate in v1.
final tradeThreadsProvider =
    FutureProvider.autoDispose<List<TradeThread>>((ref) async {
  final trades = await FirebaseService.getUserTrades();

  final threads = <TradeThread>[];
  for (final trade in trades) {
    final lastSnap = await FirebaseService.db
        .collection('trades')
        .doc(trade.id)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    threads.add(TradeThread(
      trade: trade,
      lastMessage: lastSnap.docs.isEmpty
          ? null
          : Message.fromFirestore(
              lastSnap.docs.first.data(), lastSnap.docs.first.id),
    ));
  }

  threads.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
  return threads;
});

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(tradeThreadsProvider);
    final currentUserId = ref.watch(currentUserProvider)?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Chats')),
      body: SafeArea(
        child: threadsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text(
              'Could not load chats. Pull to retry.',
              style:
                  AppTypography.sansRegular.copyWith(color: AppColors.ink2),
            ),
          ),
          data: (threads) => threads.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            size: 44, color: AppColors.piriMoss),
                        const SizedBox(height: 12),
                        Text(
                          'Chats live inside trades. Ask for a book and the conversation starts here.',
                          textAlign: TextAlign.center,
                          style: AppTypography.sansRegular.copyWith(
                            fontSize: 13.5,
                            color: AppColors.ink2,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(tradeThreadsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: threads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _ThreadRow(
                      thread: threads[index],
                      currentUserId: currentUserId,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  final TradeThread thread;
  final String currentUserId;

  const _ThreadRow({required this.thread, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final trade = thread.trade;
    final partner = trade.getPartner(currentUserId);
    final book = trade.book;
    final last = thread.lastMessage;

    return GestureDetector(
      key: Key('thread_${trade.id}'),
      onTap: () =>
          context.push(AppRoutes.tradeChat.replaceFirst(':id', trade.id)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            if (book != null)
              SizedBox(
                width: 36,
                height: 52,
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: 68,
                    height: 98,
                    child: BookCover(
                      title: book.title,
                      author: book.author,
                      coverColorKey: book.coverColorKey,
                      showShadow: false,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          partner?.displayName ?? 'Neighbor',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.sansExtraBold.copyWith(
                            fontSize: 14,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Text(
                        timeago.format(thread.lastActivity),
                        style: AppTypography.sansRegular.copyWith(
                          fontSize: 10.5,
                          color: AppColors.ink3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    last == null
                        ? (book?.title ?? 'New trade')
                        : last.isSystem
                            ? last.text
                            : last.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sansRegular.copyWith(
                      fontSize: 12.5,
                      color: AppColors.ink2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  StatusChip(status: trade.status.value),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
