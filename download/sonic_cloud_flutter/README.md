# Sonic Cloud

<p align="center">
  <img src="assets/icon/icon.png" width="120" height="120" alt="Sonic Cloud logo" />
</p>

<p align="center">
  <strong>A premium glassmorphic music player with cloud integration, real audio playback, equalizer, lyrics, and a plugin architecture.</strong><br/>
  Built with Flutter. Implements the Sonic Cloud design system across four screens, plus a v2 service layer for production features.
</p>

<p align="center">
  <a href="https://flutter.dev"><img alt="Flutter" src="https://img.shields.io/badge/Flutter-%E2%89%A53.10-02569B?logo=flutter&logoColor=white" /></a>
  <a href="https://dart.dev"><img alt="Dart" src="https://img.shields.io/badge/Dart-%E2%89%A53.0-0175C2?logo=dart&logoColor=white" /></a>
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Linux%20%7C%20Windows%20%7C%20Web-5A5EA5" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-5A5EA5" />
  <img alt="Status" src="https://img.shields.io/badge/status-active-brightgreen" />
  <img alt="Features" src="https://img.shields.io/badge/features-58%20implemented%20%7C%2042%20scaffolded%20%7C%2048%20planned-blue" />
</p>

---

## Screenshots

<p align="center">
  <img src="screenshots/my_library.png" width="200" alt="My Library" />
  <img src="screenshots/now_playing.png" width="200" alt="Now Playing" />
  <img src="screenshots/cloud_storage.png" width="200" alt="Cloud Storage" />
  <img src="screenshots/settings.png" width="200" alt="Settings" />
</p>

<p align="center"><em>Left to right: My Library · Now Playing · Cloud Storage · Settings</em></p>

> The screenshots above are renderings of the design-system HTML mockups that
> this Flutter app implements 1:1. Each screen reproduces the same glassmorphic
> cards, sonic-seeker progress bar, vinyl-style Now Playing view, and vibrant
> cyan accents.

---

## Features

- 🎨 **Design-system-driven** — every color, typography token, spacing step,
  and radius comes from `sonic_cloud.md`. The HTML analysis found radius
  tokens halved in the original Tailwind config; this port restores them.
- 🟦 **Glassmorphism** — translucent cards with `BackdropFilter` blur and
  light-edge borders, exactly per spec.
- 🌊 **Sonic Seeker** — a 45-bar waveform seek bar with drag-to-seek and a
  glowing playhead thumb.
- 🎵 **Real audio playback** — powered by `just_audio`, with a bundled sample
  WAV so playback works offline. Just press play.
- 📱 **Six platforms** — Android, iOS, macOS, Linux, Windows, and web from a
  single codebase.
- 🧪 **Tested** — widget tests for the core reusable components plus a
  `PlaybackService` unit test.

---

## Project structure

```
sonic_cloud_flutter/
├── lib/
│   ├── main.dart                      ← entry + bottom-nav shell + ambient bg
│   ├── theme/
│   │   ├── app_colors.dart            ← full Material-3 palette from YAML
│   │   ├── app_typography.dart        ← Montserrat (headlines) + Inter (body/labels)
│   │   ├── app_spacing.dart           ← 4px scale + corrected radius tokens
│   │   └── app_theme.dart             ← ThemeData.dark() wired to tokens
│   ├── services/
│   │   └── playback_service.dart      ← just_audio wrapper (ChangeNotifier)
│   ├── models/
│   │   └── models.dart                ← Track, Album, CloudDrive, etc.
│   ├── data/
│   │   └── mock_data.dart             ← in-memory content for all screens
│   ├── widgets/
│   │   ├── glass_card.dart            ← GlassCard + AmbientBackground
│   │   ├── sonic_glow_button.dart     ← pulsing cyan play button
│   │   ├── waveform_progress.dart     ← 45-bar waveform seek bar
│   │   ├── top_app_bar.dart           ← glass top app bar
│   │   ├── bottom_nav_bar.dart        ← glass bottom nav w/ active glow
│   │   ├── album_card.dart            ← carousel card
│   │   └── track_row.dart             ← song list row w/ pulse animation
│   └── screens/
│       ├── my_library_screen.dart     ← Home: search, chips, carousel, song list
│       ├── now_playing_screen.dart    ← Vinyl art + waveform + controls
│       ├── cloud_storage_screen.dart  ← Storage, drives, sync activity
│       └── settings_screen.dart       ← Profile, connections, playback
├── test/
│   ├── app_smoke_test.dart            ← end-to-end smoke test
│   ├── glass_card_test.dart
│   ├── waveform_progress_test.dart
│   ├── sonic_glow_button_test.dart
│   ├── track_row_test.dart
│   └── playback_service_test.dart     ← unit test with mocktail
├── assets/
│   ├── icon/icon.png                  ← source launcher icon (1024×1024)
│   └── audio/sample_track.wav         ← bundled demo audio
├── api/                               ← Vercel serverless backend (Node.js)
│   ├── _lib/{store,http,lrc}.js       ← shared storage + HTTP helpers + LRC parser
│   ├── status.js                      ← GET /api/status — health + endpoint list
│   ├── auth/{signin,me}.js            ← anonymous / email auth, Bearer tokens
│   ├── library/{index,[id]}.js        ← cloud library CRUD
│   ├── playlists/{index,[id]}.js      ← manual / smart / auto playlists CRUD
│   ├── lyrics/index.js                ← LRC parsing + storage
│   ├── sync/{push,pull}.js            ← queue / favorites / ratings / positions / settings
│   └── devices/index.js               ← session list + revoke
├── screenshots/                       ← design-system reference renders
├── android/ ios/ macos/ linux/ windows/ web/   ← platform runners
└── pubspec.yaml
```

