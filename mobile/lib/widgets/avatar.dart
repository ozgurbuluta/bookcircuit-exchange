import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../models/profile.dart';

/// User avatar widget
class UserAvatar extends StatelessWidget {
  final Profile? profile;
  final String? imageUrl;
  final String? initials;
  final double size;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    this.profile,
    this.imageUrl,
    this.initials,
    this.size = 40,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl ?? profile?.avatarUrl;
    final letters = initials ?? profile?.initials ?? 'U';
    final bgColor = backgroundColor ?? _getColorFromInitials(letters);

    if (url != null && url.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildInitialsAvatar(letters, bgColor),
            errorWidget: (context, url, error) =>
                _buildInitialsAvatar(letters, bgColor),
          ),
        ),
      );
    }

    return _buildInitialsAvatar(letters, bgColor);
  }

  Widget _buildInitialsAvatar(String letters, Color bgColor) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgColor, _darken(bgColor, 0.16)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          letters.substring(0, letters.length.clamp(0, 2)),
          style: AppTypography.serifMedium.copyWith(
            fontSize: size * 0.4,
            letterSpacing: 0.3,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Color _getColorFromInitials(String initials) {
    final colors = [
      const Color(0xFFB6502E), // rust
      const Color(0xFF3F5468), // dusty
      const Color(0xFF5A5A36), // olive
      const Color(0xFF4A3552), // plum
      const Color(0xFF2F4A3A), // forest
    ];
    final hash = initials.hashCode.abs();
    return colors[hash % colors.length];
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
