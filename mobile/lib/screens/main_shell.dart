import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../config/router.dart';
import '../providers/providers.dart';
import '../services/supabase_service.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  RealtimeChannel? _tradesChannel;

  static const _tabs = [
    _TabItem(route: AppRoutes.home, icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    _TabItem(route: AppRoutes.discover, icon: Icons.search_outlined, activeIcon: Icons.search, label: 'Discover'),
    _TabItem(route: AppRoutes.trades, icon: Icons.swap_horiz_outlined, activeIcon: Icons.swap_horiz, label: 'Trades'),
    _TabItem(route: AppRoutes.messages, icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Messages'),
    _TabItem(route: AppRoutes.profile, icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _tradesChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscriptions() {
    // Subscribe to trade updates for real-time badge updates
    try {
      _tradesChannel = SupabaseService.subscribeToTrades((trade) {
        // Invalidate providers to refresh badge counts
        ref.invalidate(pendingTradesCountProvider);
        ref.invalidate(tradesProvider);
      });
    } catch (e) {
      // Subscription failed, will rely on pull-to-refresh
      debugPrint('Failed to setup realtime trades subscription: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCurrentIndex();
  }

  void _updateCurrentIndex() {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _tabs.indexWhere((tab) => tab.route == location);
    if (index != -1 && index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    context.go(_tabs[index].route);
  }

  @override
  Widget build(BuildContext context) {
    // Watch for badge counts
    final pendingTrades = ref.watch(pendingTradesCountProvider);
    final unreadMessages = ref.watch(unreadMessagesCountProvider);

    return Scaffold(
      body: widget.child,
      extendBody: true,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xD2F6EEDF), // paper3 with 82% opacity
              border: Border(
                top: BorderSide(color: AppColors.line, width: 0.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_tabs.length, (index) {
                    final tab = _tabs[index];
                    final isActive = index == _currentIndex;

                    // Get badge count for this tab
                    int? badge;
                    if (tab.route == AppRoutes.trades) {
                      badge = pendingTrades.when(
                        data: (count) => count > 0 ? count : null,
                        loading: () => null,
                        error: (_, __) => null,
                      );
                    } else if (tab.route == AppRoutes.messages) {
                      badge = unreadMessages.when(
                        data: (count) => count > 0 ? count : null,
                        loading: () => null,
                        error: (_, __) => null,
                      );
                    }

                    return _TabBarItem(
                      icon: isActive ? tab.activeIcon : tab.icon,
                      label: tab.label,
                      isActive: isActive,
                      badge: badge,
                      onTap: () => _onTabTapped(index),
                    );
                  }),
                ),
              ),
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
  final IconData icon;
  final String label;
  final bool isActive;
  final int? badge;
  final VoidCallback onTap;

  const _TabBarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 25,
                  color: isActive ? AppColors.rust : AppColors.ink3,
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                      decoration: BoxDecoration(
                        color: AppColors.rust,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.paper3,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          badge! > 99 ? '99+' : badge.toString(),
                          style: AppTypography.sansBold.copyWith(
                            fontSize: 9.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTypography.sansMedium.copyWith(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.rust : AppColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
