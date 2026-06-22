import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../config/router.dart';
import '../../models/book.dart';
import '../../models/trade.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature coming soon!',
          style: AppTypography.sansRegular.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.ink2,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
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
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.ink2),
                title: Text('Add a book',
                    style: AppTypography.sansSemiBold.copyWith(color: AppColors.ink)),
                subtitle: Text('Search and add one book',
                    style: AppTypography.sansRegular.copyWith(fontSize: 12.5, color: AppColors.ink3)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.addBook);
                },
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined, color: AppColors.rust),
                title: Text('Scan a shelf',
                    style: AppTypography.sansSemiBold.copyWith(color: AppColors.ink)),
                subtitle: Text('Photograph a shelf to add many at once',
                    style: AppTypography.sansRegular.copyWith(fontSize: 12.5, color: AppColors.ink3)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.scanShelf);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final myBooksAsync = ref.watch(myBooksProvider);

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
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppIconButton(
                      icon: Icons.settings_outlined,
                      onPressed: () => context.push(AppRoutes.editProfile),
                    ),
                  ],
                ),
              ),
            ),

            // Profile info
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: Column(
                  children: [
                    UserAvatar(profile: profile, size: 88),
                    const SizedBox(height: 14),
                    Text(
                      profile?.displayName ?? 'You',
                      style: AppTypography.serifSemiBold.copyWith(
                        fontSize: 25,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile?.formattedLocation ?? 'Set your location',
                      style: AppTypography.sansRegular.copyWith(
                        fontSize: 13.5,
                        color: AppColors.ink3,
                      ),
                    ),
                    if (profile?.bio != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        profile!.bio!,
                        style: AppTypography.serifItalic.copyWith(
                          fontSize: 15,
                          height: 1.5,
                          color: AppColors.ink2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => context.push(AppRoutes.editProfile),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      ),
                      child: Text(
                        'Edit profile',
                        style: AppTypography.sansBold.copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Stats
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                decoration: BoxDecoration(
                  color: AppColors.paper2,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line, width: 0.5),
                ),
                child: Row(
                  children: [
                    _StatItem(value: '0', label: 'Trades'),
                    _StatItem(
                      value: myBooksAsync.when(
                        data: (books) => books.length.toString(),
                        loading: () => '-',
                        error: (_, __) => '0',
                      ),
                      label: 'On shelf',
                    ),
                    const _StatItem(value: '-', label: 'Rating'),
                    const _StatItem(value: '0', label: 'Saved'),
                  ],
                ),
              ),
            ),

            // My shelf header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 28, 0, 12),
                child: SectionHeader(
                  title: 'My shelf',
                  action: 'Add book',
                  onAction: () => _showAddOptions(context),
                ),
              ),
            ),

            // My books
            myBooksAsync.when(
              data: (books) => SliverToBoxAdapter(
                child: SizedBox(
                  height: 230,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: books.length + 1,
                    itemBuilder: (context, index) {
                      if (index == books.length) {
                        return _AddBookTile(onTap: () => _showAddOptions(context));
                      }
                      final book = books[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: SizedBox(
                          width: 104,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => context.push('/book/${book.id}'),
                                child: Stack(
                                  children: [
                                    BookCover(
                                      imageUrl: book.coverImgUrl,
                                      title: book.title,
                                      author: book.author,
                                      width: 104,
                                    ),
                                    if (book.status == BookStatus.trading)
                                      Positioned(
                                        top: 7,
                                        left: 7,
                                        child: StatusPill(status: TradeStatus.pending),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                book.title,
                                style: AppTypography.serifSemiBold.copyWith(
                                  fontSize: 13.5,
                                  color: AppColors.ink,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              ConditionBadge(condition: book.condition, small: true),
                            ],
                          ),
                        ),
                      );
                    },
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

            // Settings
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.paper2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.line, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.location_on_outlined,
                        label: 'Reading location',
                        value: profile?.formattedLocation ?? 'Set location',
                        onTap: () => context.push(AppRoutes.editProfile),
                      ),
                      _SettingsRow(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        value: 'On',
                        onTap: () => _showComingSoon(context, 'Notifications'),
                      ),
                      _SettingsRow(
                        icon: Icons.favorite_outline,
                        label: 'Saved books',
                        value: '0',
                        onTap: () => _showComingSoon(context, 'Saved books'),
                      ),
                      _SettingsRow(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        value: '',
                        onTap: () => context.push(AppRoutes.editProfile),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Sign out
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
                child: Center(
                  child: GestureDetector(
                    onTap: () async {
                      await ref.read(authProvider.notifier).signOut();
                      if (context.mounted) {
                        context.go(AppRoutes.signIn);
                      }
                    },
                    child: Text(
                      'Sign out',
                      style: AppTypography.sansSemiBold.copyWith(
                        fontSize: 13,
                        color: AppColors.rust2,
                      ),
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

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.line2, width: 0.5)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTypography.serifSemiBold.copyWith(
                fontSize: 21,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.sansSemiBold.copyWith(
                fontSize: 11.5,
                color: AppColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line2, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.rust.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: AppColors.rust),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: AppTypography.sansSemiBold.copyWith(
                  fontSize: 15,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: AppTypography.sansRegular.copyWith(
                  fontSize: 13.5,
                  color: AppColors.ink3,
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 17,
              color: AppColors.ink.withValues(alpha: 0.22),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddBookTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddBookTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 104,
        child: Column(
          children: [
            Container(
              width: 104,
              height: 156,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: AppColors.line,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_box_outlined, size: 26, color: AppColors.ink3),
                  const SizedBox(height: 8),
                  Text(
                    'Add book',
                    style: AppTypography.sansSemiBold.copyWith(
                      fontSize: 12,
                      color: AppColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
