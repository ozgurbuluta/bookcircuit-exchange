import 'package:flutter/material.dart';
import '../config/theme.dart';

/// 1–5 star rating, display-only or interactive (mock #3g).
///
/// Filled stars use honeyAccent; empty stars use the line color.
/// Pass [onChanged] to make it an input.
class RatingStars extends StatelessWidget {
  final int rating;
  final ValueChanged<int>? onChanged;
  final double size;

  const RatingStars({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final value = i + 1;
        final filled = value <= rating;
        final star = Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          key: Key('rating_star_$value'),
          size: size,
          color: filled ? AppColors.honeyAccent : AppColors.line,
        );

        if (onChanged == null) return star;
        return GestureDetector(
          onTap: () => onChanged!(value),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: star,
          ),
        );
      }),
    );
  }
}
