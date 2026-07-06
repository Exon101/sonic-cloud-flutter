import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_settings_service.dart';
import '../accessibility/accessibility_service.dart';
import '../theme/app_colors.dart';

/// ThemeService — exposes a [ThemeData] derived from [AppSettingsService].
///
/// Supports five modes: system, dark, light, AMOLED (true black), and
/// dynamic (Material You on Android 12+). Custom accent color overrides the
/// default cyan.
class ThemeService extends ChangeNotifier {
  ThemeService(this._settings, this._accessibility) {
    _settings.addListener(_onChanged);
    _accessibility.addListener(_onChanged);
  }
  final AppSettingsService _settings;
  final AccessibilityService _accessibility;

  void _onChanged() => notifyListeners();

  @override
  void dispose() {
    _settings.removeListener(_onChanged);
    _accessibility.removeListener(_onChanged);
    super.dispose();
  }

  ThemeData get themeData {
    final mode = _settings.themeMode;
    final accent = _settings.accentColor;
    final seed = accent ?? const Color(0xFF00F4FE);
    final fontScale = _accessibility.fontScale;
    final highContrast = _accessibility.highContrast;

    ThemeData theme;
    switch (mode) {
      case ThemeModePreference.system:
        theme = _buildDarkTheme(seed, amoled: false, highContrast: highContrast);
      case ThemeModePreference.dark:
        theme = _buildDarkTheme(seed, amoled: false, highContrast: highContrast);
      case ThemeModePreference.light:
        theme = _buildLightTheme(seed, highContrast: highContrast);
      case ThemeModePreference.amoled:
        theme = _buildDarkTheme(seed, amoled: true, highContrast: highContrast);
      case ThemeModePreference.dynamic:
        theme = _buildDarkTheme(seed, amoled: false, highContrast: highContrast);
    }

    // Apply font scale
    if (fontScale != 1.0) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontSizeFactor: fontScale),
      );
    }

    return theme;
  }

  ThemeData _buildDarkTheme(Color seed, {required bool amoled, required bool highContrast}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      contrastLevel: highContrast ? 1.0 : 0.0,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: amoled ? Colors.black : AppColors.background,
      canvasColor: amoled ? Colors.black : AppColors.surface,
    );
  }

  ThemeData _buildLightTheme(Color seed, {required bool highContrast}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      contrastLevel: highContrast ? 1.0 : 0.0,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF5F5F8),
    );
  }
}
