import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class TradesScreen extends ConsumerWidget {
  const TradesScreen({super.key});

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(tradesProvider);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(tradeFilterProvider);
    final tradesAsync = ref.watch(tradesProvider);
    final currentUserId = ref.watch(currentUserProvider)?.uid;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _onRefresh(ref),
          color: AppColors.rust,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                'Trades',
                style: AppTypography.serifSemiBold.copyWith(
                  fontSize: 32,
                  letterSpacing: -0.4,
                  color: AppColors.ink,
                ),
              ),
            ),

            // Filter tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.paper3,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.line, width: 0.5),
                ),
                child: Row(
                  children: TradeFilter.values.map((f) {
                    final isSelected = f == filter;
                    final label = f == TradeFilter.all
                        ? 'All'
                        : f == TradeFilter.incoming
                            ? 'Incoming'
                            : f == TradeFilter.outgoing
                                ? 'Outgoing'
                                : 'Done';
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => ref.read(tradeFilterProvider.notifier).state = f,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.paper : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.ink.withValues(alpha: 0.12),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            label,
                            style: AppTypography.sansSemiBold.copyWith(
                              fontSize: 13,
                              color: isSelected ? AppColors.ink : AppColors.ink3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Trades list
            Expanded(
              child: tradesAsync.when(
                data: (trades) => trades.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                          _buildEmptyState(filter),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
                        itemCount: trades.length,
                        itemBuilder: (context, index) {
                          final trade = trades[index];
                          return _TradeCard(
                            trade: trade,
                            currentUserId: currentUserId ?? '',
                            onTap: () => context.push('/trade/${trade.id}'),
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
      ),
    );
  }

  Widget _buildEmptyState(TradeFilter filter) {
    String message;
    String subtitle;

    switch (filter) {
      case TradeFilter.incoming:
        message = 'No incoming trades';
        subtitle = 'Trade requests will appear here';
      case TradeFilter.outgoing:
        message = 'No outgoing trades';
        subtitle = 'Find a book and make an offer!';
      case TradeFilter.done:
        message = 'No completed trades';
        subtitle = 'Your finished trades will appear here';
      case TradeFilter.all:
        message = 'No trades yet';
        subtitle = 'Start trading to see them here';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.swap_horiz,
            size: 48,
            color: AppColors.ink3.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.serifSemiBold.copyWith(
              fontSize: 18,
              color: AppColors.ink2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
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

class _TradeCard extends StatelessWidget {
  final dynamic trade;
  final String currentUserId;
  final VoidCallback onTap;

  const _TradeCard({
    required this.trade,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncoming = trade.recipientId == currentUserId;
    final partner = trade.getPartner(currentUserId);
    final theirBooks = trade.getTheirBooks(currentUserId);
    final myBooks = trade.getMyBooks(currentUserId);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.paper2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    UserAvatar(profile: partner, size: 30),
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner?.displayName ?? 'Unknown',
                          style: AppTypography.sansBold.copyWith(
                            fontSize: 14,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          isIncoming ? 'Wants to trade' : 'You proposed',
                          style: AppTypography.sansRegular.copyWith(
                            fontSize: 11.5,
                            color: AppColors.ink3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                StatusPill(status: trade.status),
              ],
            ),
            const SizedBox(height: 14),
            // Books preview
            Row(
              children: [
                Expanded(
                  child: _BookSlot(
                    book: theirBooks.isNotEmpty ? theirBooks.first : null,
                    label: 'They give',
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.paper3,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line, width: 0.5),
                  ),
                  child: const Icon(Icons.swap_horiz, size: 18, color: AppColors.rust),
                ),
                Expanded(
                  child: _BookSlot(
                    book: myBooks.isNotEmpty ? myBooks.first : null,
                    label: 'You give',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookSlot extends StatelessWidget {
  final dynamic book;
  final String label;

  const _BookSlot({required this.book, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (book != null)
          BookCover(
            imageUrl: book.coverImgUrl,
            title: book.title,
            author: book.author,
            coverColorKey: book.coverColorKey,
            width: 38,
            borderRadius: 3,
          )
        else
          Container(
            width: 38,
            height: 57,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppColors.line, style: BorderStyle.solid),
            ),
            child: const Icon(Icons.add, size: 16, color: AppColors.ink3),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTypography.sansSemiBold.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0.5,
                  color: AppColors.ink3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                book?.title ?? 'To be chosen',
                style: AppTypography.serifSemiBold.copyWith(
                  fontSize: 13.5,
                  color: AppColors.ink,
                  height: 1.15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
