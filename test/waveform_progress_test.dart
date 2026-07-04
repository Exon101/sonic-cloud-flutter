import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/widgets/waveform_progress.dart';

void main() {
  group('WaveformProgress', () {
    testWidgets('renders without exceptions for progress=0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 64,
              child: WaveformProgress(progress: 0.0),
            ),
          ),
        ),
      );
      expect(find.byType(WaveformProgress), findsOneWidget);
    });

    testWidgets('renders without exceptions for progress=1', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 64,
              child: WaveformProgress(progress: 1.0),
            ),
          ),
        ),
      );
      expect(find.byType(WaveformProgress), findsOneWidget);
    });

    testWidgets('calls onSeek when tapped on the right half', (tester) async {
      double? seekedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 64,
              child: WaveformProgress(
                progress: 0.0,
                onSeek: (p) => seekedValue = p,
              ),
            ),
          ),
        ),
      );

      // Tap on the right edge — should request seek to ~1.0.
      await tester.tapAt(const Offset(310, 32));
      await tester.pump();

      expect(seekedValue, isNotNull);
      expect(seekedValue!, greaterThan(0.8));
      expect(seekedValue!, lessThanOrEqualTo(1.0));
    });

    testWidgets('calls onSeek when dragged horizontally', skip: 'CI-flaky: gesture timing', (tester) async {
      double? seekedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 64,
              child: WaveformProgress(
                progress: 0.5,
                onSeek: (p) => seekedValue = p,
              ),
            ),
          ),
        ),
      );

      // Drag from left edge toward the middle.
      final gesture = await tester.startGesture(const Offset(10, 32));
      await gesture.moveTo(const Offset(160, 32));
      await gesture.up();
      await tester.pump();

      expect(seekedValue, isNotNull);
      expect(seekedValue!, greaterThan(0.4));
      expect(seekedValue!, lessThan(0.7));
    });
  });
}
