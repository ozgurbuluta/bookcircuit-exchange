import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

/// Generated book cover with literary styling
class BookCover extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String author;
  final String? coverColorKey;
  final double width;
  final double? height;
  final double borderRadius;
  final bool showShadow;

  const BookCover({
    super.key,
    this.imageUrl,
    required this.title,
    required this.author,
    this.coverColorKey,
    this.width = 96,
    this.height,
    this.borderRadius = 5,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final h = height ?? width * 1.5;
    final colorKey = coverColorKey ?? _getColorKeyFromTitle(title);
    final colors = AppColors.covers[colorKey] ?? AppColors.covers['slate']!;

    // If we have an image URL, show the actual cover
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildGeneratedCover(colors, h),
            errorWidget: (context, url, error) => _buildGeneratedCover(colors, h),
          ),
        ),
      );
    }

    // Generate a placeholder cover
    return _buildGeneratedCover(colors, h);
  }

  Widget _buildGeneratedCover(BookCoverColors colors, double h) {
    final fontSize = (width * 0.135).clamp(9.0, 16.0);

    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.background, _darken(colors.background, 0.1)],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          // Spine shading
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: width * 0.08,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(borderRadius),
                  bottomLeft: Radius.circular(borderRadius),
                ),
              ),
            ),
          ),
          // Inner frame
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(h * 0.05),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colors.rule.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
          // Content
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.13,
                vertical: h * 0.13,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.serifMedium.copyWith(
                        fontSize: fontSize,
                        height: 1.15,
                        color: colors.ink,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    author.toUpperCase(),
                    style: AppTypography.sansMedium.copyWith(
                      fontSize: fontSize * 0.62,
                      letterSpacing: 0.4,
                      color: colors.ink.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getColorKeyFromTitle(String title) {
    final colors = AppColors.covers.keys.toList();
    final hash = title.hashCode.abs();
    return colors[hash % colors.length];
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
