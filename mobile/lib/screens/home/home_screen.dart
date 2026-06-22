import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../config/router.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(booksProvider);
    ref.invalidate(pendingTradesCountProvider);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final currentUser = ref.watch(currentUserProvider);
    final booksAsync = ref.watch(booksProvider);
    final pendingTrades = ref.watch(pendingTradesCountProvider);

    return Container(
      color: AppColors.paper,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.rust,
          backgroundColor: AppColors.paper2,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${profile?.fullName?.split(' ').first ?? 'reader'}',
                            style: AppTypography.serifSemiBold.copyWith(
                              fontSize: 32,
                              letterSpacing: -0.4,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile?.formattedLocation ?? 'Set your location',
                            style: AppTypography.sansRegular.copyWith(
                              fontSize: 14,
                              color: AppColors.ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        pendingTrades.when(
                          data: (count) => AppIconButton(
                            icon: Icons.notifications_outlined,
                            badge: count > 0 ? count : null,
                            onPressed: () => context.go(AppRoutes.trades),
                          ),
                          loading: () => AppIconButton(
                            icon: Icons.notifications_outlined,
                            onPressed: () => context.go(AppRoutes.trades),
                          ),
                          error: (_, __) => AppIconButton(
                            icon: Icons.notifications_outlined,
                            onPressed: () => context.go(AppRoutes.trades),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => context.go(AppRoutes.profile),
                          child: UserAvatar(profile: profile, size: 38),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.paper2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.04),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 19, color: AppColors.ink3),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                          style: AppTypography.sansRegular.copyWith(
                            fontSize: 15,
                            color: AppColors.ink,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search titles, authors...',
                            hintStyle: AppTypography.sansRegular.copyWith(
                              fontSize: 15,
                              color: AppColors.ink3,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _searchFocusNode.unfocus();
                          },
                          child: const Icon(Icons.close, size: 18, color: AppColors.ink3),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Pending trades banner
            pendingTrades.when(
              data: (count) => count > 0
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                        child: GestureDetector(
                          onTap: () => context.go(AppRoutes.trades),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [AppColors.rust, AppColors.rust2],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.rust.withValues(alpha: 0.28),
                                  blurRadius: 22,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.swap_horiz,
                                    size: 22,
                                    color: AppColors.paper2,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$count trade${count > 1 ? 's' : ''} await your reply',
                                        style: AppTypography.serifSemiBold.copyWith(
                                          fontSize: 16,
                                          color: AppColors.paper2,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'Tap to view',
                                        style: AppTypography.sansRegular.copyWith(
                                          fontSize: 12.5,
                                          color: AppColors.paper2.withValues(alpha: 0.82),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: AppColors.paper2.withValues(alpha: 0.7),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SliverToBoxAdapter(child: SizedBox.shrink()),
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

            // Near you section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
                child: SectionHeader(
                  title: 'Near you',
                  action: 'Discover',
                  onAction: () => context.go(AppRoutes.discover),
                ),
              ),
            ),

            // Books carousel - only show books from OTHER users
            booksAsync.when(
              data: (allBooks) {
                final otherUsersBooks = allBooks
                    .where((b) => b.userId != currentUser?.uid)
                    .toList();
                final books = _searchQuery.isEmpty
                    ? otherUsersBooks
                    : otherUsersBooks.where((b) =>
                        b.title.toLowerCase().contains(_searchQuery) ||
                        b.author.toLowerCase().contains(_searchQuery)).toList();
                return books.isEmpty
                  ? SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.paper2,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.line, width: 0.5),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.menu_book_outlined, size: 48, color: AppColors.ink3.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty ? 'No books nearby yet' : 'No matches found',
                              style: AppTypography.serifSemiBold.copyWith(
                                fontSize: 16,
                                color: AppColors.ink2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchQuery.isEmpty ? 'Be the first to share a book!' : 'Try a different search term',
                              style: AppTypography.sansRegular.copyWith(
                                fontSize: 13,
                                color: AppColors.ink3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverToBoxAdapter(
                      child: SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: books.take(5).length,
                          itemBuilder: (context, index) {
                            final book = books[index];
                            return Padding(
                              padding: EdgeInsets.only(right: index < 4 ? 16 : 0),
                              child: BookCoverCard(
                                book: book,
                                onTap: () => context.push('/book/${book.id}'),
                              ),
                            );
                          },
                        ),
                      ),
                    );
              },
              loading: () => SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.rust),
                    ),
                  ),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.rust.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.rust, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Unable to load books. Pull down to refresh.',
                          style: AppTypography.sansRegular.copyWith(
                            fontSize: 13,
                            color: AppColors.rust2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Fresh on the shelves section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
                child: SectionHeader(title: 'Fresh on the shelves'),
              ),
            ),

            // Books list - only show books from OTHER users
            booksAsync.when(
              data: (allBooks) {
                final otherUsersBooks = allBooks
                    .where((b) => b.userId != currentUser?.uid)
                    .toList();
                final books = _searchQuery.isEmpty
                    ? otherUsersBooks
                    : otherUsersBooks.where((b) =>
                        b.title.toLowerCase().contains(_searchQuery) ||
                        b.author.toLowerCase().contains(_searchQuery)).toList();
                final freshBooks = books.skip(5).take(4).toList();
                if (freshBooks.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.paper2,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.line, width: 0.5),
                      ),
                      child: Column(
                        children: freshBooks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final book = entry.value;
                          return Container(
                            decoration: BoxDecoration(
                              border: index == 0
                                  ? null
                                  : const Border(
                                      top: BorderSide(
                                        color: AppColors.line2,
                                        width: 0.5,
                                      ),
                                    ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: BookCard(
                              book: book,
                              onTap: () => context.push('/book/${book.id}'),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: Center(child: Text('Error: $error')),
              ),
            ),

            // Quote footer
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 28, 40, 120),
                child: Text(
                  '"A book is a gift you can open again and again."',
                  style: AppTypography.serifItalic.copyWith(
                    fontSize: 14,
                    color: AppColors.ink3,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
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
