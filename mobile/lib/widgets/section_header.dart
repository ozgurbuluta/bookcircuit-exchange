import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Section header with optional action
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTypography.sansBold.copyWith(
              fontSize: 12.5,
              letterSpacing: 1.4,
              color: AppColors.ink3,
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: AppTypography.sansSemiBold.copyWith(
                  fontSize: 13,
                  color: AppColors.rust,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
