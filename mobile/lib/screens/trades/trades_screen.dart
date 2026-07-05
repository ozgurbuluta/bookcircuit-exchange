import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/router.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/status_chip.dart';

/// My trades (mock #2c): active vs completed, one card per trade with the
/// offer, status, expiry countdown, and the right actions for your role.
class TradesScreen extends ConsumerWidget {
  const TradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(tradeFilterProvider);
    final tradesAsync = ref.watch(tradesProvider);
    final currentUserId = ref.watch(currentUserProvider)?.uid;

    ref.listen<AsyncValue<void>>(tradeActionsProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(TradeActionsNotifier.describeError(next.error)),
            backgroundColor: AppColors.terracotta,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('My trades')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  _FilterTab(
                    key: const Key('trades_active'),
                    label: 'Active',
                    selected: filter == TradeFilter.active,
                    onTap: () => ref
                        .read(tradeFilterProvider.notifier)
                        .state = TradeFilter.active,
                  ),
                  const SizedBox(width: 8),
                  _FilterTab(
                    key: const Key('trades_done'),
                    label: 'Completed',
                    selected: filter == TradeFilter.done,
                    onTap: () => ref
                        .read(tradeFilterProvider.notifier)
                        .state = TradeFilter.done,
                  ),
                ],
              ),
            ),
            Expanded(
              child: tradesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Could not load trades. Pull to retry.',
                    style: AppTypography.sansRegular
                        .copyWith(color: AppColors.ink2),
                  ),
                ),
                data: (trades) => trades.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.swap_horiz,
                                  size: 44, color: AppColors.piriMoss),
                              const SizedBox(height: 12),
                              Text(
                                filter == TradeFilter.active
                                    ? 'No trades under way. Ask for a book you like — 50 pts, flat.'
                                    : 'Completed trades will gather here.',
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
                        onRefresh: () async => ref.invalidate(tradesProvider),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: trades.length,
                          itemBuilder: (context, index) => _TradeCard(
                            trade: trades[index],
                            currentUserId: currentUserId ?? '',
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.greenTint : AppColors.surface,
          border: Border.all(
              color: selected ? AppColors.green : AppColors.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTypography.sansBold.copyWith(
            fontSize: 13,
            color: selected ? AppColors.green : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

class _TradeCard extends ConsumerWidget {
  final Trade trade;
  final String currentUserId;

  const _TradeCard({required this.trade, required this.currentUserId});

  bool get _isOwner => trade.ownerId == currentUserId;

  String? _expiryLabel() {
    if (trade.status != TradeStatus.requested) return null;
    final expiresAt = trade.requestedAt.add(Trade.expiryWindow);
    final left = expiresAt.difference(DateTime.now());
    if (left.isNegative) return 'expiring';
    if (left.inDays >= 1) return 'expires in ${left.inDays}d';
    return 'expires in ${left.inHours}h';
  }

  Future<bool> _confirm(
      BuildContext context, String title, String body) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        title: Text(title,
            style:
                AppTypography.sansExtraBold.copyWith(color: AppColors.ink)),
        content: Text(body,
            style: AppTypography.sansRegular
                .copyWith(color: AppColors.ink2, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, cancel',
                style: AppTypography.sansBold
                    .copyWith(color: AppColors.terracotta)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = trade.book;
    final partner = trade.getPartner(currentUserId);
    final expiry = _expiryLabel();
    final actions = ref.read(tradeActionsProvider.notifier);

    final iConfirmed = trade.hasConfirmedSwap(currentUserId);
    final waitingOnOther =
        trade.status == TradeStatus.accepted && iConfirmed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (book != null)
                SizedBox(
                  width: 38,
                  height: 54,
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
                    Text(
                      book?.title ?? 'Book',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sansExtraBold.copyWith(
                        fontSize: 14.5,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        _isOwner
                            ? '${partner?.displayName ?? 'A neighbor'} asked'
                            : 'You asked ${partner?.displayName ?? 'the owner'}',
                        trade.offer == TradeOffer.points50
                            ? '${Trade.pointsPrice} pts'
                            : 'book for book',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sansRegular.copyWith(
                        fontSize: 12,
                        color: AppColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(status: trade.status.value),
                  if (expiry != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      expiry,
                      style: AppTypography.sansSemiBold.copyWith(
                        fontSize: 10,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (trade.offer == TradeOffer.points50 &&
              trade.status == TradeStatus.requested &&
              !_isOwner) ...[
            const SizedBox(height: 8),
            Text(
              'You sent ${Trade.pointsPrice} pts — returned if cancelled',
              style: AppTypography.sansRegular.copyWith(
                fontSize: 11,
                color: AppColors.ink3,
              ),
            ),
          ],
          if (waitingOnOther) ...[
            const SizedBox(height: 8),
            Text(
              key: const Key('waiting_confirm'),
              'Waiting for ${partner?.displayName.split(' ').first ?? 'them'} to confirm the swap',
              style: AppTypography.sansSemiBold.copyWith(
                fontSize: 12,
                color: AppColors.honeyDeep,
              ),
            ),
          ],
          if (!trade.status.isTerminal) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_isOwner && trade.status == TradeStatus.requested) ...[
                  Expanded(
                    child: ElevatedButton(
                      key: Key('accept_${trade.id}'),
                      onPressed: () async {
                        await actions.acceptTrade(trade.id);
                        ref.invalidate(tradesProvider);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: Key('decline_${trade.id}'),
                      onPressed: () async {
                        await actions.rejectTrade(trade.id);
                        ref.invalidate(tradesProvider);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                ],
                if (trade.status == TradeStatus.accepted && !iConfirmed) ...[
                  Expanded(
                    child: ElevatedButton(
                      key: Key('swap_${trade.id}'),
                      onPressed: () async {
                        final result = await actions.confirmSwap(trade.id);
                        ref.invalidate(tradesProvider);
                        if (result != null &&
                            result.completed &&
                            context.mounted) {
                          context.push(
                              AppRoutes.rateSwap.replaceFirst(':id', trade.id));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Mark as swapped'),
                    ),
                  ),
                ],
                if (trade.status == TradeStatus.accepted ||
                    (!_isOwner && trade.status == TradeStatus.requested)) ...[
                  if (trade.status == TradeStatus.accepted)
                    const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: Key('cancel_${trade.id}'),
                      onPressed: () async {
                        final sure = await _confirm(
                          context,
                          'Cancel this trade?',
                          trade.escrowed
                              ? 'The held ${Trade.pointsPrice} pts go straight back.'
                              : 'Both books go back on their shelves.',
                        );
                        if (!sure) return;
                        await actions.cancelTrade(trade.id);
                        ref.invalidate(tradesProvider);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        foregroundColor: AppColors.terracotta,
                      ),
                      child: Text(trade.status == TradeStatus.requested
                          ? 'Cancel request'
                          : 'Cancel'),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                OutlinedButton(
                  key: Key('chat_${trade.id}'),
                  onPressed: () => context.push(
                      AppRoutes.tradeChat.replaceFirst(':id', trade.id)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                  ),
                  child: const Icon(Icons.chat_bubble_outline, size: 16),
                ),
              ],
            ),
          ],
          if (trade.status == TradeStatus.swapped) ...[
            const SizedBox(height: 10),
            GestureDetector(
              key: Key('rate_${trade.id}'),
              onTap: () => context
                  .push(AppRoutes.rateSwap.replaceFirst(':id', trade.id)),
              child: Text(
                'Rate the swap',
                style: AppTypography.sansBold.copyWith(
                  fontSize: 12.5,
                  color: AppColors.green,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
