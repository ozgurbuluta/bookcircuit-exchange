import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Notifications (mock #1k) — placeholder scaffold until Phase J wires the
/// notifications collection and inline Accept / Decline / Chat actions.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Notifications')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.notifications_none_outlined,
                  size: 48, color: AppColors.piriMoss),
              const SizedBox(height: 16),
              Text(
                'All quiet for now',
                style: AppTypography.serifRegular.copyWith(
                  fontSize: 20,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Requests, trades and ratings will land here.',
                textAlign: TextAlign.center,
                style: AppTypography.sansRegular.copyWith(
                  fontSize: 13.5,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
