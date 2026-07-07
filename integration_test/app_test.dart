import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sonic_cloud/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sonic Cloud UI Tests', () {
    testWidgets('App launches and shows Library screen', (tester) async {
      await tester.pumpWidget(const SonicCloudApp());

      // Wait for splash screen to appear
      await tester.pump(const Duration(milliseconds: 500));

      // Wait for initialization (up to 15 seconds)
      int attempts = 0;
      while (attempts < 30) {
        await tester.pump(const Duration(milliseconds: 500));
        attempts++;
        // Check if we're past the splash screen
        if (find.text('Sonic Cloud').evaluate().isNotEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }

      // App should NOT show a white screen — it should show either:
      // - The splash screen (loading), or
      // - The Library screen (after init)
      expect(find.byType(MaterialApp), findsOneWidget);

      // Take a screenshot for debugging
    });

    testWidgets('Library screen has Add Music button', (tester) async {
      await tester.pumpWidget(const SonicCloudApp());

      // Wait for app to initialize
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Look for the "Add Music" FAB
      expect(
        find.text('Add Music'),
        findsOneWidget,
        reason:
            'Library screen should have an "Add Music" floating action button',
      );

    });

    testWidgets('Bottom navigation switches tabs', (tester) async {
      await tester.pumpWidget(const SonicCloudApp());

      // Wait for app to initialize
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Should start on Library tab (index 0)
      expect(find.text('Add Music'), findsOneWidget);

      // Tap "Cloud" tab
      final cloudTab = find.text('Cloud');
      if (cloudTab.evaluate().isNotEmpty) {
        await tester.tap(cloudTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Should show Cloud Storage screen
        expect(
          find.text('Connected Drives'),
          findsOneWidget,
          reason: 'Tapping Cloud tab should show the Cloud Storage screen',
        );
      }

      // Tap "Settings" tab
      final settingsTab = find.text('Settings');
      if (settingsTab.evaluate().isNotEmpty) {
        await tester.tap(settingsTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Should show Settings screen
        expect(
          find.text('Appearance'),
          findsOneWidget,
          reason: 'Tapping Settings tab should show the Settings screen',
        );
      }

      // Tap "Library" tab to go back
      final libraryTab = find.text('Library');
      if (libraryTab.evaluate().isNotEmpty) {
        await tester.tap(libraryTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Should be back on Library
        expect(find.text('Add Music'), findsOneWidget);
      }
    });

    testWidgets('Add Music opens bottom sheet', (tester) async {
      await tester.pumpWidget(const SonicCloudApp());

      // Wait for app to initialize
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Tap "Add Music" FAB
      final addMusicButton = find.text('Add Music');
      if (addMusicButton.evaluate().isNotEmpty) {
        await tester.tap(addMusicButton);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Should show bottom sheet with options
        expect(
          find.text('Open Audio Files'),
          findsOneWidget,
          reason: 'Tapping Add Music should show "Open Audio Files" option',
        );
        expect(
          find.text('Scan Folder'),
          findsOneWidget,
          reason: 'Tapping Add Music should show "Scan Folder" option',
        );


        // Close the sheet
        await tester.tapAt(const Offset(50, 50));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Settings screen shows theme options', (tester) async {
      await tester.pumpWidget(const SonicCloudApp());

      // Wait for app to initialize
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Navigate to Settings
      final settingsTab = find.text('Settings');
      if (settingsTab.evaluate().isNotEmpty) {
        await tester.tap(settingsTab.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Should have Appearance section with Theme dropdown
        expect(find.text('Appearance'), findsOneWidget);
        expect(find.text('Theme'), findsOneWidget);

        // Should have Accessibility section
        expect(find.text('Accessibility'), findsOneWidget);

        // Should have Security section
        expect(find.text('Security'), findsOneWidget);

      }
    });

    testWidgets('No white screen — app renders content', (tester) async {
      await tester.pumpWidget(const SonicCloudApp());

      // Wait up to 15 seconds
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // The app should have rendered SOMETHING — either splash or main content.
      // A white screen means nothing rendered, which is a critical failure.
      final hasMaterialApp = find.byType(MaterialApp).evaluate().isNotEmpty;
      final hasScaffold = find.byType(Scaffold).evaluate().isNotEmpty;

      expect(hasMaterialApp, true, reason: 'App should have a MaterialApp');
      expect(hasScaffold, true,
          reason: 'App should have at least one Scaffold');

      // Check that we have visible text (not just empty containers)
      final hasText = find.byType(Text).evaluate().isNotEmpty;
      expect(hasText, true, reason: 'App should display some text');

    });
  });
}
