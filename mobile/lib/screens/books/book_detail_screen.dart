import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../config/router.dart';
import '../../models/book.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  bool _isFavorited = false;

  Future<void> _toggleFavorite() async {
    HapticFeedback.lightImpact();
    setState(() => _isFavorited = !_isFavorited);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isFavorited ? 'Added to saved books' : 'Removed from saved books',
          style: AppTypography.sansRegular.copyWith(color: Colors.white),
        ),
        backgroundColor: _isFavorited ? AppColors.sage : AppColors.ink2,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareBook(Book book) async {
    await Share.share(
      '${book.title} by ${book.author} - Available for swap on Turtle Turning Pages!',
      subject: 'Check out this book',
    );
  }

  /// Create (or reuse) a conversation with the book owner, then open the chat.
  /// We must navigate with a conversation ID, not the owner's user ID.
  Future<void> _openChat(Book book) async {
    // Capture context-bound objects before the async gap so we don't touch
    // BuildContext after awaiting.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final conversation =
        await ref.read(conversationActionsProvider.notifier).startConversation(
              otherUserId: book.userId,
              bookId: book.id,
            );

    if (conversation != null) {
      router.push('/chat/${conversation.id}?userId=${book.userId}&bookId=${book.id}');
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not open conversation. Please try again.',
            style: AppTypography.sansRegular.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.ink2,
        ),
      );
    }
  }

  Future<void> _requestBook(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Request this book?',
          style: AppTypography.serifSemiBold.copyWith(
            fontSize: 20,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          'This will send a request to ${book.owner?.displayName ?? 'the owner'} to start a trade.',
          style: AppTypography.sansRegular.copyWith(
            fontSize: 14,
            color: AppColors.ink2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTypography.sansSemiBold.copyWith(color: AppColors.ink2),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Create trade request
      final trade = await ref.read(tradeActionsProvider.notifier).createTrade(
        partnerId: book.userId,
        myBookIds: [],
        theirBookIds: [book.id],
      );

      if (trade != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Request sent to ${book.owner?.displayName ?? 'owner'}',
              style: AppTypography.sansRegular.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.sage,
          ),
        );
        context.go(AppRoutes.trades);
      }
    }
  }

  void _showOwnerMenu(Book book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.ink2),
              title: Text('Edit book', style: AppTypography.sansSemiBold.copyWith(color: AppColors.ink)),
              onTap: () {
                Navigator.pop(context);
                context.push('/edit-book/${book.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.rust),
              title: Text('Delete book', style: AppTypography.sansSemiBold.copyWith(color: AppColors.rust)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppColors.paper,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    title: Text('Delete book?', style: AppTypography.serifSemiBold.copyWith(fontSize: 20, color: AppColors.ink)),
                    content: Text('This action cannot be undone.', style: AppTypography.sansRegular.copyWith(fontSize: 14, color: AppColors.ink2)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel', style: AppTypography.sansSemiBold.copyWith(color: AppColors.ink2)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.rust),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  await ref.read(bookActionsProvider.notifier).deleteBook(book.id);
                  if (!mounted) return;
                  context.pop();
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookProvider(widget.bookId));
    final currentUserId = ref.watch(currentUserProvider)?.uid;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: bookAsync.when(
        data: (book) {
          if (book == null) {
            return const Center(child: Text('Book not found'));
          }

          final isOwner = book.userId == currentUserId;
          final colors = AppColors.covers[book.coverColorKey] ?? AppColors.covers['slate']!;

          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // App bar
                    SliverAppBar(
                      backgroundColor: AppColors.paper,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: AppColors.rust),
                        onPressed: () => context.pop(),
                      ),
                      actions: [
                        if (!isOwner) ...[
                          AppIconButton(
                            icon: _isFavorited ? Icons.favorite : Icons.favorite_outline,
                            iconColor: _isFavorited ? AppColors.rust : null,
                            onPressed: _toggleFavorite,
                          ),
                          const SizedBox(width: 4),
                        ],
                        AppIconButton(
                          icon: Icons.share_outlined,
                          onPressed: () => _shareBook(book),
                        ),
                        if (isOwner) ...[
                          const SizedBox(width: 4),
                          AppIconButton(
                            icon: Icons.more_vert,
                            onPressed: () => _showOwnerMenu(book),
                          ),
                        ],
                        const SizedBox(width: 8),
                      ],
                      pinned: true,
                    ),

                    // Hero cover
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colors.background.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 26),
                        child: Column(
                          children: [
                            Center(
                              child: BookCover(
                                imageUrl: book.coverImgUrl,
                                title: book.title,
                                author: book.author,
                                coverColorKey: book.coverColorKey,
                                width: 172,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                children: [
                                  Text(
                                    book.title,
                                    style: AppTypography.serifSemiBold.copyWith(
                                      fontSize: 26,
                                      height: 1.12,
                                      letterSpacing: -0.3,
                                      color: AppColors.ink,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    book.author,
                                    style: AppTypography.sansRegular.copyWith(
                                      fontSize: 15,
                                      color: AppColors.ink2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ConditionBadge(condition: book.condition),
                                      if (book.distanceDisplay != null) ...[
                                        const SizedBox(width: 10),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.location_on, size: 15, color: AppColors.rust),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${book.distanceDisplay} away',
                                              style: AppTypography.sansSemiBold.copyWith(
                                                fontSize: 13,
                                                color: AppColors.ink3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Owner card
                    if (!isOwner && book.owner != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GestureDetector(
                            onTap: () => _openChat(book),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.paper2,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.line, width: 0.5),
                              ),
                              child: Row(
                                children: [
                                  UserAvatar(profile: book.owner, size: 46),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          book.owner!.displayName,
                                          style: AppTypography.serifSemiBold.copyWith(
                                            fontSize: 16,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          book.owner!.formattedLocation ?? 'Location not set',
                                          style: AppTypography.sansRegular.copyWith(
                                            fontSize: 12.5,
                                            color: AppColors.ink3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.rust.withValues(alpha: 0.10),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.chat_bubble_outline, size: 19, color: AppColors.rust),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Description
                    if (book.description != null) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
                          child: SectionHeader(title: 'About this copy'),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            book.description!,
                            style: AppTypography.serifRegular.copyWith(
                              fontSize: 16,
                              height: 1.55,
                              color: AppColors.ink2,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Details
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
                        child: SectionHeader(title: 'Details'),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 2.5,
                          children: [
                            _DetailItem(label: 'Published', value: book.publicationYear?.toString() ?? '-'),
                            _DetailItem(label: 'Pages', value: book.pages?.toString() ?? '-'),
                            _DetailItem(label: 'Language', value: book.language ?? '-'),
                            _DetailItem(label: 'Publisher', value: book.publisher ?? '-'),
                          ],
                        ),
                      ),
                    ),

                    // Genres
                    if (book.genres != null && book.genres!.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(40, 16, 40, 0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: book.genres!.map((g) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.paper3,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.line, width: 0.5),
                                ),
                                child: Text(
                                  g,
                                  style: AppTypography.sansSemiBold.copyWith(
                                    fontSize: 12.5,
                                    color: AppColors.ink2,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                    // Interest count
                    if (book.interestCount != null && book.interestCount! > 0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(40, 26, 40, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.favorite_outline, size: 14, color: AppColors.ink3),
                              const SizedBox(width: 6),
                              Text(
                                '${book.interestCount} readers interested',
                                style: AppTypography.sansRegular.copyWith(
                                  fontSize: 12.5,
                                  color: AppColors.ink3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              ),

              // Action bar
              if (!isOwner)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  decoration: BoxDecoration(
                    color: AppColors.paper.withValues(alpha: 0.9),
                    border: const Border(top: BorderSide(color: AppColors.line, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          onPressed: () => context.push('/propose-swap/${widget.bookId}'),
                          isOutlined: true,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.swap_horiz, size: 19),
                              const SizedBox(width: 7),
                              const Text('Offer a swap'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          onPressed: () => _requestBook(book),
                          child: const Text('Request book'),
                        ),
                      ),
                    ],
                  ),
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

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.sansSemiBold.copyWith(
            fontSize: 11.5,
            letterSpacing: 0.6,
            color: AppColors.ink3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.serifRegular.copyWith(
            fontSize: 16,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
