import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/main.dart';

void main() {
  group('SonicCloudApp smoke test', () {
    testWidgets('renders the Library screen with key elements', (tester) async {
      await tester.pumpWidget(const SonicCloudApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Top app bar wordmark
      expect(find.text('Sonic Cloud'), findsWidgets);
      // Search field hint
      expect(find.text('Search your library...'), findsOneWidget);
      // Filter chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Artists'), findsOneWidget);
      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('Playlists'), findsOneWidget);
      // Section headings
      expect(find.text('Recently Played'), findsOneWidget);
      expect(find.text('All Songs'), findsOneWidget);
      // First track in the list (mock data)
      expect(find.text('Starlight Drift'), findsOneWidget);
    });

    testWidgets('tapping the Cloud nav item switches to Cloud Storage', (
      tester,
    ) async {
      await tester.pumpWidget(const SonicCloudApp());
      await tester.pumpAndSettle();

      // Cloud nav item is labeled 'Cloud'
      await tester.tap(find.text('Cloud').first);
      await tester.pumpAndSettle();

      expect(find.text('Cloud Storage'), findsOneWidget);
      expect(find.text('Connected Drives'), findsOneWidget);
      expect(find.text('Recent Sync Activity'), findsOneWidget);
    });

    testWidgets('tapping the Settings nav item switches to Settings', (
      tester,
    ) async {
      await tester.pumpWidget(const SonicCloudApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();

      // The settings page has a "Log Out" button.
      expect(find.text('Log Out'), findsOneWidget);
      // The mock user is "Alex Mercer".
      expect(find.text('Alex Mercer'), findsOneWidget);
    });

    testWidgets('tapping the first track opens Now Playing', (tester) async {
      await tester.pumpWidget(const SonicCloudApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Starlight Drift'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Now Playing header label
      expect(find.text('NOW PLAYING'), findsOneWidget);
      // Track title is shown again in Now Playing.
      expect(find.text('Starlight Drift'), findsOneWidget);
    });
  });
}
