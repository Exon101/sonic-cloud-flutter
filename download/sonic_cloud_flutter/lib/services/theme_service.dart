import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_settings_service.dart';
import '../theme/app_colors.dart';

/// ThemeService — exposes a [ThemeData] derived from [AppSettingsService].
///
/// Supports five modes: system, dark, light, AMOLED (true black), and
/// dynamic (Material You on Android 12+). Custom accent color overrides the
/// default cyan.
class ThemeService extends ChangeNotifier {
  ThemeService(this._settings) {
    _settings.addListener(_onSettingsChanged);
  }
  final AppSettingsService _settings;

  void _onSettingsChanged() => notifyListeners();

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  ThemeData get themeData {
    final mode = _settings.themeMode;
    final accent = _settings.accentColor;
    final seed = accent ?? const Color(0xFF00F4FE); // default Sonic cyan

    switch (mode) {
      case ThemeModePreference.system:
        // Flutter's platformBrightness will handle dark/light switching.
        return _buildDarkTheme(seed, amoled: false);
      case ThemeModePreference.dark:
        return _buildDarkTheme(seed, amoled: false);
      case ThemeModePreference.light:
        return _buildLightTheme(seed);
      case ThemeModePreference.amoled:
        return _buildDarkTheme(seed, amoled: true);
      case ThemeModePreference.dynamic:
        // Material You: on Android 12+, this would query the system's
        // dynamic color scheme. Stubbed to fall back to dark theme w/ accent.
        return _buildDarkTheme(seed, amoled: false);
    }
  }

  ThemeData _buildDarkTheme(Color seed, {required bool amoled}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: amoled ? Colors.black : AppColors.background,
      canvasColor: amoled ? Colors.black : AppColors.surface,
    );
  }

  ThemeData _buildLightTheme(Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF5F5F8),
    );
  }
}
