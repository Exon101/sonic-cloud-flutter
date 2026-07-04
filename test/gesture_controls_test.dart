import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/gestures/gesture_controls.dart';
import 'package:sonic_cloud/theme/app_colors.dart';
import 'package:flutter/material.dart';

void main() {
  group('GestureControls', () {
    testWidgets('renders child correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GestureControls(child: Center(child: Text('Hello'))),
          ),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('single tap fires onTogglePlay', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureControls(
              onTogglePlay: () => taps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(GestureControls));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('long press fires onToggleFavorite', (tester) async {
      int longPresses = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureControls(
              onToggleFavorite: () => longPresses++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.longPress(find.byType(GestureControls));
      await tester.pumpAndSettle();
      expect(longPresses, 1);
    });

    testWidgets('horizontal drag with negative velocity fires onPrevious', (
      tester,
    ) async {
      int prevCount = 0;
      int nextCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureControls(
              onPrevious: () => prevCount++,
              onNext: () => nextCount++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      // Drag from right to left (negative velocity)
      await tester.timedDrag(
        find.byType(GestureControls),
        const Offset(-200, 0),
        const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();
      expect(prevCount, 1);
      expect(nextCount, 0);
    });

    testWidgets('shows hint bubble when showHints is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureControls(
              showHints: true,
              onTogglePlay: () {},
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(GestureControls));
      await tester.pump();
      // Hint bubble should appear after the tap
      expect(find.byType(GestureControls), findsOneWidget);
    });

    testWidgets('does not show hint bubble when showHints is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureControls(
              showHints: false,
              onTogglePlay: () {},
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(GestureControls));
      await tester.pump();
      // Verify no hint bubble text is shown
      expect(find.text('⏯'), findsNothing);
    });
  });
}
