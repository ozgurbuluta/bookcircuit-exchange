import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for Turtle Turning Pages
/// Warm, literary palette with paper/ink tones and terracotta accents
class AppColors {
  // Primary palette - warm paper tones
  static const Color paper = Color(0xFFF0E6D4);
  static const Color paper2 = Color(0xFFFBF6EC);
  static const Color paper3 = Color(0xFFF6EEDF);

  // Ink colors - espresso tones
  static const Color ink = Color(0xFF2A211A);
  static const Color ink2 = Color(0xFF5C4F42);
  static const Color ink3 = Color(0xFF92816E);

  // Accent colors
  static const Color rust = Color(0xFFB0492A);
  static const Color rust2 = Color(0xFF8F3A1F);
  static const Color sage = Color(0xFF5E7355);
  static const Color gold = Color(0xFFB5812F);

  // Lines & borders
  static const Color line = Color(0x1A2A211A); // 10% ink
  static const Color line2 = Color(0x0F2A211A); // 6% ink

  // Book cover palette
  static const Map<String, BookCoverColors> covers = {
    'oxblood': BookCoverColors(Color(0xFF6E2B2B), Color(0xFFF3E4D2), Color(0xFFB07A5A)),
    'olive': BookCoverColors(Color(0xFF5A5A36), Color(0xFFF1ECD6), Color(0xFFA9A86A)),
    'dusty': BookCoverColors(Color(0xFF3F5468), Color(0xFFE8EEF2), Color(0xFF8FA9BE)),
    'ochre': BookCoverColors(Color(0xFFB5812F), Color(0xFFFBF3DF), Color(0xFFE6C57E)),
    'plum': BookCoverColors(Color(0xFF4A3552), Color(0xFFEFE3F0), Color(0xFF9C82A6)),
    'terra': BookCoverColors(Color(0xFFA24A2C), Color(0xFFF8E6D6), Color(0xFFD89070)),
    'forest': BookCoverColors(Color(0xFF2F4A3A), Color(0xFFE3EFE5), Color(0xFF7FA98C)),
    'slate': BookCoverColors(Color(0xFF3A3A42), Color(0xFFE9E9EE), Color(0xFF8E8E9C)),
    'sand': BookCoverColors(Color(0xFFC9B286), Color(0xFF3A2E1E), Color(0xFF8A7350)),
    'ink': BookCoverColors(Color(0xFF24201C), Color(0xFFE8C98C), Color(0xFF7A6A4E)),
  };

  // Condition badge colors
  static const Map<String, ConditionColors> conditionColors = {
    'New': ConditionColors(Color(0xFF2F4A3A), Color(0xFFE3EFE5)),
    'Like New': ConditionColors(Color(0xFF2F4A3A), Color(0xFFE3EFE5)),
    'Very Good': ConditionColors(Color(0xFF3F5468), Color(0xFFE6EDF2)),
    'Good': ConditionColors(Color(0xFFB5812F), Color(0xFFFBF1DA)),
    'Acceptable': ConditionColors(Color(0xFF9A6A2E), Color(0xFFF6E9D2)),
    'Poor': ConditionColors(Color(0xFF8F3A1F), Color(0xFFF6E0D6)),
  };

  // Trade status colors
  static const Map<String, StatusColors> statusColors = {
    'request_pending': StatusColors('Request', Color(0xFFB5812F), Color(0xFFFBF1DA)),
    'pending': StatusColors('Pending', Color(0xFF3F5468), Color(0xFFE6EDF2)),
    'accepted': StatusColors('Accepted', Color(0xFF2F4A3A), Color(0xFFE3EFE5)),
    'rejected': StatusColors('Declined', Color(0xFF8F3A1F), Color(0xFFF6E0D6)),
    'completed': StatusColors('Completed', Color(0xFF5C4F42), Color(0xFFECE2D2)),
    'cancelled': StatusColors('Cancelled', Color(0xFF8B7B6A), Color(0xFFEEE7DA)),
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

/// App typography
class AppTypography {
  // Serif font for titles and literary elements
  static TextStyle get serifRegular => GoogleFonts.newsreader(
        fontWeight: FontWeight.w400,
      );

  static TextStyle get serifMedium => GoogleFonts.newsreader(
        fontWeight: FontWeight.w500,
      );

  static TextStyle get serifSemiBold => GoogleFonts.newsreader(
        fontWeight: FontWeight.w600,
      );

  static TextStyle get serifItalic => GoogleFonts.newsreader(
        fontStyle: FontStyle.italic,
      );

  // Sans-serif font for UI elements
  static TextStyle get sansRegular => GoogleFonts.hankenGrotesk(
        fontWeight: FontWeight.w400,
      );

  static TextStyle get sansMedium => GoogleFonts.hankenGrotesk(
        fontWeight: FontWeight.w500,
      );

  static TextStyle get sansSemiBold => GoogleFonts.hankenGrotesk(
        fontWeight: FontWeight.w600,
      );

  static TextStyle get sansBold => GoogleFonts.hankenGrotesk(
        fontWeight: FontWeight.w700,
      );
}

/// App theme configuration
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.paper,
      primaryColor: AppColors.rust,
      colorScheme: const ColorScheme.light(
        primary: AppColors.rust,
        onPrimary: AppColors.paper2,
        secondary: AppColors.sage,
        onSecondary: Colors.white,
        surface: AppColors.paper,
        onSurface: AppColors.ink,
        error: AppColors.rust2,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
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
        color: AppColors.paper2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.line, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paper2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.rust, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTypography.sansRegular.copyWith(
          fontSize: 15,
          color: AppColors.ink3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.rust,
          foregroundColor: AppColors.paper2,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: AppTypography.sansBold.copyWith(fontSize: 15.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.ink, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: AppTypography.sansBold.copyWith(fontSize: 15.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.rust,
          textStyle: AppTypography.sansSemiBold.copyWith(fontSize: 14),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xD2F6EEDF), // paper3 with 82% opacity
        selectedItemColor: AppColors.rust,
        unselectedItemColor: AppColors.ink3,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line2,
        thickness: 0.5,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.serifSemiBold.copyWith(
          fontSize: 32,
          color: AppColors.ink,
          letterSpacing: -0.4,
        ),
        displayMedium: AppTypography.serifSemiBold.copyWith(
          fontSize: 26,
          color: AppColors.ink,
          letterSpacing: -0.3,
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
        bodyLarge: AppTypography.serifRegular.copyWith(
          fontSize: 16,
          color: AppColors.ink2,
          height: 1.55,
        ),
        bodyMedium: AppTypography.sansRegular.copyWith(
          fontSize: 14,
          color: AppColors.ink2,
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
          letterSpacing: 0.5,
          color: AppColors.ink3,
        ),
      ),
    );
  }
}
