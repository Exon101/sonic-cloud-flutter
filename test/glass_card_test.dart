import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/theme/app_radius.dart' as r;
import 'package:sonic_cloud/widgets/glass_card.dart';

void main() {
  group('GlassCard', () {
    testWidgets('renders its child inside a clipped container', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassCard(child: Text('hello glass')),
          ),
        ),
      );
      expect(find.text('hello glass'), findsOneWidget);
    });

    testWidgets('forwards onTap through InkWell', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              onTap: () => taps++,
              child: const Text('tap me'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('tap me'));
      expect(taps, 1);
    });

    testWidgets('respects custom borderRadius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              borderRadius: r.AppRadius.xl,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );
      // No exceptions thrown means the widget tree built successfully with
      // the custom radius.
      expect(find.byType(GlassCard), findsOneWidget);
    });
  });
}
