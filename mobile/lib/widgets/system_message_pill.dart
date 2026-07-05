import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Centered honey pill for system events in trade chat (mock #2d):
/// "points escrowed", "accepted", "cancelled", "swapped".
class SystemMessagePill extends StatelessWidget {
  final String text;

  const SystemMessagePill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        key: const Key('system_pill_container'),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.honey,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.sansExtraBold.copyWith(
            fontSize: 11,
            color: AppColors.honeyDeep,
          ),
        ),
      ),
    );
  }
}
