import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/book.dart';
import 'book_cover.dart';
import 'condition_badge.dart';

/// Book card for list display
class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showDistance;

  const BookCard({
    super.key,
    required this.book,
    this.onTap,
    this.trailing,
    this.showDistance = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            BookCover(
              imageUrl: book.coverImgUrl,
              title: book.title,
              author: book.author,
              coverColorKey: book.coverColorKey,
              width: 52,
              borderRadius: 4,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: AppTypography.serifSemiBold.copyWith(
                      fontSize: 16,
                      height: 1.2,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    book.author,
                    style: AppTypography.sansRegular.copyWith(
                      fontSize: 13,
                      color: AppColors.ink2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      ConditionBadge(condition: book.condition, small: true),
                      if (showDistance && book.distanceDisplay != null) ...[
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 13,
                              color: AppColors.ink3,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              book.distanceDisplay!,
                              style: AppTypography.sansMedium.copyWith(
                                fontSize: 12,
                                color: AppColors.ink3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.ink.withValues(alpha: 0.22),
                ),
          ],
        ),
      ),
    );
  }
}

/// Compact book cover card for horizontal scrolling
class BookCoverCard extends StatelessWidget {
  final Book book;
  final VoidCallback? onTap;
  final double width;

  const BookCoverCard({
    super.key,
    required this.book,
    this.onTap,
    this.width = 116,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(
              imageUrl: book.coverImgUrl,
              title: book.title,
              author: book.author,
              coverColorKey: book.coverColorKey,
              width: width,
            ),
            const SizedBox(height: 9),
            Text(
              book.title,
              style: AppTypography.serifSemiBold.copyWith(
                fontSize: 13.5,
                height: 1.2,
                color: AppColors.ink,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (book.distanceDisplay != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 12,
                    color: AppColors.ink3,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    book.distanceDisplay!,
                    style: AppTypography.sansMedium.copyWith(
                      fontSize: 11.5,
                      color: AppColors.ink3,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
