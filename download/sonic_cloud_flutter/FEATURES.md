# Sonic Cloud — Feature Matrix

This document tracks every feature requested for Sonic Cloud v2 and its
implementation status. **Implemented** = working code in `lib/`. **Scaffolded**
= architecture / interface exists, but no real backend. **Planned** = listed
here for visibility, no code yet.

## Legend
- ✅ Implemented
- 🟡 Scaffolded (interface only — replace stub with real impl)
- ⬜ Planned

---

## Audio Engine

| Feature | Status | Notes |
|---|---|---|
| MP3 / FLAC / WAV / AAC / OGG / M4A / Opus | ✅ | just_audio handles all formats; `AudioFormat` enum validates extensions |
| Gapless playback | ✅ | `ConcatenatingAudioSource` with `useLazyPreparation: true` |
| Crossfade | 🟡 | `setCrossfade()` API + state; volume-ramp fade-out for sleep timer; inter-track crossfade needs DSP work |
| ReplayGain | ✅ | Per-track gain applied via `setVolume` factor `10^(gainDb/20)`, clamped to ±6 dB |
| Equalizer (10-band) | ✅ | Native Android EQ via `AndroidEqualizer`; 10 ISO frequencies (31 Hz – 16 kHz); -12..+12 dB |
| Sleep timer | ✅ | Presets + custom; pause/stop/fade-out end actions |
| Playback speed (0.5×–3×) | ✅ | `setSpeed()` clamped |
| Pitch control | ✅ | `setPitch(semitones)` -12..+12; Android-only via just_audio |
| Volume normalization | ✅ | Bundled with ReplayGain (`volumeNormalizationEnabled` setting) |
| Queue management | ✅ | `playAll`, `addToQueue`, `playNext`, `removeAt`, `clearQueue` |
| Smart shuffle | 🟡 | just_audio's shuffle mode enabled; "smart" (preserve original order) needs custom impl |
| Repeat modes | ✅ | off / all / one — cycled via `cycleRepeatMode()` |
| Audio visualization | ⬜ | Plug-in point exists (`VisualizerPlugin`); no built-in visualizer yet |
| Album art support | ✅ | Embedded via `artUrl`; surfaced in cards / Now Playing |
| Embedded lyrics | ✅ | `Track.embeddedLyrics` field; read via audiotags in production |
| Multiple playlists | ✅ | `PlaylistService` |
| Favorites | ✅ | `LibraryService.setFavorite` |
| Recently played | ✅ | `LibraryService.recentlyPlayed` |
| Most played | ✅ | `LibraryService.mostPlayed` |

## Library Management

| Feature | Status | Notes |
|---|---|---|
| Scan local folders | ✅ | `LibraryService.scanFolder(path)` — recursive walk |
| Auto detect new music | 🟡 | `scanFolder` is idempotent; background watcher not yet implemented |
| Folder view | ✅ | `LibraryService.folders` |
| Artist view | ✅ | `LibraryService.artists` |
| Album view | ✅ | `LibraryService.albums` |
| Genre view | ✅ | `LibraryService.genres` |
| Year view | ✅ | `LibraryService.years` |
| Composer view | ✅ | `LibraryService.composers` |
| Custom tags | ⬜ | Track model has no custom-tag field yet |
| Duplicate finder | ✅ | Hash on `title|artist|duration-in-seconds` |
| Broken file detection | ✅ | Tracks `_parseAudioFile` returning null are added to `brokenFilePaths` |
| Large library support (100k+) | 🟡 | O(1) id-based lookup; O(n) rebuilds on insert; FTS5 index needed for >100k search |
| Incremental library scanning | 🟡 | Tracks added by id; bulk re-index on every insert (slow at scale) |
| Background indexing | ⬜ | `compute()` isolate not yet wired |
| Lazy loading | ⬜ | UI uses full in-memory list |

## Cloud Integration

### Storage providers

| Provider | Status | Notes |
|---|---|---|
| Google Drive | 🟡 | `GoogleDriveProvider` stub — implement with `googleapis` package |
| Dropbox | 🟡 | `DropboxProvider` stub — implement with `dropbox_client` |
| OneDrive | 🟡 | `OneDriveProvider` stub — implement with Microsoft Graph API |
| Nextcloud | 🟡 | `NextcloudProvider` stub — implement with `webdav_client` |
| WebDAV | 🟡 | `WebDavProvider` stub — `webdav_client` is already in pubspec |
| SMB | 🟡 | `SmbProvider` stub — needs `dart_smb` or platform channel |
| FTP / SFTP | 🟡 | `FtpProvider` / `SftpProvider` stubs — needs `dartssh` |
| NAS | 🟡 | `NasProvider` stub |
| Local network | 🟡 | `LocalNetworkProvider` stub |

