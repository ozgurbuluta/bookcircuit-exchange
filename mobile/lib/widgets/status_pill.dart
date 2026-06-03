import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/trade.dart';

/// Status pill for trade status display
class StatusPill extends StatelessWidget {
  final TradeStatus status;

  const StatusPill({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.statusColors[status.value] ??
        const StatusColors('Unknown', AppColors.ink2, AppColors.paper3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        colors.label,
        style: AppTypography.sansSemiBold.copyWith(
          fontSize: 11.5,
          letterSpacing: 0.3,
          color: colors.foreground,
        ),
      ),
    );
  }
}
