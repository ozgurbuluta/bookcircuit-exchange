import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/points_badge.dart';

/// First shelf (mock #3f): welcome-gift banner + empty shelf, with the choice
/// to scan a first book or browse nearby first (spec §5).
class FirstShelfScreen extends ConsumerWidget {
  const FirstShelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final bannerDismissed = ref.watch(welcomeBannerDismissedProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SET-UP · 2 OF 2',
                  style: AppTypography.sansSemiBold.copyWith(
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                    color: AppColors.ink3,
                  ),
                ),
                PointsBadge(points: profile?.points ?? 0),
              ],
            ),
            const SizedBox(height: 16),
            if (bannerDismissed.value != true)
              Container(
                key: const Key('welcome_gift_banner'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.honey,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome gift — 200 pts',
                            style: AppTypography.sansExtraBold.copyWith(
                              fontSize: 14.5,
                              color: AppColors.honeyDeep,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Good for your first four books. Every book you pass on earns 50 back.',
                            style: AppTypography.sansRegular.copyWith(
                              fontSize: 12.5,
                              color: AppColors.honeyDeep,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      key: const Key('dismiss_banner'),
                      onTap: () => ref
                          .read(welcomeBannerDismissedProvider.notifier)
                          .dismiss(),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.close,
                            size: 18, color: AppColors.honeyDeep),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),
            Text(
              'My shelf · 0 books',
              style: AppTypography.serifRegular.copyWith(
                fontSize: 22,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.auto_stories_outlined,
                      size: 44, color: AppColors.piriMoss),
                  const SizedBox(height: 14),
                  Text(
                    "Shelves with a book or two on them get found. Scan one whenever you're ready — no rush.",
                    textAlign: TextAlign.center,
                    style: AppTypography.sansRegular.copyWith(
                      fontSize: 13.5,
                      color: AppColors.ink2,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              key: const Key('scan_first_book'),
              onPressed: () => context.go(AppRoutes.addBook),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Scan my first book'),
            ),
            const SizedBox(height: 10),
            TextButton(
              key: const Key('browse_first'),
              onPressed: () => context.go(AppRoutes.home),
              child: Text(
                'or look around first — browse nearby',
                style: AppTypography.sansBold.copyWith(
                  fontSize: 13,
                  color: AppColors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