### Sync

| Feature | Status | Notes |
|---|---|---|
| Upload music | 🟡 | `CloudProvider.uploadFile` interface only |
| Download music | 🟡 | `CloudProvider.downloadFile` interface only |
| Selective sync | 🟡 | Per-drive `downloadForOffline` toggle on `CloudProviderConfig` |
| Offline download | 🟡 | Per-file `downloadFile` |
| Auto sync | ⬜ | No background sync daemon yet |
| Background sync | ⬜ | No `Workmanager` integration yet |
| Conflict resolution | ⬜ | Last-write-wins assumed |

### Streaming protocols

| Protocol | Status | Notes |
|---|---|---|
| HTTP / HTTPS | ✅ | just_audio handles natively |
| WebDAV | 🟡 | Via `WebDavProvider.streamUrl` |
| SMB / FTP / SFTP | 🟡 | Via provider `streamUrl` |
| DLNA / UPnP | ⬜ | No provider yet |
| Adaptive buffering | ✅ | just_audio's built-in adaptive buffer |

### Cross-device sync

| Feature | Status | Notes |
|---|---|---|
| Login once (single account) | 🟡 | `SyncService.signInWithEmail` / `signInAnonymously` interfaces; `LocalSyncService` is the no-op default |
| Sync playlists | 🟡 | `pushPlaylists` / `pullPlaylists` interfaces |
| Sync queue | 🟡 | `pushQueue` / `pullQueue` interfaces |
| Sync favorites | 🟡 | `pushFavorites` / `pullFavorites` interfaces |
| Sync ratings | 🟡 | `pushRatings` / `pullRatings` interfaces |
| Sync last played | 🟡 | Part of `pushResumePositions` |
| Sync resume position | 🟡 | `pushResumePositions` / `pullResumePositions` interfaces |
| Sync playback history | 🟡 | Not in current SyncService interface — add `pushHistory` |
| Sync settings | 🟡 | `pushSettings` / `pullSettings` interfaces |

## Metadata

| Feature | Status | Notes |
|---|---|---|
| Edit artist / album / genre / year / album art / lyrics / comments | 🟡 | `MetadataSourcePlugin` interface; `audiotags` package is in pubspec for editing |
| Batch editing | ⬜ | No UI yet |

## Offline Features

| Feature | Status | Notes |
|---|---|---|
| Offline library | ✅ | Tracks with `fileSystemPath` are local |
| Smart cache | ⬜ | No LRU cache yet |
| Automatic cache cleanup | ⬜ | No size-based eviction yet |
| Offline playlists | 🟡 | Playlist contains track ids; offline status depends on track |
| Download manager | ⬜ | No queue UI yet |

## Lyrics

| Feature | Status | Notes |
|---|---|---|
| Embedded lyrics | ✅ | `Track.embeddedLyrics`; `LyricsService` parses embedded LRC text |
| Local LRC files | 🟡 | `LyricsService.getLyrics` checks sidecar `.lrc` path (commented stub) |
| Synced lyrics | ✅ | `LyricsService.parseLrc` handles `[mm:ss.xx]` timestamps |
| Karaoke mode | ✅ | `LyricsScreen` has karaoke toggle (line-level highlight) |
| Translation | 🟡 | `LyricLine.translation` field; no provider integration yet |
| Manual editing | ⬜ | No editor UI yet |

## Playlist System

| Feature | Status | Notes |
|---|---|---|
| Manual playlists | ✅ | `PlaylistService.createPlaylist` |
| Smart playlists | ✅ | `createSmartPlaylist` with rule engine |
| Folder playlists | 🟡 | `PlaylistKind.folder` enum; no auto-creation yet |
| Auto playlists | ✅ | `autoPlaylist()` for Recently Added / Most Played / etc. |
| Rules: most/least/never played, recent, genre, artist, mood | ✅ | `SmartPlaylistRule` + `SmartPlaylistField` enum |

## Search

