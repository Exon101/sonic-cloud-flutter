# Changelog

All notable changes to Sonic Cloud are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.0] — 2025-07-05

### Major release — all features wired, local file playback, real cloud providers

### Added
- **Local file playback**: "Add Music" FAB on MyLibraryScreen with file picker (pick audio files) + folder scanner (scan a directory recursively). Picked/scanned tracks are persisted to SQLite.
- **Real cloud providers**: Google Drive (google_sign_in + REST API), Dropbox (OAuth2 + API v2), OneDrive (Microsoft Graph API), Nextcloud (WebDAV), SMB (smbclient CLI), WebDAV (webdav_client) — 6 real implementations, 4 stubs remaining
- **OAuth flows**: OAuthService with google_sign_in for Google Drive, flutter_web_auth_2 for Dropbox + OneDrive authorization code flows
- **audiotags Rust backend**: MetadataService now reads/writes real ID3/Vorbis/MP4/FLAC tags via AudioTags.read()/write()
- **Rotating vinyl**: album art in NowPlayingScreen rotates at 33⅓ RPM when playing, pauses when paused, with vinyl groove rings
- **Mini-player**: persistent bottom bar with album thumbnail, title, artist, progress bar, play/pause + next buttons
- **Lyrics + sleep timer**: NowPlayingScreen top bar has lyrics button (opens synced lyrics screen) + sleep timer button (opens timer sheet)
- **Smart shuffle**: preserves original queue order, restores on toggle off
- **LRC sidecar files**: reads/writes .lrc files next to audio files
- **All screens wired to real services**: MyLibraryScreen (LibraryService + SearchService), SettingsScreen (AppSettingsService + SecurityService + AccessibilityService + LocalApiService), NowPlayingScreen (PlaybackService + LyricsService)
- **Theme system**: 5 modes (system/dark/light/AMOLED/dynamic) + 6 accent colors
- **Security**: PIN, biometric unlock, secure credential storage, granular per-provider permissions
- **Accessibility**: high-contrast, font scale slider, colorblind modes, reduced motion, large touch targets
- **Local REST API + WebSocket**: shelf-based API on port 8765 for companion apps
- **Custom logo**: user-provided 1024×1024 PNG as app icon everywhere

### Fixed
- CI: bumped Gradle 8.9 → 8.11.1, AGP 8.7.0 → 8.9.1, compileSdk 35 → 36
- CI: removed hand-written CMakeLists.txt (incompatible with Flutter build system)
- CI: added --force flag to flutter create in release workflow
- CI: publish-release uses if: always() so release is created with available artifacts
- CI: fixed all analyzer errors (RepeatMode ambiguity, const method invocations, missing imports)
- CI: fixed auto-merge workflow (missing checkout step)
- Closed bogus Dependabot PRs targeting non-existent action versions
- Updated all GitHub Actions to valid latest versions

## [3.1.0] — 2025-07-04

### Added
- WebDAV provider: real implementation using webdav_client 1.2.x API
- Smart shuffle: preserves original queue order via _shuffledOrder copy
- LRC sidecar files: reads/writes .lrc files via dart:io
- Metadata editing: MetadataService with read/write/batchEdit
- Audio metadata reading: LibraryService calls MetadataService first

### Fixed
- Auto-merge workflow: added missing checkout step
- All 3 CI jobs pass (Analyze & Test, Build Web, Build Android APK)

### Fixed
- CI now passes — corrected all pubspec package versions to ones that exist
  on pub.dev (webdav_client 1.2.2, audiotags 1.4.5, etc.)
- Replaced Drift with sqflite to eliminate the build_runner codegen step
- Fixed invalid mid-file imports in `plugin_registry.dart` and
  `real_webdav_provider.dart`
- Fixed conflicting `WebSocketChannel` definitions in `local_api_service.dart`
- `EqualizerService.init()` no longer crashes when no AudioPlayer is wired
- Closed 4 bogus Dependabot PRs that targeted non-existent GitHub Actions
  versions

