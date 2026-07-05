import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Trade status chip using the AppColors.statusColors map (mocks #2c/#2d).
/// Unknown statuses render the raw value neutral-styled rather than crashing.
class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.statusColors[status] ??
        StatusColors(status, AppColors.ink2, AppColors.neutralTint);

    return Container(
      key: const Key('status_chip_container'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        colors.label,
        style: AppTypography.sansExtraBold.copyWith(
          fontSize: 11.5,
          color: colors.foreground,
        ),
      ),
    );
  }
}