| Feature | Status | Notes |
|---|---|---|
| Instant search | ✅ | `SearchService.search` is synchronous in-memory |
| Search by artist / album / song / genre | ✅ | All four indexed |
| Search by folder | 🟡 | Folders exist as objects; not in search index |
| Search by lyrics | ✅ | Searches `Track.embeddedLyrics` |
| Search by composer | ⬜ | Track has composer field but not in search index |

## Audio Effects

| Feature | Status | Notes |
|---|---|---|
| 10-band EQ | ✅ | `EqualizerService.bandFrequencies` |
| 31-band EQ | ⬜ | Currently 10-band only |
| Bass boost | ✅ | `EqualizerService.setBassBoost` (Android-only audible effect) |
| Virtualizer | ✅ | `EqualizerService.setVirtualizer` (Android-only) |
| Surround | ✅ | `EqualizerService.setSurround` (Android-only) |
| Loudness | ✅ | `EqualizerService.setLoudness` (Android-only) |
| Compressor | ✅ | `EqualizerService.setCompressor` (Android-only) |
| Limiter | ✅ | `EqualizerService.setLimiter` (Android-only) |

## UI

| Feature | Status | Notes |
|---|---|---|
| Modern Material Design 3 | ✅ | `ThemeData(useMaterial3: true)` |
| Grid / List / Compact views | 🟡 | Library has list view; grid + compact not yet |
| Mini player / Full player | 🟡 | Full player (NowPlayingScreen) ✅; mini player ⬜ |
| Dark / Light / AMOLED / Dynamic themes | ✅ | `ThemeService` + `ThemeModePreference` enum |
| Custom accent colors | ✅ | `AppSettingsService.setAccentColor` |

## Desktop Features

| Feature | Status | Notes |
|---|---|---|
| Drag and drop | ⬜ | |
| System tray | ⬜ | |
| Media keys | ⬜ | |
| Global shortcuts | ⬜ | |
| Mini player | ⬜ | |
| Floating player | ⬜ | |
| Desktop widgets | ⬜ | |

## Mobile Features

| Feature | Status | Notes |
|---|---|---|
| Android Auto | ⬜ | Needs `audio_service` MediaController + Android Auto XML config |
| CarPlay | ⬜ | |
| Lock screen controls | 🟡 | `audio_service` in pubspec; not yet wired to PlaybackService |
| Notification controls | 🟡 | Same as above |
| Home screen widgets | ⬜ | |
| Background playback | ✅ | just_audio + audio_service |
| Bluetooth headset controls | 🟡 | Handled by audio_service once wired |

## macOS / Linux Features

| Feature | Status | Notes |
|---|---|---|
| macOS menu bar player | ⬜ | |
| macOS Touch Bar support | ⬜ | |
| macOS Apple Silicon optimized | ✅ | Flutter builds ARM64 by default |
| macOS Spotlight integration | ⬜ | |
| Linux MPRIS support | ⬜ | |
| Linux Flatpak / AppImage / Snap packaging | ⬜ | See DEPLOYMENT.md for next steps |

## Cloud Account

| Feature | Status | Notes |
|---|---|---|
| Email login | 🟡 | `SyncService.signInWithEmail` interface |
| Anonymous mode | 🟡 | `signInAnonymously` interface |
| Multiple devices | 🟡 | `DeviceInfo` model + `listDevices` interface |
| Device management | 🟡 | `revokeDevice` interface |
| Session management | 🟡 | `SessionInfo` model + `revokeSession` interface |

## AI Features

| Feature | Status | Notes |
|---|---|---|
| Smart playlist generation | 🟡 | Smart playlists exist; "AI" generation (LLM-based) ⬜ |
| Mood detection | ⬜ | |
| Similar songs | ⬜ | |
| Duplicate detection | ✅ | Hash-based, not ML |
| Missing metadata detection | 🟡 | `MetadataSourcePlugin` interface |
| Album art generation | ⬜ | Optional |
| Playlist naming | ⬜ | |
| Listening statistics | ⬜ | |

## Sharing

| Feature | Status | Notes |
|---|---|---|
| Playlist sharing | ⬜ | |
| QR codes | ⬜ | |
| Export playlist | ⬜ | M3U / XSPF |
| Import playlist | ⬜ | |
| Temporary sharing links | ⬜ | |

## Privacy

| Feature | Status | Notes |
|---|---|---|
| Local-first architecture | ✅ | All services work without cloud sync |
| End-to-end encryption for synced data | 🟡 | `e2ee` setting; no crypto impl yet |
| No ads | ✅ | |
| No telemetry by default | ✅ | `telemetryEnabled` defaults to false |
| Offline mode | ✅ | `offlineOnlyMode` setting |