### Added
- `CODEOWNERS` — automatic review requests per path
- `CONTRIBUTING.md` — dev environment + workflow + conventions
- `.github/SECURITY.md` — vulnerability disclosure policy
- `.github/BRANCH_PROTECTION.md` — recommended `main` branch rules + `gh` script
- `.github/workflows/stale.yml` — auto-close stale issues (60d) and PRs (30d)
- CHANGELOG.md (this file)
- `.github/dependabot.yml` re-tuned to use MAJOR version pinning

## [3.0.0] — 2024-12 (v3 release)

### Added
- `audio_service` MediaController wired into PlaybackService (lock-screen,
  notification, Bluetooth headset controls)
- Real WebDAV provider using `webdav_client` (list/stream/download/upload/delete)
- `LibraryBrowseScreen` with 7 tabs (Sources/Artists/Albums/Genres/Years/
  Composers/Folders)
- Equalizer screen wired into MyLibrary top app bar
- SQLite persistence via Drift (later replaced with sqflite in 3.1.0)
- `UniversalLibraryService` combining local + all cloud providers
- `AudioFingerprinter` for cross-format duplicate detection
- `GestureControls` widget on Now Playing (tap/swipe/long-press)
- `SecurityService` (PIN + biometric + secure cloud credential storage +
  granular per-provider permissions)
- `AccessibilityService` (high-contrast, font scale, colorblind modes,
  reduced motion, large touch targets)
- `LocalApiService` (shelf REST API + WebSocket on port 8765)
- 5 new test files (~25 cases)

## [2.0.0] — 2024-12 (v2 release)

### Added
- Expanded domain models (Artist, Album, Genre, Composer, YearBucket, Folder,
  Playlist, SmartPlaylistRule, Lyrics, EqualizerBand, CloudProviderConfig,
  SyncState, UserAccount, DeviceInfo, SessionInfo, RepeatMode, SleepTimer)
- `PlaybackService` v2 with gapless playback, queue mgmt, repeat modes,
  shuffle, speed 0.5-3x, pitch ±12, sleep timer, crossfade, ReplayGain
- `EqualizerService` (10-band ISO EQ, 9 built-in presets, bass boost /
  virtualizer / surround / loudness / compressor / limiter)
- `LibraryService` (scan, multi-tier indices, duplicates, broken files,
  favorites, ratings, play counts)
- `LyricsService` (LRC parser, synced active-line index, karaoke mode)
- `PlaylistService` (manual + smart + auto playlists with rule engine)
- `SearchService` (instant in-memory search)
- `SyncService` abstraction + `LocalSyncService` default
- `AppSettingsService` (SharedPreferences-backed)
- `ThemeService` (5 theme modes + custom accent)
- 10 cloud provider stubs (Google Drive, Dropbox, OneDrive, Nextcloud,
  WebDAV, SMB, FTP, SFTP, NAS, LocalNetwork)
- `PluginRegistry` with 7 extension points
- 4 new test files (~30 cases)
- `FEATURES.md` 148-row feature matrix

## [1.0.0] — 2024-12 (initial release)

### Added
- 4-screen Flutter implementation of the Sonic Cloud design system
  (My Library, Now Playing, Cloud Storage, Settings)
- Glassmorphism via `BackdropFilter`
- Animated sonic glow on play button + active nav items
- 45-bar waveform seek bar with drag-to-seek
- Vinyl-style Now Playing with pulsing outer ring
- `just_audio` playback with bundled sample WAV
- `flutter_launcher_icons` config + 1024×1024 source icon
- Platform runners for Android, iOS, macOS, Linux, Windows, web
- CI/CD via GitHub Actions + Codemagic
- Fastlane config for Android + iOS releases
- Docker + docker-compose for containerized web deploy
- Vercel, Netlify, Firebase Hosting configs
- 6 helper shell scripts (`build.sh`, `deploy_*.sh`)
- README with badges, screenshots, deployment docs

[Unreleased]: https://github.com/Exon101/sonic-cloud-flutter/compare/v4.0.0...HEAD
[4.0.0]: https://github.com/Exon101/sonic-cloud-flutter/releases/tag/v4.0.0
[3.0.0]: https://github.com/Exon101/sonic-cloud-flutter/releases/tag/v3.0.0
[2.0.0]: https://github.com/Exon101/sonic-cloud-flutter/releases/tag/v2.0.0
[1.0.0]: https://github.com/Exon101/sonic-cloud-flutter/releases/tag/v1.0.0