---

## Getting started

### Prerequisites

- Flutter ≥ 3.10
- Dart ≥ 3.0

### Install & run

```bash
git clone https://github.com/Exon101/sonic-cloud-flutter.git
cd sonic-cloud-flutter
flutter pub get
flutter run
```

Pick a target with `flutter run -d <device>`. Use `flutter devices` to list
available targets.

### Regenerate launcher icons

```bash
dart run flutter_launcher_icons
```

This regenerates `android/app/src/main/res/mipmap-*/`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, `web/icons/`, `macos/Runner/Assets.xcassets/AppIcon.appiconset/`, and `windows/runner/resources/app_icon.ico` from the source PNG at `assets/icon/icon.png`.

### Run the tests

```bash
flutter test
```

The suite includes:
- `glass_card_test.dart` — child rendering, tap handling, custom radius
- `waveform_progress_test.dart` — boundary progress values, tap-to-seek, drag-to-seek
- `sonic_glow_button_test.dart` — play/pause icon state, tap, custom size
- `track_row_test.dart` — title/artist rendering, cloud badge, active state, taps
- `playback_service_test.dart` — unit tests with a mocked `AudioPlayer` (mocktail)
- `app_smoke_test.dart` — full app smoke test that navigates between all four screens

---

## How the audio is wired

The [PlaybackService](lib/services/playback_service.dart) is a thin
`ChangeNotifier` wrapper around `just_audio`'s `AudioPlayer`:

```
PlaybackService  ←──  widgets listen via AnimatedBuilder(animation: service)
   │
   ├─ load(url)              ─→ AudioPlayer.setUrl(...)
   ├─ play() / pause()       ─→ AudioPlayer.play() / pause()
   ├─ seekToProgress(0..1)   ─→ AudioPlayer.seek(Duration)
   └─ notifies listeners on every position / state change
```

- A single `PlaybackService` instance lives in `_HomeShellState` and is
  injected into `NowPlayingScreen` via the constructor.
- `NowPlayingScreen` rebuilds via `AnimatedBuilder(animation: widget.playback, ...)`
  so the waveform, timestamps, and play/pause icon all stay in sync.
- The bundled sample WAV at `assets/audio/sample_track.wav` is loaded as an
  `asset://` URL — playback works fully offline. To use real audio, replace
  `Track.audioUrl` with a network URL.

---

## Design system fidelity

| Token family   | Status | Notes                                                                 |
| -------------- | ------ | --------------------------------------------------------------------- |
| Colors         | ✅ exact | Every Material-3 surface/primary/secondary/tertiary/error variant     |
| Typography     | ✅ exact | Montserrat 600/700 headlines, Inter 400/500/600 body/labels           |
| Spacing        | ✅ exact | 4px base scale, edge-margin 20px, gutter 16px                         |
| Radius         | ✅ fixed | HTML had every radius halved; Flutter uses spec values (lg=16px, xl=24px) |
| Glassmorphism  | ✅      | `BackdropFilter(blur 20)` + 5% white fill + 1px top/left light edge   |
| Sonic glow     | ✅      | Drop-shadow on active nav icons, pulsing outer glow on play button    |

### Screen-level fixes from the original HTML analysis