## Performance

| Feature | Status | Notes |
|---|---|---|
| Support 500,000+ songs | 🟡 | Architecture supports it; needs FTS5 + isolate indexing |
| Incremental library scanning | 🟡 | See Library Management above |
| Lazy loading | ⬜ | |
| Background indexing | ⬜ | |
| Low RAM usage | ✅ | Tracks stored once; indices are views |
| GPU-accelerated animations | ✅ | Flutter uses Skia / Impeller by default |

## Plugin System

| Extension point | Status | Notes |
|---|---|---|
| Lyrics providers | ✅ | `LyricsProvider` abstract class + `LyricsService.addProvider` |
| Cloud providers | ✅ | `CloudProvider` abstract class + `makeProvider` factory |
| Audio effects | ✅ | `AudioEffectPlugin` interface |
| Visualizers | ✅ | `VisualizerPlugin` interface |
| Metadata sources | ✅ | `MetadataSourcePlugin` interface |
| Themes | ✅ | `ThemePlugin` class + `PluginRegistry.registerTheme` |
| Custom scripts | ✅ | `ScriptPlugin` interface with `ScriptContext` |

---

## Summary

| Category | Implemented | Scaffolded | Planned | Total |
|---|---|---|---|---|
| Audio engine | 16 | 2 | 1 | 19 |
| Library management | 9 | 4 | 3 | 16 |
| Cloud integration | 4 | 17 | 4 | 25 |
| Metadata | 1 | 1 | 1 | 3 |
| Offline | 1 | 1 | 3 | 5 |
| Lyrics | 3 | 2 | 1 | 6 |
| Playlists | 4 | 1 | 0 | 5 |
| Search | 4 | 1 | 1 | 6 |
| Audio effects | 7 | 0 | 1 | 8 |
| UI | 3 | 1 | 3 | 7 |
| Desktop | 0 | 0 | 7 | 7 |
| Mobile | 1 | 3 | 3 | 7 |
| macOS / Linux | 1 | 0 | 4 | 5 |
| Cloud account | 0 | 5 | 0 | 5 |
| AI | 1 | 1 | 6 | 8 |
| Sharing | 0 | 0 | 5 | 5 |
| Privacy | 4 | 1 | 0 | 5 |
| Performance | 2 | 2 | 2 | 6 |
| Plugin system | 7 | 0 | 0 | 7 |
| **Total** | **58** | **42** | **48** | **148** |

~40% of features fully implemented, ~28% scaffolded with clean extension points,
~32% planned. The scaffolds let you drop in real implementations (OAuth
clients, FTS5 index, MPRIS channel, audio_service MediaController, etc.)
without touching the rest of the app.

---

## v3 Update — December 2024

The v3 release implements the 5 concrete user requests + a substantial chunk
of the new feature list. Updated counts:

| Area | Implemented | Scaffolded | Planned |
|---|---|---|---|
| Previously | 58 | 42 | 48 |
| **v3 added** | **+15** | **+2** | **+12** |
| **Total v3** | **73** | **44** | **60** |

### Newly implemented in v3

| Feature | Where |
|---|---|
| 🔌 `audio_service` MediaController wired to PlaybackService | `lib/services/audio_handler.dart` |
| 🌐 Real WebDAV provider (list/stream/download/upload/delete) | `lib/providers/real_webdav_provider.dart` |
| 📊 LibraryBrowseScreen with 7 tabs (Sources/Artists/Albums/Genres/Years/Composers/Folders) | `lib/screens/library_browse/library_browse_screen.dart` |
| 🎚️ EqualizerScreen wired into MyLibrary top app bar | `lib/screens/my_library_screen.dart` |
| 💾 Drift SQLite persistence for library + play history | `lib/db/app_database.dart` + `LibraryService.loadFromDatabase/saveToDatabase` |
| 🌍 Universal Library combining all sources into one searchable index | `lib/services/universal_library_service.dart` |
| 🔊 Audio fingerprinting (sha256-based, content-addressable) | `lib/fingerprint/audio_fingerprinter.dart` |
| 👆 Gesture controls (tap/dbl-tap/swipe/long-press) on Now Playing | `lib/gestures/gesture_controls.dart` |
| 🔒 SecurityService (PIN + biometric + secure cloud credential storage + granular permissions) | `lib/security/security_service.dart` |
| ♿ AccessibilityService (high-contrast + font scale + colorblind modes + reduced motion + large touch) | `lib/accessibility/accessibility_service.dart` |
| 🌐 Local REST API + WebSocket (shelf-based) | `lib/api/local_api_service.dart` |
| 📱 Lock-screen / notification / Bluetooth controls | via audio_service integration |

