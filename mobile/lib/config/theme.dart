import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for Turtle Turning Pages.
///
/// Source of truth: docs/design-package/TOKENS.md, extracted from the
/// "Turtle Turning Pages" design canvas. Forest-green + cream palette with a
/// honey accent for the points economy and terracotta for destructive actions.
class AppColors {
  // Backgrounds & lines
  static const Color bg = Color(0xFFFAF5E9);
  static const Color surface = Color(0xFFFFFCF4);
  static const Color line = Color(0xFFE8E2CE);
  static const Color neutralTint = Color(0xFFF0EADB);

  // Ink scale
  static const Color ink = Color(0xFF20291F);
  static const Color ink2 = Color(0xFF5F6A5C);
  static const Color ink3 = Color(0xFF939C8D);

  // Brand greens
  static const Color green = Color(0xFF2F5240);
  static const Color greenDeep = Color(0xFF24382B);
  static const Color greenTint = Color(0xFFE8EEDF);

  // Honey — points badges, system pills, condition chips, "In trade" overlays
  static const Color honey = Color(0xFFF6E7C8);
  static const Color honeyDeep = Color(0xFF96621C);
  static const Color honeyAccent = Color(0xFFD9952F);

  // Terracotta — cancel actions, cancelled/declined states, unread badges
  static const Color terracotta = Color(0xFFC05F37);
  static const Color terracottaTint = Color(0xFFFBF1EA);

  // Piri illustration greens (onboarding + empty states only)
  static const Color piriSage = Color(0xFF8FA783);
  static const Color piriMoss = Color(0xFF7E9469);

  // Chat bubbles
  static const Color sentBubbleText = Color(0xFFF5F0E1);

  // Shadows
  static const Color shadow = Color(0x1224382B); // rgba(36,56,43,0.07)

  // ---------------------------------------------------------------------------
  // Legacy aliases — old token names mapped onto the new palette so screens
  // keep compiling until each is rebuilt. Remove in Phase L.
  // ---------------------------------------------------------------------------
  @Deprecated('Use AppColors.bg')
  static const Color paper = bg;
  @Deprecated('Use AppColors.surface')
  static const Color paper2 = surface;
  @Deprecated('Use AppColors.bg or AppColors.neutralTint')
  static const Color paper3 = neutralTint;
  @Deprecated('Use AppColors.green')
  static const Color rust = green;
  @Deprecated('Use AppColors.greenDeep')
  static const Color rust2 = greenDeep;
  @Deprecated('Use AppColors.piriMoss')
  static const Color sage = piriMoss;
  @Deprecated('Use AppColors.honeyAccent')
  static const Color gold = honeyAccent;
  @Deprecated('Use AppColors.line')
  static const Color line2 = line;

  /// Book cover placeholder palette (7 canonical colorways from the mocks).
  /// Photos are v2 — every cover is generated from these.
  static const Map<String, BookCoverColors> covers = {
    'honey': BookCoverColors(Color(0xFFD9952F), Color(0xFF3A2A0E), Color(0xFFB37517)),
    'plum': BookCoverColors(Color(0xFF7A5A68), Color(0xFFF2E9EC), Color(0xFF9C7E8C)),
    'slate': BookCoverColors(Color(0xFF5C7186), Color(0xFFF0F2EC), Color(0xFF7E93A8)),
    'deepGreen': BookCoverColors(Color(0xFF24382B), Color(0xFFEDE6D2), Color(0xFF46604D)),
    'forest': BookCoverColors(Color(0xFF2F5240), Color(0xFFF2EBD8), Color(0xFF517462)),
    'terracotta': BookCoverColors(Color(0xFFC05F37), Color(0xFFFBEEDF), Color(0xFFE28159)),
    'brick': BookCoverColors(Color(0xFF8A4A3B), Color(0xFFF6E7D4), Color(0xFFAC6C5D)),
  };

  /// Condition chips — the 4 spec conditions all use the honey pill style
  /// (mock #2a). Legacy 6-value keys retained until Phase B lands everywhere.
  static const Map<String, ConditionColors> conditionColors = {
    // Spec v1 conditions
    'like_new': ConditionColors(honeyDeep, honey),
    'very_good': ConditionColors(honeyDeep, honey),
    'good': ConditionColors(honeyDeep, honey),
    'well_read': ConditionColors(honeyDeep, honey),
    // Legacy display-name keys (remove in Phase L)
    'New': ConditionColors(honeyDeep, honey),
    'Like New': ConditionColors(honeyDeep, honey),
    'Very Good': ConditionColors(honeyDeep, honey),
    'Good': ConditionColors(honeyDeep, honey),
    'Acceptable': ConditionColors(honeyDeep, honey),
    'Poor': ConditionColors(honeyDeep, honey),
  };