1. **Settings desktop view** — HTML had a placeholder; this port uses one responsive layout.
2. **Album art radius** — Correctly 16px (`rounded-lg`), not 8px.
3. **Toggles are accessible** — Each toggle has a visible label and a `GestureDetector`.
4. **No duplicate stylesheets** — Single source of truth in `app_theme.dart`.
5. **Bottom nav doesn't appear on Now Playing** — Pushed as a full-screen route.

---

## v2 Architecture — production features

Beyond the original four-screen design-system port, v2 adds a full service
layer that supports the feature set of a production music player. The full
matrix of what's implemented, scaffolded (interface only), and planned lives in
[FEATURES.md](FEATURES.md) — quick summary:

### Implemented (working code)

- **Audio engine**: gapless playback via `ConcatenatingAudioSource`, repeat
  modes (off/all/one), shuffle, playback speed 0.5×–3×, pitch ±12 semitones,
  per-track ReplayGain normalization, sleep timer (pause/stop/fade-out)
- **Equalizer**: 10-band ISO-frequency EQ (31 Hz–16 kHz, -12..+12 dB) with
  native Android EQ via `AndroidEqualizer`, 9 built-in presets (Flat, Bass
  Boost, Rock, Pop, Jazz, etc.), bass boost / virtualizer / surround /
  loudness / compressor / limiter toggles
- **Library**: scan local folders recursively, multi-tier indices
  (artists / albums / genres / years / composers / folders), duplicate
  detection, broken-file detection, favorites, ratings, play counts,
  recently played, most played
- **Lyrics**: parse embedded lyrics + sidecar `.lrc` files, multi-timestamp
  lines, millisecond precision, synced scrolling with active-line highlight,
  karaoke mode, tap-to-seek
- **Playlists**: manual + smart + auto playlists, rule engine
  (most/least/never played, recent, genre, artist, mood, year, rating)
- **Search**: instant in-memory search across artist / album / song /
  genre / lyrics
- **Themes**: dark / light / AMOLED / dynamic / system, custom accent colors
  via `ColorScheme.fromSeed`
- **Plugin system**: extension points for lyrics providers, cloud providers,
  audio effects, visualizers, metadata sources, themes, and scripts

### Scaffolded (interface only — drop in real impl)

- 10 cloud providers (Google Drive, Dropbox, OneDrive, Nextcloud, WebDAV,
  SMB, FTP, SFTP, NAS, local network) — `CloudProvider` abstract class
- Cross-device sync (playlists, queue, favorites, ratings, resume position,
  settings) — `SyncService` abstract class with `LocalSyncService` default
- `audio_service` integration for lock-screen / notification / Bluetooth
  controls (package is in pubspec; MediaController not wired)
- Tag editing via `audiotags`

### Planned (not yet started)

- Android Auto / CarPlay / DLNA / UPnP
- Audio visualizer widgets
- FTS5 index for >100k song libraries
- Desktop: system tray, media keys, MPRIS, drag-and-drop
- AI: mood detection, similar songs, smart playlist generation
- Sharing: playlist QR codes, M3U/XSPF import/export

See [FEATURES.md](FEATURES.md) for the complete 148-row matrix.

### v2 Service architecture

```
lib/
├── models/models.dart              ← 20+ domain classes (Track, Album, Playlist, Lyrics, EQ, Cloud…)
├── services/
│   ├── playback_service.dart       ← v2: queue, repeat, shuffle, speed, pitch, sleep timer, crossfade, ReplayGain
│   ├── equalizer_service.dart      ← 10-band EQ + bass boost / virtualizer / etc.
│   ├── library_service.dart        ← scan, indices, duplicates, broken files, favorites, ratings
│   ├── lyrics_service.dart         ← LRC parser, synced active-line index, karaoke
│   ├── playlist_service.dart       ← manual + smart + auto playlists with rule engine
│   ├── search_service.dart         ← instant in-memory search
│   ├── sync_service.dart           ← cross-device sync abstraction + LocalSyncService
│   ├── app_settings_service.dart   ← SharedPreferences-backed settings
│   └── theme_service.dart          ← 5 theme modes + custom accent
├── providers/cloud_providers.dart  ← CloudProvider abstract + 10 stub implementations
├── plugins/plugin_registry.dart    ← 7 plugin extension points
└── screens/
    ├── equalizer/equalizer_screen.dart
    ├── lyrics/lyrics_screen.dart
    └── lyrics/sleep_timer_sheet.dart
```

---

## Deployment

Sonic Cloud ships with deployment configs for **every** target platform. The
full guide lives in [DEPLOYMENT.md](DEPLOYMENT.md); here's the quick reference:

### Web — pick your host

