import 'package:flutter/material.dart';

/// Sonic Cloud color palette.
///
/// Mirrors the YAML frontmatter in `sonic_cloud.md` exactly.
/// Deep indigo surfaces, vibrant cyan "Sonic" energy, electric violet tertiary.
class AppColors {
  AppColors._();

  // ── Surfaces ──────────────────────────────────────────────────────────────
  static const surface = Color(0xFF131318);
  static const surfaceDim = Color(0xFF131318);
  static const surfaceBright = Color(0xFF39383E);
  static const surfaceLowest = Color(0xFF0E0E13);
  static const surfaceLow = Color(0xFF1B1B20);
  static const surfaceContainer = Color(0xFF1F1F25);
  static const surfaceContainerHigh = Color(0xFF2A292F);
  static const surfaceContainerHighest = Color(0xFF35343A);
  static const surfaceVariant = Color(0xFF35343A);

  // ── On-surface text ───────────────────────────────────────────────────────
  static const onSurface = Color(0xFFE4E1E9);
  static const onSurfaceVariant = Color(0xFFC8C5CE);
  static const inverseSurface = Color(0xFFE4E1E9);
  static const inverseOnSurface = Color(0xFF303036);

  // ── Outline ───────────────────────────────────────────────────────────────
  static const outline = Color(0xFF928F98);
  static const outlineVariant = Color(0xFF47464D);
  static const surfaceTint = Color(0xFFC5C3E5);

  // ── Primary (Deep Indigo) ─────────────────────────────────────────────────
  static const primary = Color(0xFFC5C3E5);
  static const onPrimary = Color(0xFF2E2E48);
  static const primaryContainer = Color(0xFF12122B);
  static const onPrimaryContainer = Color(0xFF7D7C9B);
  static const inversePrimary = Color(0xFF5C5C79);
  static const primaryFixed = Color(0xFFE2DFFF);
  static const primaryFixedDim = Color(0xFFC5C3E5);
  static const onPrimaryFixed = Color(0xFF191932);
  static const onPrimaryFixedVariant = Color(0xFF444460);

  // ── Secondary (Vibrant Cyan — the "Sonic" energy) ─────────────────────────
  static const secondary = Color(0xFFE6FEFF);
  static const onSecondary = Color(0xFF003739);
  static const secondaryContainer = Color(0xFF00F4FE);
  static const onSecondaryContainer = Color(0xFF006C71);
  static const secondaryFixed = Color(0xFF63F7FF);
  static const secondaryFixedDim = Color(0xFF00DCE5);
  static const onSecondaryFixed = Color(0xFF002021);
  static const onSecondaryFixedVariant = Color(0xFF004F53);

  // ── Tertiary (Electric Violet) ────────────────────────────────────────────
  static const tertiary = Color(0xFFC9BFFF);
  static const onTertiary = Color(0xFF2E009C);
  static const tertiaryContainer = Color(0xFF130051);
  static const onTertiaryContainer = Color(0xFF7F66FF);
  static const tertiaryFixed = Color(0xFFE5DEFF);
  static const tertiaryFixedDim = Color(0xFFC9BFFF);
  static const onTertiaryFixed = Color(0xFF1A0063);
  static const onTertiaryFixedVariant = Color(0xFF441CC8);

  // ── Error ─────────────────────────────────────────────────────────────────
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const onErrorContainer = Color(0xFFFFDAD6);

  // ── Background ────────────────────────────────────────────────────────────
  static const background = Color(0xFF131318);
  static const onBackground = Color(0xFFE4E1E9);

  // ── Brand gradient stops ──────────────────────────────────────────────────
  /// Background gradient from `#12122B` (top) to `#0A0A0F` (bottom).
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF12122B), Color(0xFF0A0A0F)],
  );

  /// Sonic glow color used for active playback elements.
  static const sonicGlow = Color(0xFF00F4FE);
}
