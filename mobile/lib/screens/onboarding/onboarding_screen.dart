import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../config/router.dart';
import '../../providers/onboarding_provider.dart';

/// Tour (mocks #3b–#3d): three cards, skippable at every step (spec §5).
/// Skip and finish both land on neighborhood setup; the tour never shows again.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static final List<_TourPage> _pages = [
    _TourPage(
      icon: Icons.auto_stories_outlined,
      title: "Shelve what you've finished",
      body:
          'Point the camera at a cover or barcode — title, author and edition fill themselves in. You just confirm the language and how worn it is.',
      piri:
          'Your bookcase at home becomes your shelf here. Four books is a fine start.',
    ),
    _TourPage(
      icon: Icons.directions_walk_outlined,
      title: 'Trade with neighbors, on foot',
      body:
          "Search by postal code and see what's on shelves around you. Ask for a book, agree on a spot over chat, and swap it hand to hand.",
      piri:
          'No shipping, no couriers. Nothing travels farther than a pleasant walk.',
    ),
    _TourPage(
      icon: Icons.toll_outlined,
      title: 'Every book is a flat 50 pts',
      body:
          'Nothing to haggle over. Request any book for 50 pts — or offer one of yours instead. Every book you pass on earns 50 back.',
      piri:
          'Your first four books are on the club. Spend them slowly — rather my style.',
    ),
  ];

  Future<void> _finishTour() async {
    await ref.read(onboardingNotifierProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go(AppRoutes.setup);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  key: const Key('skip_tour'),
                  onPressed: _finishTour,
                  child: Text(
                    'Skip the tour',
                    style: AppTypography.sansSemiBold.copyWith(
                      fontSize: 13,
                      color: AppColors.ink3,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemCount: _pages.length,
                itemBuilder: (context, index) => _TourCard(page: _pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.green : AppColors.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('tour_next'),
                  onPressed: isLast
                      ? _finishTour
                      : () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                  child: Text(isLast ? 'Join the club' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourPage {
  final IconData icon;
  final String title;
  final String body;
  final String piri;

  const _TourPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.piri,
  });
}

class _TourCard extends StatelessWidget {
  final _TourPage page;

  const _TourCard({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: AppColors.greenTint,
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 54, color: AppColors.green),
          ),
          const SizedBox(height: 36),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: AppTypography.serifRegular.copyWith(
              fontSize: 26,
              color: AppColors.ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: AppTypography.sansRegular.copyWith(
              fontSize: 14.5,
              color: AppColors.ink2,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Piri: ',
                    style: AppTypography.sansExtraBold.copyWith(
                      fontSize: 12.5,
                      color: AppColors.green,
                    ),
                  ),
                  TextSpan(
                    text: page.piri,
                    style: AppTypography.sansRegular.copyWith(
                      fontSize: 12.5,
                      color: AppColors.ink2,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