| Tier | Host | Config file | One-liner |
|---|---|---|---|
| **Production** (large-scale) | **Firebase Hosting** | `firebase.json`, `.firebaserc` | `./scripts/deploy_web.sh firebase` |
| **Dev / small-scale** | **Vercel** *(also hosts the `/api` serverless backend)* | `vercel.json`, `api/` | `./scripts/deploy_web.sh vercel` |
| **Self-hosted** (own server) | Docker (nginx) | `Dockerfile`, `docker-compose.yml` | `./scripts/deploy_web.sh docker` → http://localhost:8080 |
| **Alt static host** | Netlify *(web bundle only — no `/api`)* | `netlify.toml` | `./scripts/deploy_web.sh netlify` |
| **Local preview** | — | — | `./scripts/deploy_web.sh preview` |

**Dev demo (Vercel):** https://sonic-cloud-kappa.vercel.app/  •  **API:** https://sonic-cloud-kappa.vercel.app/api/status

### Mobile

```bash
./scripts/deploy_android.sh install     # debug APK → connected device
./scripts/deploy_android.sh firebase    # release APK → Firebase App Distribution
./scripts/deploy_android.sh playstore   # release AAB → Google Play (production)

./scripts/deploy_ios.sh install         # debug build → connected iPhone
./scripts/deploy_ios.sh testflight      # release IPA → TestFlight (via fastlane)
./scripts/deploy_ios.sh appstore        # release IPA → App Store (via fastlane)
```

### Desktop

```bash
./scripts/build.sh macos      # → build/macos/Build/Products/Release/Sonic Cloud.app
./scripts/build.sh windows    # → build/windows/x64/runner/Release/sonic_cloud.exe
./scripts/build.sh linux      # → build/linux/x64/release/bundle/sonic_cloud
```

### CI/CD

| Platform | Config | Trigger |
|---|---|---|
| **GitHub Actions** (CI) | `.github/workflows/ci.yml` | every push / PR — analyze + test + build web & APK |
| **GitHub Actions** (Release) | `.github/workflows/release.yml` | tag `v*.*.*` — builds all 6 platforms + creates GitHub Release |
| **Codemagic** | `codemagic.yaml` | tag / push to main — Firebase App Distribution + Play Store + TestFlight + Firebase Hosting (prod) + Vercel (dev) |
| **Fastlane** | `fastlane/Fastfile.android`, `fastlane/Fastfile.ios` | invoked by scripts or CI |
| **Dependabot** | `.github/dependabot.yml` | weekly — Flutter packages, GitHub Actions, Docker, Ruby gems |

To cut a release:

```bash
git tag v1.0.0
git push origin v1.0.0
# → GitHub Actions builds all platforms and creates a Release with artifacts
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for environment-variable setup, signing-key
preparation, and per-platform details.

---

## Built with

- [Flutter](https://flutter.dev) — UI toolkit
- [google_fonts](https://pub.dev/packages/google_fonts) — Montserrat + Inter
- [just_audio](https://pub.dev/packages/just_audio) — audio playback
- [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) — icon generation
- [mocktail](https://pub.dev/packages/mocktail) — test mocks
- [Fastlane](https://fastlane.tools) — mobile release automation
- [Codemagic](https://codemagic.io) — cloud CI/CD
- [Docker](https://www.docker.com) — containerized web deploy

---

## License

MIT — feel free to fork and adapt.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide. Quick reference:

```bash
git clone https://github.com/Exon101/sonic-cloud-flutter.git
cd sonic-cloud-flutter
flutter pub get
dart format .
flutter analyze --no-fatal-infos
flutter test
```

Before opening a PR:
1. Branch from `main` (`feat/…`, `fix/…`, `chore/…`, `docs/…`)
2. Run `dart format .`, `flutter analyze`, `flutter test` — all must pass
3. Use [conventional commit messages](https://www.conventionalcommits.org/)
4. Fill in the [PR template](.github/pull_request_template.md)
5. Link any closed issues (`Closes #123`)

CI runs on every push and PR — `Analyze & Test`, `Build Web`, `Build Android APK`.
The `main` branch is protected: see [`.github/BRANCH_PROTECTION.md`](.github/BRANCH_PROTECTION.md).

## Security

Found a vulnerability? **Do not open a public issue.** See
[`.github/SECURITY.md`](.github/SECURITY.md) for the disclosure process.

Sonic Cloud ships with several security features built in:
- App PIN (salted hash in OS keychain via `flutter_secure_storage`)
- Biometric unlock (`local_auth`)
- Secure cloud credential storage per provider
- Granular per-provider permissions (read / write / delete / stream / offline)
- Optional offline-only mode (no network calls)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for versioned release notes.
