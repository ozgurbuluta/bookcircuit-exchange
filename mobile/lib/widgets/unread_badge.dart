import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Terracotta unread-count badge (mocks #1i/#1h): white text, pill,
/// 9.5–10px extra-bold. Renders nothing when count is zero.
class UnreadBadge extends StatelessWidget {
  final int count;

  const UnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      key: const Key('unread_badge_container'),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      decoration: BoxDecoration(
        color: AppColors.terracotta,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: AppTypography.sansExtraBold.copyWith(
            fontSize: 10,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