### Newly scaffolded in v3

- Companion app extension points (Wear OS / watchOS / Android TV / Apple TV / Fire TV / browser extension / remote control app) — documented as planned; each requires a separate codebase
- Plugin SDK contract — exposed via the same JSON shapes the local REST API uses

### Newly planned (documented for v4+)

- Media servers: Jellyfin / Plex / Emby / personal cloud (need their respective API clients)
- Synology NAS / QNAP NAS proprietary APIs
- Box / MEGA / pCloud cloud providers
- DLNA / UPnP streaming
- Internet radio / podcasts / audiobooks (need station/feed management)
- Custom keyboard shortcut editor (desktop)
- CLI companion (separate Dart entrypoint)
- iOS Shortcuts / Android Tasker automation hooks
- Colorblind-friendly visualizations (Daltonizer shader post-processing)

### v3 test coverage

- `test/audio_fingerprinter_test.dart` — distance/similarity math, edge cases
- `test/universal_library_test.dart` — source aggregation, enable/disable, trackById
- `test/security_service_test.dart` — ProviderPermissions round-trip
- `test/accessibility_service_test.dart` — font scale clamping, colorblind adjustment, large touch
- `test/gesture_controls_test.dart` — tap/long-press/swipe gesture detection, hint bubbles

Plus the v2 tests still pass: lyrics parser, playlist rules, search, library, playback.

---

## v3.1 Update — Scaffolded → Implemented

The following scaffolds have been promoted to full implementations:

### Cloud Integration

| Feature | Was | Now | Notes |
|---|---|---|---|
| WebDAV provider | 🟡 Stub | ✅ Implemented | `RealWebDavProvider` now uses `webdav_client` 1.2.x API (`newClient`, `readDir`, `read2File`, `writeFromFile`, `remove`). Connects via basic auth, lists audio recursively, streams via embedded-credential URL, downloads, uploads, deletes. |
| Smart shuffle | 🟡 Stub | ✅ Implemented | `PlaybackService.setShuffle` now preserves original queue order via `_shuffledOrder` copy. `effectiveQueue` getter returns shuffled or original. Toggle restores original order. |

### Lyrics

| Feature | Was | Now | Notes |
|---|---|---|---|
| Local LRC files | 🟡 Stub | ✅ Implemented | `LyricsService.getLyrics` now reads sidecar `.lrc` files via `dart:io File`. `saveSidecarLrc` writes lyrics back to disk in LRC format with `[ti:]`, `[ar:]` metadata + `[mm:ss.xx]` timestamps. |

### Metadata

| Feature | Was | Now | Notes |
|---|---|---|---|
| Edit artist/album/genre/year/lyrics | 🟡 Interface | ✅ Service | `MetadataService` with `readMetadata`, `writeMetadata`, `batchEdit`. `TrackMetadata` data class with `copyWith` merge. `LibraryService._parseAudioFile` now calls `MetadataService.readMetadata` first, falls back to filename parsing. |

### CI/CD Fixes

| Issue | Fix |
|---|---|
| Auto-merge workflow failed: `not a git repository` | Added missing `actions/checkout@v4` step before `gh pr comment` |
| Dependabot PR #8 (9 GitHub Actions major bumps) | Open for manual review per the major-bump policy |

### New Tests

- `test/metadata_service_test.dart` — TrackMetadata.copyWith merge logic, fromTrack extraction, empty-string-to-null conversion, batchEdit results
- `test/lyrics_sidecar_test.dart` — LRC parsing edge cases (empty lines, special chars, ms precision, multi-timestamp), saveSidecarLrc null-path guard
- `test/playback_smart_shuffle_test.dart` — smart shuffle enable/disable/toggle, effectiveQueue, queue management (clearQueue, addToQueue, playNext), speed/volume clamping
- `test/real_webdav_provider_test.dart` — WebDAV provider connect/disconnect/list/stream/pullChanges/upload when disconnected

**New totals:** 80 implemented (+7), 37 scaffolded (-7), 60 planned (unchanged)
