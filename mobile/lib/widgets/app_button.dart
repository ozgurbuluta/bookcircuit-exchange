import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Primary app button with loading state
class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final bool isOutlined;
  final bool isDanger;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.isOutlined = false,
    this.isDanger = false,
    this.width,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return SizedBox(
        width: width,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: isDanger ? AppColors.rust2.withValues(alpha: 0.35) : AppColors.ink,
              width: 1.5,
            ),
            foregroundColor: isDanger ? AppColors.rust2 : AppColors.ink,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : child,
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.rust, AppColors.rust2],
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: AppColors.rust.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.paper2),
                  ),
                )
              : DefaultTextStyle(
                  style: AppTypography.sansBold.copyWith(
                    fontSize: 15.5,
                    color: AppColors.paper2,
                  ),
                  child: child,
                ),
        ),
      ),
    );
  }
}

/// Icon button with optional badge
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final int? badge;
  final double size;
  final Color? iconColor;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.badge,
    this.size = 38,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(icon, size: 21, color: iconColor ?? AppColors.ink),
            ),
            if (badge != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: AppColors.rust,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.paper, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      badge! > 99 ? '99+' : badge.toString(),
                      style: AppTypography.sansBold.copyWith(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
