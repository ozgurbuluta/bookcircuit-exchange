import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/book.dart';

/// Condition badge for book condition display
class ConditionBadge extends StatelessWidget {
  final BookCondition condition;
  final bool small;

  const ConditionBadge({
    super.key,
    required this.condition,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.conditionColors[condition.displayName] ??
        const ConditionColors(AppColors.ink2, AppColors.paper3);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 7 : 9,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        condition.displayName,
        style: AppTypography.sansSemiBold.copyWith(
          fontSize: small ? 10.5 : 11.5,
          letterSpacing: 0.2,
          color: colors.foreground,
        ),
      ),
    );
  }
}
