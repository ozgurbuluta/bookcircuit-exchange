import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/points_badge.dart';

/// Trade request sheet (mock #2b, spec §4): offer a flat 50 pts or exactly
/// one of your on-shelf books, add an optional note, send. Points are
/// escrowed the moment the request is sent.
Future<Trade?> showTradeRequestSheet(BuildContext context, Book book) {
  return showModalBottomSheet<Trade>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => TradeRequestSheet(book: book),
  );
}

class TradeRequestSheet extends ConsumerStatefulWidget {
  final Book book;

  const TradeRequestSheet({super.key, required this.book});

  @override
  ConsumerState<TradeRequestSheet> createState() => _TradeRequestSheetState();
}

class _TradeRequestSheetState extends ConsumerState<TradeRequestSheet> {
  final _noteController = TextEditingController();
  TradeOffer _offer = TradeOffer.points50;
  String? _offeredBookId;
  bool _sending = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final trade = await ref.read(tradeActionsProvider.notifier).createRequest(
          bookId: widget.book.id,
          offer: _offer,
          offeredBookId: _offeredBookId,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _sending = false);

    if (trade != null) {
      ref.invalidate(tradesProvider);
      ref.read(authProvider.notifier).refreshProfile();
      Navigator.of(context).pop(trade);
    } else {
      final error = ref.read(tradeActionsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TradeActionsNotifier.describeError(error.error)),
          backgroundColor: AppColors.terracotta,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final myBooksAsync = ref.watch(myBooksProvider);
    final points = profile?.points ?? 0;

    final myOnShelf = myBooksAsync.maybeWhen(
      data: (books) =>
          books.where((b) => b.status == BookStatus.onShelf).toList(),
      orElse: () => const <Book>[],
    );

    final canAffordPoints = points >= Trade.pointsPrice;
    final hasBooksToOffer = myOnShelf.isNotEmpty;
    // Spec §4.10: neither points nor books → disabled with hint
    final blocked = !canAffordPoints && !hasBooksToOffer;

    final canSend = !_sending &&
        !blocked &&
        (_offer == TradeOffer.points50
            ? canAffordPoints
            : _offeredBookId != null);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Book preview
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 64,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: 68,
                        height: 98,
                        child: BookCover(
                          title: widget.book.title,
                          author: widget.book.author,
                          coverColorKey: widget.book.coverColorKey,
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
                          widget.book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.sansExtraBold.copyWith(
                            fontSize: 16,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          widget.book.author,
                          style: AppTypography.sansRegular.copyWith(
                            fontSize: 12.5,
                            color: AppColors.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PointsBadge(points: points),
                ],
              ),
              const SizedBox(height: 20),
              if (blocked) ...[
                Container(
                  key: const Key('blocked_hint'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.neutralTint,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    'Shelve a book to earn points',
                    textAlign: TextAlign.center,
                    style: AppTypography.sansBold.copyWith(
                      fontSize: 13.5,
                      color: AppColors.ink2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Text(
                  'Your offer',
                  style: AppTypography.sansSemiBold.copyWith(
                    fontSize: 12.5,
                    color: AppColors.ink2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _OfferOption(
                        key: const Key('offer_points'),
                        title: '${Trade.pointsPrice} pts',
                        subtitle: canAffordPoints
                            ? 'held until the swap'
                            : 'not enough points',
                        selected: _offer == TradeOffer.points50,
                        enabled: canAffordPoints,
                        onTap: () => setState(() {
                          _offer = TradeOffer.points50;
                          _offeredBookId = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OfferOption(
                        key: const Key('offer_book'),
                        title: 'One of my books',
                        subtitle: hasBooksToOffer
                            ? '${myOnShelf.length} on your shelf'
                            : 'nothing on your shelf',
                        selected: _offer == TradeOffer.book,
                        enabled: hasBooksToOffer,
                        onTap: () => setState(() => _offer = TradeOffer.book),
                      ),
                    ),
                  ],
                ),
                if (_offer == TradeOffer.book) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 108,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: myOnShelf.length,
                      itemBuilder: (context, index) {
                        final book = myOnShelf[index];
                        final selected = _offeredBookId == book.id;
                        return GestureDetector(
                          key: Key('pick_${book.id}'),
                          onTap: () =>
                              setState(() => _offeredBookId = book.id),
                          child: Container(
                            width: 64,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selected
                                    ? AppColors.green
                                    : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: BookCover(
                              title: book.title,
                              author: book.author,
                              coverColorKey: book.coverColorKey,
                              width: 60,
                              height: 104,
                              showShadow: false,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  key: const Key('note_field'),
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'A note for the owner (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                if (_offer == TradeOffer.points50)
                  Text(
                    key: const Key('escrow_copy'),
                    '${Trade.pointsPrice} pts are held when you send — returned in full if the trade is cancelled or declined.',
                    style: AppTypography.sansRegular.copyWith(
                      fontSize: 11.5,
                      color: AppColors.ink3,
                      height: 1.45,
                    ),
                  ),
                const SizedBox(height: 14),
              ],
              ElevatedButton(
                key: const Key('send_request'),
                onPressed: canSend ? _send : null,
                child: Text(
                  _sending
                      ? 'Sending…'
                      : _offer == TradeOffer.points50
                          ? 'Send request · ${Trade.pointsPrice} pts'
                          : 'Send request',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _OfferOption({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected ? AppColors.greenTint : AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.green : AppColors.line,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.sansExtraBold.copyWith(
                  fontSize: 14,
                  color: selected ? AppColors.green : AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.sansRegular.copyWith(
                  fontSize: 11,
                  color: AppColors.ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
