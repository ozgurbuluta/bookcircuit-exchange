import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turtle_turning_pages/config/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Never fetch fonts over the network in tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppColors — core palette (docs/design-package/TOKENS.md)', () {
    test('backgrounds and lines', () {
      expect(AppColors.bg, const Color(0xFFFAF5E9));
      expect(AppColors.surface, const Color(0xFFFFFCF4));
      expect(AppColors.line, const Color(0xFFE8E2CE));
    });

    test('ink scale', () {
      expect(AppColors.ink, const Color(0xFF20291F));
      expect(AppColors.ink2, const Color(0xFF5F6A5C));
      expect(AppColors.ink3, const Color(0xFF939C8D));
    });

    test('brand greens', () {
      expect(AppColors.green, const Color(0xFF2F5240));
      expect(AppColors.greenDeep, const Color(0xFF24382B));
      expect(AppColors.greenTint, const Color(0xFFE8EEDF));
    });

    test('honey (points / system pills / condition chips)', () {
      expect(AppColors.honey, const Color(0xFFF6E7C8));
      expect(AppColors.honeyDeep, const Color(0xFF96621C));
      expect(AppColors.honeyAccent, const Color(0xFFD9952F));
    });

    test('terracotta (destructive / unread)', () {
      expect(AppColors.terracotta, const Color(0xFFC05F37));
      expect(AppColors.terracottaTint, const Color(0xFFFBF1EA));
    });
  });

  group('AppColors — book cover palette', () {
    test('has the 7 canonical cover colorways', () {
      expect(AppColors.covers.keys, containsAll(<String>[
        'honey',
        'plum',
        'slate',
        'deepGreen',
        'forest',
        'terracotta',
        'brick',
      ]));
      expect(AppColors.covers.length, 7);
    });

    test('cover colorway values match the mocks', () {
      expect(AppColors.covers['honey']!.background, const Color(0xFFD9952F));
      expect(AppColors.covers['honey']!.ink, const Color(0xFF3A2A0E));
      expect(AppColors.covers['forest']!.background, const Color(0xFF2F5240));
      expect(AppColors.covers['forest']!.ink, const Color(0xFFF2EBD8));
      expect(
          AppColors.covers['terracotta']!.background, const Color(0xFFC05F37));
    });
  });

  group('AppColors — status + condition maps', () {
    test('new trade statuses are mapped', () {
      for (final status in [
        'requested',
        'accepted',
        'swapped',
        'declined',
        'cancelled',
        'expired',
      ]) {
        expect(AppColors.statusColors, contains(status),
            reason: 'missing status color for $status');
      }
      expect(AppColors.statusColors['accepted']!.foreground, AppColors.green);
      expect(AppColors.statusColors['cancelled']!.foreground,
          AppColors.terracotta);
      expect(AppColors.statusColors['requested']!.foreground, AppColors.ink2);
    });

    test('the 4 spec conditions are mapped and honey-styled', () {
      for (final condition in ['like_new', 'very_good', 'good', 'well_read']) {
        final colors = AppColors.conditionColors[condition];
        expect(colors, isNotNull,
            reason: 'missing condition color for $condition');
        expect(colors!.background, AppColors.honey);
        expect(colors.foreground, AppColors.honeyDeep);
      }
    });
  });

  group('AppTypography — spec fonts', () {
    test('display styles use Young Serif', () {
      expect(AppTypography.serifSemiBold.fontFamily, contains('YoungSerif'));
      expect(AppTypography.serifRegular.fontFamily, contains('YoungSerif'));
    });

    test('UI styles use Schibsted Grotesk', () {
      expect(
          AppTypography.sansRegular.fontFamily, contains('SchibstedGrotesk'));
      expect(AppTypography.sansBold.fontFamily, contains('SchibstedGrotesk'));
      expect(AppTypography.sansBold.fontWeight, FontWeight.w700);
    });
  });

  group('AppTheme', () {
    test('scaffold and scheme use the new palette', () {
      final theme = AppTheme.lightTheme;
      expect(theme.scaffoldBackgroundColor, AppColors.bg);
      expect(theme.colorScheme.primary, AppColors.green);
      expect(theme.colorScheme.error, AppColors.terracotta);
      expect(theme.cardTheme.color, AppColors.surface);
    });
  });
}
