import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../config/router.dart';
import '../providers/providers.dart';
import '../widgets/unread_badge.dart';

/// Tab shell (spec §2): Home · Journal · Add book (center) · Chats · Shelf.
/// The center slot is an action, not a tab — it pushes the add-book flow.
class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _tabs = [
    _TabItem(
        route: AppRoutes.home,
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home'),
    _TabItem(
        route: AppRoutes.journal,
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        label: 'Journal'),
    _TabItem(
        route: AppRoutes.messages,
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Chats'),
    _TabItem(
        route: AppRoutes.shelf,
        icon: Icons.collections_bookmark_outlined,
        activeIcon: Icons.collections_bookmark,
        label: 'Shelf'),
  ];

  int get _currentIndex {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _tabs.indexWhere((tab) => tab.route == location);
    return index == -1 ? 0 : index;
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    context.go(_tabs[index].route);
  }

  void _openAddBook() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
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
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.green),
                title: Text('Scan a book',
                    style: AppTypography.sansSemiBold
                        .copyWith(color: AppColors.ink)),
                subtitle: Text('Cover or barcode — details fill themselves in',
                    style: AppTypography.sansRegular
                        .copyWith(fontSize: 12.5, color: AppColors.ink3)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.addBook);
                },
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined,
                    color: AppColors.green),
                title: Text('Scan a shelf',
                    style: AppTypography.sansSemiBold
                        .copyWith(color: AppColors.ink)),
                subtitle: Text('Photograph a shelf to add many at once',
                    style: AppTypography.sansRegular
                        .copyWith(fontSize: 12.5, color: AppColors.ink3)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.scanShelf);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.ink2),
                title: Text('Enter manually',
                    style: AppTypography.sansSemiBold
                        .copyWith(color: AppColors.ink)),
                subtitle: Text('Type the details yourself',
                    style: AppTypography.sansRegular
                        .copyWith(fontSize: 12.5, color: AppColors.ink3)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.addBook);
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
  Widget build(BuildContext context) {
    final unreadMessages = ref.watch(unreadMessagesCountProvider);
    final currentIndex = _currentIndex;

    final chatBadge = unreadMessages.maybeWhen(
      data: (count) => count,
      orElse: () => 0,
    );

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TabBarItem(
                  tab: _tabs[0],
                  isActive: currentIndex == 0,
                  onTap: () => _onTabTapped(0),
                ),
                _TabBarItem(
                  tab: _tabs[1],
                  isActive: currentIndex == 1,
                  onTap: () => _onTabTapped(1),
                ),
                _AddBookButton(onTap: _openAddBook),
                _TabBarItem(
                  tab: _tabs[2],
                  isActive: currentIndex == 2,
                  badge: chatBadge,
                  onTap: () => _onTabTapped(2),
                ),
                _TabBarItem(
                  tab: _tabs[3],
                  isActive: currentIndex == 3,
                  onTap: () => _onTabTapped(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _TabItem({
    required this.route,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _TabBarItem extends StatelessWidget {
  final _TabItem tab;
  final bool isActive;
  final int badge;
  final VoidCallback onTap;

  const _TabBarItem({
    required this.tab,
    required this.isActive,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? tab.activeIcon : tab.icon,
                  size: 24,
                  color: isActive ? AppColors.green : AppColors.ink3,
                ),
                if (badge > 0)
                  Positioned(
                    top: -5,
                    right: -9,
                    child: UnreadBadge(count: badge),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: AppTypography.sansMedium.copyWith(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.green : AppColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Center "Add book" action (spec §2) — raised green disc + label.
class _AddBookButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddBookButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('add_book_fab'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: AppColors.bg, size: 24),
            ),
            const SizedBox(height: 2),
            Text(
              'Add book',
              style: AppTypography.sansMedium.copyWith(
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
