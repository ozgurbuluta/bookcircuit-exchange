import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Selectable rating tag ("On time", "As described", "Great pick").
///
/// Mock #3g: selected = greenTint bg + green text; unselected = surface bg,
/// line border, ink2 text. Pill radius.
class RatingTagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const RatingTagChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: const Key('rating_tag_container'),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.greenTint : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.green : AppColors.line,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTypography.sansBold.copyWith(
            fontSize: 12.5,
            color: selected ? AppColors.green : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}
