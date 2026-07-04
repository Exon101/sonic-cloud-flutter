/// Sonic Cloud spacing & radius scale.
///
/// Mirrors the `spacing` and `rounded` maps in `sonic_cloud.md`.
/// NOTE: This file corrects the radius token bug found in the HTML analysis —
/// the HTML Tailwind config halved every radius value. Here they match the spec.
class AppSpacing {
  AppSpacing._();

  // ── Spacing scale (4px base) ──────────────────────────────────────────────
  static const double base = 4;
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;
  static const double edgeMargin = 20;
  static const double gutter = 16;

  // ── Minimum touch target (spec: 44x44) ────────────────────────────────────
  static const double touchTarget = 44;
}

/// Radius scale per `sonic_cloud.md` `rounded:` map.
class AppRadius {
  AppRadius._();

  static const double sm = 0.25 * 16; // 0.25rem → 4px
  static const double def = 0.5 * 16; // 0.5rem  → 8px  (DEFAULT)
  static const double md = 0.75 * 16; // 0.75rem → 12px
  static const double lg = 1.0 * 16; // 1rem    → 16px (album art, glass cards)
  static const double xl = 1.5 * 16; // 1.5rem  → 24px
  static const double full = 9999; // pill / circle
}
