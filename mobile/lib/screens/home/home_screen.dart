import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/router.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/points_badge.dart';

/// Home — "The Shelf" (mock #1a, spec §7): search card, map teaser with the
/// nearby count, "New nearby", "Most loved this month", journal teaser.
/// The user's own books never appear here.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final newNearby = ref.watch(newNearbyProvider);
    final mostLoved = ref.watch(mostLovedProvider);
    final nearbyCount = ref.watch(nearbyCountProvider);

    final area = profile?.areaLabel?.split(',').first.trim();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(nearbyPoolProvider);
            await ref.read(booksProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              // Header: brand + bell + points (spec §2)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Turtle Turning Pages',
                      style: AppTypography.serifRegular.copyWith(
                        fontSize: 17,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('bell_button'),
                    icon: const Icon(Icons.notifications_none_outlined,
                        color: AppColors.ink2),
                    onPressed: () => context.push(AppRoutes.notifications),
                  ),
                  PointsBadge(
                    points: profile?.points ?? 0,
                    onTap: () => context.push(AppRoutes.trades),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Greeting (mock #1a)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'What will you pass on this week?',
                      style: AppTypography.serifRegular.copyWith(
                        fontSize: 24,
                        color: AppColors.ink,
                        height: 1.2,
                      ),
                    ),
                    if (area != null)
                      TextSpan(
                        text: '  — $area',
                        style: AppTypography.serifItalic.copyWith(
                          fontSize: 16,
                          color: AppColors.ink3,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Search card
              TextField(
                key: const Key('home_search'),
                controller: _searchController,
                onSubmitted: (value) {
                  ref
                      .read(bookSearchParamsProvider.notifier)
                      .update((p) => p.copyWith(query: value));
                  context.push(AppRoutes.map);
                },
                decoration: const InputDecoration(
                  hintText: 'Search nearby shelves',
                  prefixIcon:
                      Icon(Icons.search, color: AppColors.ink3, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              // Map teaser (mock #1a)
              GestureDetector(
                key: const Key('map_teaser'),
                onTap: () => context.push(AppRoutes.map),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.greenTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map_outlined,
                          color: AppColors.green, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: nearbyCount.when(
                          loading: () => Text(
                            'Looking around your neighborhood…',
                            style: AppTypography.sansSemiBold.copyWith(
                              fontSize: 13,
                              color: AppColors.green,
                            ),
                          ),
                          error: (_, __) => Text(
                            'See what is on shelves near you',
                            style: AppTypography.sansSemiBold.copyWith(
                              fontSize: 13,
                              color: AppColors.green,
                            ),
                          ),
                          data: (count) => Text(
                            count == 0
                                ? 'No books within 1 km yet — check back soon'
                                : '$count books within 1 km',
                            style: AppTypography.sansSemiBold.copyWith(
                              fontSize: 13,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'Open map',
                        style: AppTypography.sansExtraBold.copyWith(
                          fontSize: 12.5,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // New nearby
              _SectionHeader(
                title: 'New nearby',
                onSeeAll: () => context.push(AppRoutes.map),
              ),
              const SizedBox(height: 10),
              newNearby.when(
                loading: () => const SizedBox(
                  height: 190,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const _EmptySection(
                    text: 'Could not load nearby books. Pull to retry.'),
                data: (books) => books.isEmpty
                    ? const _EmptySection(
                        text:
                            'Nothing on nearby shelves yet. Yours could be the first.')
                    : SizedBox(
                        height: 196,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: books.length,
                          itemBuilder: (context, index) =>
                              _NearbyCard(book: books[index]),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              // Most loved this month
              _SectionHeader(
                title: 'Most loved this month',
                onSeeAll: () => context.push(AppRoutes.map),
              ),
              const SizedBox(height: 10),
              mostLoved.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (books) => books.isEmpty
                    ? const _EmptySection(
                        text: 'No requests around here yet this month.')
                    : Column(
                        children: books
                            .map((book) => _MostLovedRow(book: book))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 24),
              // Journal teaser
              _SectionHeader(
                title: 'From the club journal',
                seeAllLabel: 'Read all',
                onSeeAll: () => context.go(AppRoutes.journal),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                key: const Key('journal_teaser'),
                onTap: () => context.go(AppRoutes.journal),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book_outlined,
                          color: AppColors.piriMoss, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Stories, reading lists and club events',
                          style: AppTypography.sansSemiBold.copyWith(
                            fontSize: 13,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.ink3, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String seeAllLabel;
  final VoidCallback onSeeAll;

  const _SectionHeader({
    required this.title,
    this.seeAllLabel = 'See all',
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTypography.serifRegular.copyWith(
            fontSize: 18,
            color: AppColors.ink,
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            seeAllLabel,
            style: AppTypography.sansBold.copyWith(
              fontSize: 12.5,
              color: AppColors.green,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String text;

  const _EmptySection({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.sansRegular.copyWith(
          fontSize: 13,
          color: AppColors.ink2,
          height: 1.5,
        ),
      ),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  final Book book;

  const _NearbyCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final ownerFirstName = book.owner?.displayName.split(' ').first;

    return GestureDetector(
      onTap: () =>
          context.push(AppRoutes.bookDetail.replaceFirst(':id', book.id)),
      child: Container(
        width: 108,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 108,
              height: 142,
              child: BookCover(
                title: book.title,
                author: book.author,
                coverColorKey: book.coverColorKey,
                width: 108,
                height: 142,
                showShadow: false,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.sansBold.copyWith(
                fontSize: 12,
                color: AppColors.ink,
              ),
            ),
            Text(
              [
                if (book.distanceDisplay != null) book.distanceDisplay!,
                if (ownerFirstName != null) ownerFirstName,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.sansRegular.copyWith(
                fontSize: 10.5,
                color: AppColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MostLovedRow extends StatelessWidget {
  final Book book;

  const _MostLovedRow({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          context.push(AppRoutes.bookDetail.replaceFirst(':id', book.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
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
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sansBold.copyWith(
                      fontSize: 13.5,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      book.author,
                      if (book.language != null) book.language!,
                    ].join(' · '),
                    style: AppTypography.sansRegular.copyWith(
                      fontSize: 11.5,
                      color: AppColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.honey,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${book.requestCount} requests',
                style: AppTypography.sansExtraBold.copyWith(
                  fontSize: 10.5,
                  color: AppColors.honeyDeep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
