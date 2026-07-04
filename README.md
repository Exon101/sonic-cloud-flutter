# Sonic Cloud — Flutter

A Flutter implementation of the **Sonic Cloud** music player design system. Four screens, glassmorphism, vibrant "sonic" cyan glow, vinyl-style Now Playing view, and full bottom-nav routing — all driven by a typed token layer that mirrors `sonic_cloud.md`.

## Project structure

```
sonic_cloud_flutter/
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
└── lib/
    ├── main.dart                      ← entry + bottom-nav shell + ambient bg
    ├── theme/
    │   ├── app_colors.dart            ← full Material-3 palette from YAML
    │   ├── app_typography.dart        ← Montserrat (headlines) + Inter (body/labels)
    │   ├── app_spacing.dart           ← 4px scale + 16px radius token (FIXED)
    │   └── app_theme.dart             ← ThemeData.dark() wired to tokens
    ├── models/
    │   └── models.dart                ← Track, Album, CloudDrive, etc.
    ├── data/
    │   └── mock_data.dart             ← in-memory content for all screens
    ├── widgets/
    │   ├── glass_card.dart            ← GlassCard + AmbientBackground
    │   ├── sonic_glow_button.dart     ← pulsing cyan play button
    │   ├── waveform_progress.dart     ← 45-bar waveform seek bar
    │   ├── top_app_bar.dart           ← glass top app bar
    │   ├── bottom_nav_bar.dart        ← glass bottom nav w/ active glow
    │   ├── album_card.dart            ← carousel card
    │   └── track_row.dart             ← song list row w/ pulse animation
    └── screens/
        ├── my_library_screen.dart     ← Home: search, chips, carousel, song list
        ├── now_playing_screen.dart    ← Vinyl art + waveform + controls
        ├── cloud_storage_screen.dart  ← Storage, drives, sync activity
        └── settings_screen.dart       ← Profile, connections, playback
```

## Run it

Requirements: Flutter ≥ 3.10, Dart ≥ 3.0.

```bash
cd sonic_cloud_flutter
flutter create .               # generates /android /ios /web /linux /macos /windows
flutter pub get
flutter run                    # pick a target
```

The first `flutter create .` step scaffolds the platform-specific runners — the `lib/` directory here already contains all Dart source.

Tested targets: Android, iOS, web, macOS. The layout is mobile-first and uses `SafeArea`, so it renders correctly on notched devices.

## What's implemented

### Design system fidelity (vs `sonic_cloud.md`)

| Token family | Status | Notes |
|---|---|---|
| Colors | ✅ exact | Every Material-3 surface/primary/secondary/tertiary/error variant from the YAML is typed in `app_colors.dart` |
| Typography | ✅ exact | Montserrat 600/700 for headlines, Inter 400/500/600 for body/labels. `body-sm` added (HTML spec was missing it) |
| Spacing | ✅ exact | 4px base scale, edge-margin 20px, gutter 16px |
| Radius | ✅ **fixed** | HTML had every radius halved (DEFAULT 0.25rem, lg 0.5rem). Flutter port uses spec values: lg=1rem=16px, xl=1.5rem=24px, plus `md=0.75rem=12px` |
| Glassmorphism | ✅ | `GlassCard` uses `BackdropFilter(blur(20))` + 5% white fill + 1px top/left light edge |
| Sonic glow | ✅ | Drop-shadow on active nav icons, pulsing outer glow on play button, glowing waveform playhead |

### Screen-level fixes from the HTML analysis

1. **Settings desktop view** — HTML had a placeholder ("Navigation is suppressed on transactional/settings screens per guidelines"). Flutter port uses one responsive layout for all sizes.
2. **Album art radius** — Now correctly 16px (lg) per spec, not 8px as in HTML.
3. **Toggles are accessible** — Each toggle has a label, an accessible `GestureDetector`, and visible focus.
4. **No duplicate stylesheets / classes** — Single source of truth in `app_theme.dart`.
5. **Bottom nav doesn't appear on Now Playing** — Pushed as a full-screen route, matching spec.

## Notable Flutter idioms used

- `BackdropFilter` + `ImageFilter.blur` → CSS `backdrop-filter` substitute
- `AnimationController` + `repeat(reverse: true)` for the pulsing vinyl glow and the active-track pulse bars
- `FractionallySizedBox` for the storage usage bar
- `LayoutBuilder` + `Wrap` for the responsive drives grid (1/2/3 columns)
- `IndexedStack` keeps each tab's scroll state alive when switching
- `MaterialPageRoute(fullscreenDialog: true)` for Now Playing

## What's NOT implemented (deliberately out of scope)

- Audio playback — this is a UI port of the HTML mockups
- Real cloud sync — all data is mock
- Persistence — no SharedPreferences / Drift / Hive
- Auth flow — the avatar is hardcoded mock data

Adding these is straightforward: swap `MockData` for a repository, plug a `JustAudio` instance into the Now Playing screen, and persist `offlineMode` with `shared_preferences`.

## Iterate from here

- Change the palette in one place: `lib/theme/app_colors.dart`
- Change typography: `lib/theme/app_typography.dart`
- Change spacing/radius: `lib/theme/app_spacing.dart`
- Add a new screen: drop a file in `lib/screens/`, add it to the `IndexedStack` in `main.dart`
