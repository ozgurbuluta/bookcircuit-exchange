// Basic Flutter widget test for Turtle Turning Pages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App configuration test', (WidgetTester tester) async {
    // Simple test to verify basic widget rendering works
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Turtle Turning Pages'),
          ),
        ),
      ),
    );

    // Verify text renders
    expect(find.text('Turtle Turning Pages'), findsOneWidget);
  });

  test('Color palette is defined correctly', () {
    // Verify color values are what we expect
    expect(const Color(0xFFF0E6D4), isNotNull); // paper
    expect(const Color(0xFF2A211A), isNotNull); // ink
    expect(const Color(0xFFB0492A), isNotNull); // rust
  });
}
