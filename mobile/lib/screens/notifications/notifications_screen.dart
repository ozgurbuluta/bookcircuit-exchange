import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/router.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/providers.dart';

/// Notifications (mock #1k, spec §8): request notifications carry inline
/// Accept / Decline / Chat; amounts are always the flat 50 pts.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(notificationsProvider);

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
        title: const Text('Notifications'),
        actions: [
          itemsAsync.maybeWhen(
            data: (items) => items.any((n) => !n.read)
                ? TextButton(
                    key: const Key('mark_all_read'),
                    onPressed: () => ref
                        .read(notificationActionsProvider)
                        .markAllRead(items),
                    child: const Text('Mark all read'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('Could not load notifications.',
                style:
                    AppTypography.sansRegular.copyWith(color: AppColors.ink2)),
          ),
          data: (items) => items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_none_outlined,
                            size: 48, color: AppColors.piriMoss),
                        const SizedBox(height: 16),
                        Text(
                          'All quiet for now',
                          style: AppTypography.serifRegular.copyWith(
                            fontSize: 20,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Requests, trades and ratings will land here.',
                          textAlign: TextAlign.center,
                          style: AppTypography.sansRegular.copyWith(
                            fontSize: 13.5,
                            color: AppColors.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _NotificationCard(item: items[index]),
                ),
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final AppNotification item;

  const _NotificationCard({required this.item});

  String get _title {
    switch (item.type) {
      case NotificationType.requestReceived:
        return 'A neighbor wants a book of yours';
      case NotificationType.requestAccepted:
        return 'Your request was accepted';
      case NotificationType.requestDeclined:
        return 'Your request was declined — your ${Trade.pointsPrice} pts are back';
      case NotificationType.tradeCancelled:
        return 'A trade was cancelled';
      case NotificationType.expiryWarning:
        return 'A request expires tomorrow';
      case NotificationType.expiredRefunded:
        return 'A request expired — +${Trade.pointsPrice} pts returned';
      case NotificationType.markedSwapped:
        return 'Your neighbor marked the swap — confirm when done';
      case NotificationType.ratingReceived:
        return 'You received a rating';
      case NotificationType.newBookNearby:
        return 'A new book appeared nearby';
      case NotificationType.journalEvent:
        return 'New in the club journal';
      case NotificationType.unknown:
        return 'Something happened';
    }
  }

  void _open(BuildContext context) {
    switch (item.type) {
      case NotificationType.requestReceived:
      case NotificationType.requestAccepted:
      case NotificationType.markedSwapped:
        context.push(AppRoutes.tradeChat.replaceFirst(':id', item.refId));
        break;
      case NotificationType.ratingReceived:
        context.push(AppRoutes.shelf);
        break;
      case NotificationType.newBookNearby:
        context.push(AppRoutes.bookDetail.replaceFirst(':id', item.refId));
        break;
      case NotificationType.journalEvent:
        context.go(AppRoutes.journal);
        break;
      default:
        context.push(AppRoutes.trades);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(tradeActionsProvider.notifier);
    final notificationActions = ref.read(notificationActionsProvider);

    return GestureDetector(
      key: Key('notification_${item.id}'),
      onTap: () {
        notificationActions.markRead(item.id);
        _open(context);
      },
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: item.read ? AppColors.surface : AppColors.greenTint,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!item.read)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.honeyAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    _title,
                    style: AppTypography.sansBold.copyWith(
                      fontSize: 13.5,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Text(
                  timeago.format(item.createdAt),
                  style: AppTypography.sansRegular.copyWith(
                    fontSize: 10.5,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
            // Inline actions on request notifications (mock #1k)
            if (item.type.hasInlineActions) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      key: Key('inline_accept_${item.id}'),
                      onPressed: () async {
                        await actions.acceptTrade(item.refId);
                        await notificationActions.markRead(item.id);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      child: const Text('Accept', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: Key('inline_decline_${item.id}'),
                      onPressed: () async {
                        await actions.rejectTrade(item.refId);
                        await notificationActions.markRead(item.id);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      child:
                          const Text('Decline', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: Key('inline_chat_${item.id}'),
                      onPressed: () {
                        notificationActions.markRead(item.id);
                        context.push(AppRoutes.tradeChat
                            .replaceFirst(':id', item.refId));
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      child: const Text('Chat', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