  /// Trade status colors (text + tint backgrounds, per mocks #2c/#2d).
  /// Legacy status keys retained until Phase B lands everywhere.
  static const Map<String, StatusColors> statusColors = {
    // Spec v1 statuses
    'requested': StatusColors('Requested', ink2, neutralTint),
    'accepted': StatusColors('Accepted', green, greenTint),
    'swapped': StatusColors('Swapped', greenDeep, greenTint),
    'declined': StatusColors('Declined', terracotta, terracottaTint),
    'cancelled': StatusColors('Cancelled', terracotta, terracottaTint),
    'expired': StatusColors('Expired', ink3, neutralTint),
    // Legacy keys (remove in Phase L)
    'request_pending': StatusColors('Request', honeyDeep, honey),
    'pending': StatusColors('Pending', ink2, neutralTint),
    'rejected': StatusColors('Declined', terracotta, terracottaTint),
    'completed': StatusColors('Completed', greenDeep, greenTint),
  };
}

class BookCoverColors {
  final Color background;
  final Color ink;
  final Color rule;

  const BookCoverColors(this.background, this.ink, this.rule);
}

class ConditionColors {
  final Color foreground;
  final Color background;

  const ConditionColors(this.foreground, this.background);
}

class StatusColors {
  final String label;
  final Color foreground;
  final Color background;

  const StatusColors(this.label, this.foreground, this.background);
}

/// App typography.
///
/// Display: Young Serif. UI/body: Schibsted Grotesk. (Spec §10.)
class AppTypography {
  // Young Serif ships only a regular weight; heavier "weights" are still the
  // same face — keep the weight parameter for fallback rendering consistency.
  static TextStyle get serifRegular =>
      GoogleFonts.youngSerif(fontWeight: FontWeight.w400);

  static TextStyle get serifMedium =>
      GoogleFonts.youngSerif(fontWeight: FontWeight.w400);

  static TextStyle get serifSemiBold =>
      GoogleFonts.youngSerif(fontWeight: FontWeight.w400);

  static TextStyle get serifItalic =>
      GoogleFonts.youngSerif(fontStyle: FontStyle.italic);

  static TextStyle get sansRegular =>
      GoogleFonts.schibstedGrotesk(fontWeight: FontWeight.w400);

  static TextStyle get sansMedium =>
      GoogleFonts.schibstedGrotesk(fontWeight: FontWeight.w500);

  static TextStyle get sansSemiBold =>
      GoogleFonts.schibstedGrotesk(fontWeight: FontWeight.w600);

  static TextStyle get sansBold =>
      GoogleFonts.schibstedGrotesk(fontWeight: FontWeight.w700);

  static TextStyle get sansExtraBold =>
      GoogleFonts.schibstedGrotesk(fontWeight: FontWeight.w800);
}

/// App theme configuration
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.green,
      colorScheme: const ColorScheme.light(
        primary: AppColors.green,
        onPrimary: AppColors.bg,
        secondary: AppColors.honeyAccent,
        onSecondary: AppColors.ink,
        surface: AppColors.bg,
        onSurface: AppColors.ink,
        error: AppColors.terracotta,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.serifSemiBold.copyWith(
          fontSize: 18,
          color: AppColors.ink,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.line, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.line, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.green, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTypography.sansRegular.copyWith(
          fontSize: 15,
          color: AppColors.ink3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: AppColors.bg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTypography.sansExtraBold.copyWith(fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.line, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTypography.sansBold.copyWith(fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          textStyle: AppTypography.sansBold.copyWith(fontSize: 13),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.green,
        unselectedItemColor: AppColors.ink3,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.serifSemiBold.copyWith(
          fontSize: 30,
          color: AppColors.ink,
          height: 1.15,
        ),
        displayMedium: AppTypography.serifSemiBold.copyWith(
          fontSize: 26,
          color: AppColors.ink,
        ),
        displaySmall: AppTypography.serifSemiBold.copyWith(
          fontSize: 22,
          color: AppColors.ink,
        ),
        headlineLarge: AppTypography.serifSemiBold.copyWith(
          fontSize: 20,
          color: AppColors.ink,
        ),
        headlineMedium: AppTypography.serifSemiBold.copyWith(
          fontSize: 18,
          color: AppColors.ink,
        ),
        headlineSmall: AppTypography.serifSemiBold.copyWith(
          fontSize: 16,
          color: AppColors.ink,
        ),
        titleLarge: AppTypography.sansBold.copyWith(
          fontSize: 16,
          color: AppColors.ink,
        ),
        titleMedium: AppTypography.sansSemiBold.copyWith(
          fontSize: 14,
          color: AppColors.ink,
        ),
        titleSmall: AppTypography.sansSemiBold.copyWith(
          fontSize: 12,
          color: AppColors.ink2,
        ),
        bodyLarge: AppTypography.sansRegular.copyWith(
          fontSize: 15,
          color: AppColors.ink,
          height: 1.5,
        ),
        bodyMedium: AppTypography.sansRegular.copyWith(
          fontSize: 13.5,
          color: AppColors.ink2,
          height: 1.45,
        ),
        bodySmall: AppTypography.sansRegular.copyWith(
          fontSize: 12,
          color: AppColors.ink3,
        ),
        labelLarge: AppTypography.sansBold.copyWith(
          fontSize: 14,
          color: AppColors.ink,
        ),
        labelMedium: AppTypography.sansSemiBold.copyWith(
          fontSize: 12,
          color: AppColors.ink2,
        ),
        labelSmall: AppTypography.sansSemiBold.copyWith(
          fontSize: 10.5,
          letterSpacing: 0.4,
          color: AppColors.ink3,
        ),
      ),
    );
  }
}
