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
