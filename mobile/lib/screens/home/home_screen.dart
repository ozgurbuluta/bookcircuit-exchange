import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../config/router.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final booksAsync = ref.watch(booksProvider);
    final pendingTrades = ref.watch(pendingTradesCountProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
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
                  ],
                ),
              ),
            ),

            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.discover),
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
                        Text(
                          'Search titles, authors...',
                          style: AppTypography.sansRegular.copyWith(
                            fontSize: 15,
                            color: AppColors.ink3,
                          ),
                        ),
                      ],
                    ),
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

            // Books carousel
            booksAsync.when(
              data: (books) => SliverToBoxAdapter(
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
              ),
              loading: () => const SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: Center(
                  child: Text('Error loading books: $error'),
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

            // Books list
            booksAsync.when(
              data: (books) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.paper2,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.line, width: 0.5),
                    ),
                    child: Column(
                      children: books.skip(5).take(4).map((book) {
                        final isFirst = books.skip(5).first == book;
                        return Container(
                          decoration: BoxDecoration(
                            border: isFirst
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
              ),
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
    );
  }
}
