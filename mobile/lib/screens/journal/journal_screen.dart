import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Club journal tab (mock #1l) — read-only in v1 (spec §1).
/// Placeholder scaffold until Phase K wires the blogPosts feed.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Club journal')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book_outlined,
                  size: 48, color: AppColors.piriMoss),
              const SizedBox(height: 16),
              Text(
                'The journal is warming up',
                textAlign: TextAlign.center,
                style: AppTypography.serifRegular.copyWith(
                  fontSize: 20,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stories, reading lists and club events will appear here.',
                textAlign: TextAlign.center,
                style: AppTypography.sansRegular.copyWith(
                  fontSize: 13.5,
                  color: AppColors.ink2,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
