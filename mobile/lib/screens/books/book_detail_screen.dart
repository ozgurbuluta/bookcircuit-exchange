import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../config/theme.dart';
import '../../config/router.dart';
import '../../config/env.dart';
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

  /// Hero cover that shows the full book image (no cropping). Falls back to the
  /// generated cover when there's no image URL.
  Widget _buildHeroCover(Book book) {
    if (book.coverImgUrl != null && book.coverImgUrl!.isNotEmpty) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 280, maxWidth: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: book.coverImgUrl!,
            fit: BoxFit.contain,
            placeholder: (_, __) => BookCover(
              title: book.title,
              author: book.author,
              coverColorKey: book.coverColorKey,
              width: 172,
              showShadow: false,
            ),
            errorWidget: (_, __, ___) => BookCover(
              title: book.title,
              author: book.author,
              coverColorKey: book.coverColorKey,
              width: 172,
              showShadow: false,
            ),
          ),
        ),
      );
    }
    return BookCover(
      title: book.title,
      author: book.author,
      coverColorKey: book.coverColorKey,
      width: 172,
    );
  }

  /// Haversine distance in kilometers.
  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<void> _shareBook(Book book) async {
    final message =
        'Check what I currently have in my library!\n\n'
        '"${book.title}" by ${book.author}\n\n'
        'Are you interested in a trade?\n\n'
        'Check Turtle Turning Pages for more information: ${Env.webUrl}';

    try {
      if (book.coverImgUrl != null && book.coverImgUrl!.isNotEmpty) {
        final response = await http.get(Uri.parse(book.coverImgUrl!));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/book_cover.jpg');
          await file.writeAsBytes(response.bodyBytes);

          await Share.shareXFiles(
            [XFile(file.path)],
            text: message,
            subject: '${book.title} - Turtle Turning Pages',
          );
          return;
        }
      }
    } catch (e) {
      // Fall back to text-only share
    }

    // Text-only share if image unavailable
    await Share.share(
      message,
      subject: '${book.title} - Turtle Turning Pages',
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
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);

      // Create trade request
      final trade = await ref.read(tradeActionsProvider.notifier).createTrade(
        partnerId: book.userId,
        myBookIds: [],
        theirBookIds: [book.id],
      );

      if (trade != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Request sent to ${book.owner?.displayName ?? 'owner'}',
              style: AppTypography.sansRegular.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.sage,
          ),
        );
        router.go(AppRoutes.trades);
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

          // Distance from the viewer to the book (single-book fetches don't
          // carry a precomputed distance, so derive it here).
          final myLocation = ref.watch(currentLocationProvider).valueOrNull;
          String? distanceLabel = book.distanceDisplay;
          if (distanceLabel == null &&
              myLocation != null &&
              book.locationLat != null &&
              book.locationLng != null) {
            final km = _distanceKm(
              myLocation.lat,
              myLocation.lng,
              book.locationLat!,
              book.locationLng!,
            );
            distanceLabel = '${km.toStringAsFixed(1)} km';
          }

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
                              child: _buildHeroCover(book),
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
                                      if (distanceLabel != null) ...[
                                        const SizedBox(width: 10),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.location_on, size: 15, color: AppColors.rust),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$distanceLabel away',
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

