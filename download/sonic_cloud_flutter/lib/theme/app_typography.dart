import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sonic Cloud typography.
///
/// Dual-font strategy per spec:
///   - Montserrat (700 / 600) → headlines
///   - Inter (400 / 500 / 600) → body, labels, metadata
///
/// Each `TextStyle` here maps 1:1 to a token in `sonic_cloud.md`'s `typography:` map.
class AppTypography {
  AppTypography._();

  // ── Headlines (Montserrat) ────────────────────────────────────────────────
  static TextStyle get headlineXl => GoogleFonts.montserrat(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        letterSpacing: -0.02 * 32 / 32,
      );

  static TextStyle get headlineLg => GoogleFonts.montserrat(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
      );

  static TextStyle get headlineMd => GoogleFonts.montserrat(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
      );

  // ── Body (Inter) ──────────────────────────────────────────────────────────
  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 28 / 18,
      );

  static TextStyle get bodyMd => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
      );

  /// Adds a `body-sm` token the HTML analysis flagged as missing.
  /// Defined here for consistency so song-row metadata has a typed scale.
  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 18 / 13,
      );

  // ── Labels (Inter) ────────────────────────────────────────────────────────
  static TextStyle get labelMd => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0.01 * 14,
      );

  static TextStyle get labelSm => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.05 * 12,
      );
}
