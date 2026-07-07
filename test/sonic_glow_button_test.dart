import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/widgets/sonic_glow_button.dart';

void main() {
  group('SonicGlowButton', () {
    testWidgets('shows pause icon when isPlaying=true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SonicGlowButton(isPlaying: true, onTap: () {})),
        ),
      );
      // Material Icon name 'pause_rounded' is rendered via IconData.
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('shows play icon when isPlaying=false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SonicGlowButton(isPlaying: false, onTap: () {})),
        ),
      );
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('fires onTap when tapped', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SonicGlowButton(isPlaying: false, onTap: () => taps++),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      expect(taps, 1);
    });

    testWidgets('respects custom size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SonicGlowButton(isPlaying: false, onTap: () {}, size: 100),
            ),
          ),
        ),
      );
      // The widget should render at the requested 100x100 size.
      final size = tester.getSize(find.byType(SonicGlowButton));
      expect(size.width, 100);
      expect(size.height, 100);
    });
  });

  group('GhostButton', () {
    testWidgets('renders icon and label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GhostButton(
              icon: Icons.shuffle_rounded,
              label: 'Shuffle',
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
    });

    testWidgets('fires onTap when tapped', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GhostButton(icon: Icons.shuffle_rounded, onTap: () => taps++),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.shuffle_rounded));
      expect(taps, 1);
    });
  });
}
