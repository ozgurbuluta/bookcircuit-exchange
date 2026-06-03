import 'package:flutter/material.dart';
import '../config/theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo/icon placeholder
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.rust, AppColors.rust2],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.rust.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 48,
                color: AppColors.paper2,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Turtle Turning Pages',
              style: AppTypography.serifSemiBold.copyWith(
                fontSize: 24,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Trade books with your community',
              style: AppTypography.sansRegular.copyWith(
                fontSize: 14,
                color: AppColors.ink3,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.rust),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
