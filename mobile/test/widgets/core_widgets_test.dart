import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turtle_turning_pages/config/theme.dart';
import 'package:turtle_turning_pages/widgets/points_badge.dart';
import 'package:turtle_turning_pages/widgets/rating_stars.dart';
import 'package:turtle_turning_pages/widgets/rating_tag_chip.dart';
import 'package:turtle_turning_pages/widgets/status_chip.dart';
import 'package:turtle_turning_pages/widgets/system_message_pill.dart';
import 'package:turtle_turning_pages/widgets/unread_badge.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('PointsBadge', () {
    testWidgets('renders the points amount in the honey pill', (tester) async {
      await tester.pumpWidget(_wrap(const PointsBadge(points: 200)));

      expect(find.text('200 pts'), findsOneWidget);

      final container = tester.widget<Container>(find.byKey(
        const Key('points_badge_container'),
      ));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.honey);
    });

    testWidgets('fires onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        PointsBadge(points: 50, onTap: () => tapped = true),
      ));

      await tester.tap(find.byType(PointsBadge));
      expect(tapped, isTrue);
    });
  });

  group('RatingStars', () {
    testWidgets('displays the given rating as filled stars', (tester) async {
      await tester.pumpWidget(_wrap(const RatingStars(rating: 3)));

      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .toList(growable: false);
      expect(icons.length, 5);
      expect(
          icons.where((i) => i.color == AppColors.honeyAccent).length, 3);
    });

    testWidgets('input mode reports taps', (tester) async {
      int? selected;
      await tester.pumpWidget(_wrap(
        RatingStars(rating: 0, onChanged: (v) => selected = v),
      ));

      await tester.tap(find.byKey(const Key('rating_star_4')));
      expect(selected, 4);
    });

    testWidgets('is not interactive without onChanged', (tester) async {
      await tester.pumpWidget(_wrap(const RatingStars(rating: 2)));
      // Should not throw and no gesture detectors wired to stars
      await tester.tap(find.byKey(const Key('rating_star_5')));
      // nothing to assert beyond "no crash": display-only
    });
  });

  group('RatingTagChip', () {
    testWidgets('unselected uses surface style', (tester) async {
      await tester.pumpWidget(_wrap(
        RatingTagChip(label: 'On time', selected: false, onTap: () {}),
      ));

      expect(find.text('On time'), findsOneWidget);
      final container = tester.widget<Container>(
          find.byKey(const Key('rating_tag_container')));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.surface);
    });

    testWidgets('selected uses green tint style and toggles', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(_wrap(
        RatingTagChip(
            label: 'Great pick', selected: true, onTap: () => tapCount++),
      ));

      final container = tester.widget<Container>(
          find.byKey(const Key('rating_tag_container')));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.greenTint);

      await tester.tap(find.byType(RatingTagChip));
      expect(tapCount, 1);
    });
  });

  group('SystemMessagePill', () {
    testWidgets('renders text in honey pill', (tester) async {
      await tester.pumpWidget(_wrap(
        const SystemMessagePill(text: 'You sent 50 pts'),
      ));

      expect(find.text('You sent 50 pts'), findsOneWidget);
      final container = tester.widget<Container>(
          find.byKey(const Key('system_pill_container')));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.honey);
    });
  });

  group('UnreadBadge', () {
    testWidgets('renders count on terracotta', (tester) async {
      await tester.pumpWidget(_wrap(const UnreadBadge(count: 3)));

      expect(find.text('3'), findsOneWidget);
      final container = tester.widget<Container>(
          find.byKey(const Key('unread_badge_container')));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.terracotta);
    });

    testWidgets('caps display at 99+', (tester) async {
      await tester.pumpWidget(_wrap(const UnreadBadge(count: 120)));
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('renders nothing for zero', (tester) async {
      await tester.pumpWidget(_wrap(const UnreadBadge(count: 0)));
      expect(find.byKey(const Key('unread_badge_container')), findsNothing);
    });
  });

  group('StatusChip', () {
    testWidgets('renders label and colors for accepted', (tester) async {
      await tester.pumpWidget(_wrap(const StatusChip(status: 'accepted')));

      expect(find.text('Accepted'), findsOneWidget);
      final container = tester.widget<Container>(
          find.byKey(const Key('status_chip_container')));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.greenTint);
    });

    testWidgets('renders terracotta for cancelled', (tester) async {
      await tester.pumpWidget(_wrap(const StatusChip(status: 'cancelled')));

      expect(find.text('Cancelled'), findsOneWidget);
      final container = tester.widget<Container>(
          find.byKey(const Key('status_chip_container')));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.terracottaTint);
    });

    testWidgets('falls back gracefully for unknown status', (tester) async {
      await tester.pumpWidget(_wrap(const StatusChip(status: 'bogus')));
      // Unknown statuses render the raw value, neutral-styled, no crash.
      expect(find.text('bogus'), findsOneWidget);
    });
  });
}
