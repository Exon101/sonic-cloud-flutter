import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AccessibilityService — user-tunable accessibility settings.
///
/// Features:
///   - High-contrast theme (boosts text contrast, removes subtle gradients)
///   - Adjustable font scale (0.85×–1.5×)
///   - Color-blind-friendly visualizations (deuteranopia / protanopia / tritanopia)
///   - Reduced motion (disables animations)
///   - Motor accessibility: larger touch targets (min 48×48)
///   - Screen-reader-friendly: ensure all interactive elements have labels
///
/// All settings are persisted via SharedPreferences.
class AccessibilityService extends ChangeNotifier {
  AccessibilityService(this._prefs);

  final SharedPreferences _prefs;

  bool get highContrast => _prefs.getBool('a11y_high_contrast') ?? false;
  Future<void> setHighContrast(bool v) async {
    await _prefs.setBool('a11y_high_contrast', v);
    notifyListeners();
  }

  /// Font scale multiplier. 1.0 = system default.
  double get fontScale => _prefs.getDouble('a11y_font_scale') ?? 1.0;
  Future<void> setFontScale(double v) async {
    await _prefs.setDouble('a11y_font_scale', v.clamp(0.85, 1.5));
    notifyListeners();
  }

  /// Colorblind mode: 'none', 'deuteranopia', 'protanopia', 'tritanopia'.
  String get colorblindMode => _prefs.getString('a11y_colorblind') ?? 'none';
  Future<void> setColorblindMode(String v) async {
    await _prefs.setString('a11y_colorblind', v);
    notifyListeners();
  }

  bool get reducedMotion => _prefs.getBool('a11y_reduced_motion') ?? false;
  Future<void> setReducedMotion(bool v) async {
    await _prefs.setBool('a11y_reduced_motion', v);
    notifyListeners();
  }

  bool get largeTouchTargets => _prefs.getBool('a11y_large_touch') ?? false;
  Future<void> setLargeTouchTargets(bool v) async {
    await _prefs.setBool('a11y_large_touch', v);
    notifyListeners();
  }

  /// Effective minimum touch target size based on [largeTouchTargets].
  double get minTouchTarget => largeTouchTargets ? 56.0 : 44.0;

  /// Apply the font scale to a [TextStyle].
  TextStyle scaleTextStyle(TextStyle base) {
    if (base.fontSize == null) return base;
    return base.copyWith(fontSize: base.fontSize! * fontScale);
  }

  /// Adjust a color for the active colorblind mode.
  /// (Simulates the visual change for users without the condition so designers
  /// can preview. For users WITH the condition, real correction requires
  /// Daltonizer-style shader post-processing — left as future work.)
  Color adjustColor(Color c) {
    switch (colorblindMode) {
      case 'deuteranopia':
        // Boost blue/cyan to compensate for green weakness.
        return Color.fromARGB(
          c.alpha,
          (c.red * 0.8).round().clamp(0, 255),
          c.green,
          (c.blue * 1.2).round().clamp(0, 255),
        );
      case 'protanopia':
        // Boost green to compensate for red weakness.
        return Color.fromARGB(
          c.alpha,
          c.red,
          (c.green * 1.2).round().clamp(0, 255),
          c.blue,
        );
      case 'tritanopia':
        // Boost red to compensate for blue weakness.
        return Color.fromARGB(
          c.alpha,
          (c.red * 1.2).round().clamp(0, 255),
          c.green,
          (c.blue * 0.8).round().clamp(0, 255),
        );
      default:
        return c;
    }
  }
}
