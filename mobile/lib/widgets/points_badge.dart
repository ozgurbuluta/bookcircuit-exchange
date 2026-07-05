import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Honey pill showing a points amount ("200 pts") with the shell glyph.
///
/// Mock #1a: bg honey, fg honeyDeep, radius 999, weight 700, 12.5px.
/// In headers, tapping navigates to My trades (spec §2).
class PointsBadge extends StatelessWidget {
  final int points;
  final VoidCallback? onTap;

  const PointsBadge({super.key, required this.points, this.onTap});

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      key: const Key('points_badge_container'),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.honey,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ShellGlyph(),
          const SizedBox(width: 5),
          Text(
            '$points pts',
            style: AppTypography.sansBold.copyWith(
              fontSize: 12.5,
              color: AppColors.honeyDeep,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return badge;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: badge,
    );
  }
}

/// Tiny turtle-shell glyph used next to point amounts (spec §10).
class _ShellGlyph extends StatelessWidget {
  const _ShellGlyph();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(12, 12),
      painter: _ShellPainter(),
    );
  }
}

class _ShellPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = AppColors.honeyDeep;
    final line = Paint()
      ..color = AppColors.honey
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Dome
    final rect = Rect.fromLTWH(0, size.height * 0.15, size.width, size.height * 1.4);
    canvas.drawArc(rect, 3.14159, 3.14159, true, fill);
    // Shell ridges
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.15),
      Offset(size.width / 2, size.height * 0.85),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.28),
      Offset(size.width * 0.35, size.height * 0.85),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.28),
      Offset(size.width * 0.65, size.height * 0.85),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
