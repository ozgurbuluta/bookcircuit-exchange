import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class TradeDetailScreen extends ConsumerWidget {
  final String tradeId;

  const TradeDetailScreen({super.key, required this.tradeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradeAsync = ref.watch(tradeProvider(tradeId));
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.rust),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Trade',
          style: AppTypography.serifSemiBold.copyWith(fontSize: 18, color: AppColors.ink),
        ),
        centerTitle: true,
      ),
      body: tradeAsync.when(
        data: (trade) {
          if (trade == null) {
            return const Center(child: Text('Trade not found'));
          }

          final partner = trade.getPartner(currentUserId);
          final isIncoming = trade.isIncoming(currentUserId);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Status
                      Center(child: StatusPill(status: trade.status)),
                      const SizedBox(height: 20),

                      // Swap visualization
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.paper2,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.line, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _SwapColumn(
                                label: '${partner?.displayName.split(' ').first ?? 'They'} gives',
                                book: trade.getTheirBooks(currentUserId).firstOrNull,
                              ),
                            ),
                            Container(
                              width: 46,
                              height: 46,
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.rust, AppColors.rust2],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.rust.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.swap_horiz, size: 22, color: Colors.white),
                            ),
                            Expanded(
                              child: _SwapColumn(
                                label: 'You give',
                                book: trade.getMyBooks(currentUserId).firstOrNull,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Message
                      if (trade.initiatorMessage != null) ...[
                        const SizedBox(height: 26),
                        SectionHeader(title: 'Message'),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UserAvatar(
                              profile: isIncoming ? partner : null,
                              size: 34,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.paper2,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                  border: Border.all(color: AppColors.line, width: 0.5),
                                ),
                                child: Text(
                                  trade.initiatorMessage!,
                                  style: AppTypography.serifRegular.copyWith(
                                    fontSize: 15.5,
                                    height: 1.5,
                                    color: AppColors.ink2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              _TradeActions(
                trade: trade,
                isIncoming: isIncoming,
                onAction: (action) async {
                  final notifier = ref.read(tradeActionsProvider.notifier);
                  bool success = false;
                  switch (action) {
                    case 'accept':
                      success = await notifier.acceptTrade(tradeId);
                      break;
                    case 'reject':
                      success = await notifier.rejectTrade(tradeId);
                      break;
                    case 'cancel':
                      success = await notifier.cancelTrade(tradeId);
                      break;
                    case 'complete':
                      success = await notifier.completeTrade(tradeId);
                      break;
                    case 'message':
                      if (partner != null) {
                        context.push('/chat/new?userId=${partner.id}');
                      }
                      return;
                  }
                  if (success) {
                    ref.invalidate(tradeProvider(tradeId));
                    ref.invalidate(tradesProvider);
                  }
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _SwapColumn extends StatelessWidget {
  final String label;
  final dynamic book;

  const _SwapColumn({required this.label, this.book});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.sansBold.copyWith(
            fontSize: 11,
            letterSpacing: 0.6,
            color: AppColors.ink3,
          ),
        ),
        const SizedBox(height: 10),
        if (book != null)
          BookCover(
            imageUrl: book.coverImgUrl,
            title: book.title,
            author: book.author,
            coverColorKey: book.coverColorKey,
            width: 96,
          )
        else
          Container(
            width: 96,
            height: 144,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.line, width: 1.5, style: BorderStyle.solid),
            ),
            child: const Icon(Icons.add, size: 22, color: AppColors.ink3),
          ),
        const SizedBox(height: 10),
        Text(
          book?.title ?? 'To be chosen',
          style: AppTypography.serifSemiBold.copyWith(
            fontSize: 14,
            color: AppColors.ink,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (book != null) ...[
          const SizedBox(height: 5),
          ConditionBadge(condition: book.condition, small: true),
        ],
      ],
    );
  }
}

class _TradeActions extends StatelessWidget {
  final dynamic trade;
  final bool isIncoming;
  final Function(String) onAction;

  const _TradeActions({
    required this.trade,
    required this.isIncoming,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.9),
        border: const Border(top: BorderSide(color: AppColors.line, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isIncoming && (trade.status.value == 'pending' || trade.status.value == 'request_pending')) ...[
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    onPressed: () => onAction('reject'),
                    isOutlined: true,
                    isDanger: true,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    onPressed: () => onAction('accept'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, size: 19),
                        const SizedBox(width: 7),
                        const Text('Accept trade'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ] else if (!isIncoming && (trade.status.value == 'pending' || trade.status.value == 'request_pending')) ...[
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    onPressed: () => onAction('cancel'),
                    isOutlined: true,
                    isDanger: true,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    onPressed: () => onAction('message'),
                    isOutlined: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 19),
                        const SizedBox(width: 7),
                        const Text('Message'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else if (trade.status.value == 'accepted') ...[
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    onPressed: () => onAction('message'),
                    isOutlined: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 19),
                        const SizedBox(width: 7),
                        const Text('Message'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    onPressed: () => onAction('complete'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, size: 19),
                        const SizedBox(width: 7),
                        const Text('Mark complete'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            AppButton(
              onPressed: () => onAction('message'),
              isOutlined: true,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 19),
                  const SizedBox(width: 7),
                  const Text('Message'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
