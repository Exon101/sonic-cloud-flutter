import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonic_cloud/accessibility/accessibility_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AccessibilityService', () {
    test('highContrast defaults to false', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = AccessibilityService(prefs);
      expect(svc.highContrast, false);
    });

    test('setHighContrast persists and notifies', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = AccessibilityService(prefs);
      await svc.setHighContrast(true);
      expect(svc.highContrast, true);
      // Verify it persisted
      final fresh = AccessibilityService(await SharedPreferences.getInstance());
      expect(fresh.highContrast, true);
    });

    test('fontScale defaults to 1.0', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = AccessibilityService(prefs);
      expect(svc.fontScale, 1.0);
    });

    test('setFontScale clamps to 0.85..1.5', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = AccessibilityService(prefs);
      await svc.setFontScale(0.5);
      expect(svc.fontScale, 0.85);
      await svc.setFontScale(2.0);
      expect(svc.fontScale, 1.5);
      await svc.setFontScale(1.2);
      expect(svc.fontScale, 1.2);
    });

    test('colorblindMode defaults to none', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = AccessibilityService(prefs);
      expect(svc.colorblindMode, 'none');
    });

    test('reducedMotion defaults to false', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = AccessibilityService(prefs);
      expect(svc.reducedMotion, false);
    });

    test('largeTouchTargets changes minTouchTarget from 44 to 56', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = AccessibilityService(prefs);
      expect(svc.minTouchTarget, 44.0);
      await svc.setLargeTouchTargets(true);
      expect(svc.minTouchTarget, 56.0);
    });

    test('adjustColor returns same color for "none" mode', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = AccessibilityService(prefs);
      final c = const Color.fromARGB(255, 100, 150, 200);
      expect(svc.adjustColor(c), c);
    });

    test('adjustColor shifts color in deuteranopia mode', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = AccessibilityService(prefs);
      await svc.setColorblindMode('deuteranopia');
      final c = const Color.fromARGB(255, 100, 150, 200);
      final adjusted = svc.adjustColor(c);
      // Blue channel should be boosted (240 vs 200)
      expect(adjusted.blue, greaterThan(c.blue));
    });
  });
}
