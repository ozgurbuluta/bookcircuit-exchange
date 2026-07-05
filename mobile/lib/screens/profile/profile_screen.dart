import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/router.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/points_badge.dart';
import '../../widgets/rating_stars.dart';

enum _ShelfFilter { onShelf, inTrade }

/// My shelf (mock #1h): profile header with rating + stats, then the book
/// grid with "In trade" overlays and per-book visibility toggles.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  _ShelfFilter _filter = _ShelfFilter.onShelf;

  Future<void> _toggleVisibility(Book book) async {
    final updated = book.copyWith(visible: !book.visible);
    await ref.read(bookActionsProvider.notifier).updateBook(updated);
    ref.invalidate(myBooksProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final booksAsync = ref.watch(myBooksProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('My shelf'),
        actions: [
          IconButton(
            key: const Key('shelf_settings'),
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myBooksProvider);
            await ref.read(authProvider.notifier).refreshProfile();
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (profile != null) _ProfileHeader(profile: profile),
              const SizedBox(height: 20),
              booksAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'Could not load your shelf. Pull to retry.',
                      style: AppTypography.sansRegular
                          .copyWith(color: AppColors.ink2),
                    ),
                  ),
                ),
                data: (books) => _ShelfBody(
                  books: books,
                  filter: _filter,
                  onFilterChanged: (f) => setState(() => _filter = f),
                  onToggleVisibility: _toggleVisibility,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.ink2),
              title: Text('Edit profile',
                  style:
                      AppTypography.sansSemiBold.copyWith(color: AppColors.ink)),
              onTap: () {
                Navigator.pop(ctx);
                context.push(AppRoutes.editProfile);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.logout_outlined, color: AppColors.terracotta),
              title: Text('Sign out',
                  style: AppTypography.sansSemiBold
                      .copyWith(color: AppColors.terracotta)),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(authProvider.notifier).signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  final Profile profile;

  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberSince = profile.createdAt != null
        ? DateFormat('MMMM yyyy').format(profile.createdAt!)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.greenTint,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    profile.avatarInitials,
                    style: AppTypography.sansExtraBold.copyWith(
                      fontSize: 18,
                      color: AppColors.green,
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
                      profile.displayName,
                      style: AppTypography.sansExtraBold.copyWith(
                        fontSize: 17,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (profile.areaLabel != null) profile.areaLabel!,
                        if (memberSince != null) 'member since $memberSince',
                      ].join(' · '),
                      style: AppTypography.sansRegular.copyWith(
                        fontSize: 12,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              PointsBadge(
                points: profile.points,
                onTap: () => context.push(AppRoutes.trades),
              ),
            ],
          ),
          if (profile.ratingCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              key: const Key('shelf_rating'),
              children: [
                RatingStars(rating: profile.ratingAvg.round(), size: 16),
                const SizedBox(width: 8),
                Text(
                  '${profile.ratingAvg.toStringAsFixed(1)} from ${profile.tradeCount} trades',
                  style: AppTypography.sansSemiBold.copyWith(
                    fontSize: 12.5,
                    color: AppColors.ink2,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ShelfBody extends StatelessWidget {
  final List<Book> books;
  final _ShelfFilter filter;
  final ValueChanged<_ShelfFilter> onFilterChanged;
  final Future<void> Function(Book) onToggleVisibility;

  const _ShelfBody({
    required this.books,
    required this.filter,
    required this.onFilterChanged,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final owned =
        books.where((b) => b.status != BookStatus.tradedAway).toList();
    final onShelf =
        owned.where((b) => b.status == BookStatus.onShelf).toList();
    final inTrade =
        owned.where((b) => b.status == BookStatus.inTrade).toList();

    final visible = filter == _ShelfFilter.onShelf ? onShelf : inTrade;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _FilterChip(
              key: const Key('filter_on_shelf'),
              label: 'My shelf · ${onShelf.length}',
              selected: filter == _ShelfFilter.onShelf,
              onTap: () => onFilterChanged(_ShelfFilter.onShelf),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              key: const Key('filter_in_trade'),
              label: 'In trades · ${inTrade.length}',
              selected: filter == _ShelfFilter.inTrade,
              onTap: () => onFilterChanged(_ShelfFilter.inTrade),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.auto_stories_outlined,
                      size: 40, color: AppColors.piriMoss),
                  const SizedBox(height: 12),
                  Text(
                    filter == _ShelfFilter.onShelf
                        ? "Shelves with a book or two on them get found. Scan one whenever you're ready — no rush."
                        : 'No books in trades right now.',
                    textAlign: TextAlign.center,
                    style: AppTypography.sansRegular.copyWith(
                      fontSize: 13,
                      color: AppColors.ink2,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.52,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) => _ShelfBookTile(
              book: visible[index],
              onToggleVisibility: onToggleVisibility,
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.greenTint : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.green : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTypography.sansBold.copyWith(
            fontSize: 12.5,
            color: selected ? AppColors.green : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

class _ShelfBookTile extends ConsumerWidget {
  final Book book;
  final Future<void> Function(Book) onToggleVisibility;

  const _ShelfBookTile({
    required this.book,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () =>
          context.push(AppRoutes.bookDetail.replaceFirst(':id', book.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: book.visible ? 1 : 0.45,
                    child: LayoutBuilder(
                      builder: (context, constraints) => BookCover(
                        title: book.title,
                        author: book.author,
                        coverColorKey: book.coverColorKey,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        showShadow: false,
                      ),
                    ),
                  ),
                ),
                if (book.status == BookStatus.inTrade)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      key: Key('in_trade_${book.id}'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.honey,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'In trade',
                        style: AppTypography.sansExtraBold.copyWith(
                          fontSize: 9.5,
                          color: AppColors.honeyDeep,
                        ),
                      ),
                    ),
                  ),
                if (book.status == BookStatus.onShelf)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: GestureDetector(
                      key: Key('visibility_${book.id}'),
                      onTap: () => onToggleVisibility(book),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          book.visible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 14,
                          color:
                              book.visible ? AppColors.ink2 : AppColors.ink3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.sansBold.copyWith(
              fontSize: 11.5,
              color: AppColors.ink,
            ),
          ),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.sansRegular.copyWith(
              fontSize: 10.5,
              color: AppColors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}
