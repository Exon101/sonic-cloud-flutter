# Sonic Cloud — Agent Session Memory

> **INTERNAL — NOT FOR PUBLIC USE**
> This file persists conversation context for AI agents working on this repo.
> Do NOT expose, publish, or share this file outside the development team.

## Project Overview
- **Repo**: https://github.com/Exon101/sonic-cloud-flutter
- **Framework**: Flutter (Dart 3.x, Flutter 3.32+)
- **Current version**: 4.1.0+8
- **Design system**: `sonic_cloud.md` (Cloud & Sonic glassmorphic theme)
- **Platforms**: Android, iOS, macOS, Linux, Windows, Web

## Design System (sonic_cloud.md) — ALWAYS PREFER THESE DETAILS
- **Colors**: Deep indigo dark theme (#131318 surface, #00F4FE secondary/cyan, #7F66FF tertiary/violet)
- **Fonts**: Montserrat (headlines 700/600) + Inter (body 400/500/600)
- **Spacing**: 4px base, xs(8), sm(16), md(24), lg(32), xl(48), edge-margin(20), gutter(16)
- **Radius**: sm(4px), DEFAULT(8px), md(12px), lg(16px), xl(24px), full(9999px)
- **Glassmorphism**: BackdropFilter blur(20px) + 5% white fill + 1px top/left light edge border
- **Sonic glow**: Cyan drop-shadow on active playback elements

## Architecture
```
lib/
├── main.dart                    ← Entry point, all services wired here
├── models/models.dart           ← Track, Album, Artist, Playlist, Lyrics, etc.
├── services/
│   ├── playback_service.dart    ← just_audio + audio_service, queue, shuffle, repeat, sleep timer
│   ├── audio_handler.dart       ← SonicAudioHandler (BaseAudioHandler) for notification
│   ├── library_service.dart     ← Scan folders, SQLite persistence, indices
│   ├── search_service.dart      ← Instant in-memory search
│   ├── lyrics_service.dart      ← LRC parser, synced scrolling, sidecar .lrc files
│   ├── playlist_service.dart    ← Manual + smart + auto playlists with rule engine
│   ├── equalizer_service.dart   ← 10-band EQ (Dart-only state, native deferred)
│   ├── metadata_service.dart    ← audiotags Rust backend (read/write ID3/Vorbis/MP4)
│   ├── app_settings_service.dart← SharedPreferences (theme, accent, security, a11y)
│   ├── theme_service.dart       ← 5 modes (system/dark/light/AMOLED/dynamic) + accent
│   ├── security_service.dart    ← PIN, biometric, secure storage, per-provider perms
│   ├── accessibility_service.dart← High-contrast, font scale, colorblind, reduced motion
│   ├── sync_service.dart        ← Cross-device sync abstraction (LocalSyncService default)
│   ├── oauth_service.dart       ← Google Drive (google_sign_in), Dropbox/OneDrive (flutter_web_auth_2)
│   ├── universal_library_service.dart ← Aggregates local + cloud providers
│   └── local_api_service.dart   ← shelf REST API + WebSocket on :8765
├── providers/
│   ├── cloud_providers.dart     ← Abstract CloudProvider + factory + stubs
│   ├── real_webdav_provider.dart← webdav_client 1.2.x
│   ├── real_google_drive_provider.dart ← Google Drive REST API v3
│   ├── real_dropbox_provider.dart ← Dropbox API v2
│   ├── real_onedrive_provider.dart ← Microsoft Graph API
│   ├── real_nextcloud_provider.dart ← Nextcloud WebDAV
│   └── real_smb_provider.dart   ← smbclient CLI (desktop only)
├── db/app_database.dart         ← sqflite (7 tables: tracks, playlists, play_history, etc.)
├── theme/                       ← app_colors, app_typography, app_spacing, app_theme
├── widgets/                     ← glass_card, mini_player, sonic_glow_button, etc.
└── screens/                     ← my_library, now_playing, cloud_storage, settings, equalizer, lyrics, library_browse
```

## Key Decisions & Fixes

### Version History
- v3.1.0: WebDAV, smart shuffle, LRC sidecar, metadata editing
- v4.0.0: Local file playback, 6 cloud providers, rotating vinyl, mini-player, responsive UI
- v4.1.0: Player fix (MediaItem tags, AudioSource.asset), settings fix, launcher icons, mock data removed

### Critical Fixes Applied
1. **Theme not applying**: MaterialApp wrapped in AnimatedBuilder watching [_theme, _settings, _accessibility]
2. **Player not working**: AudioSource uses MediaItem tags (not String); AudioSource.asset() for asset:// URLs; try-catch with debugPrint
3. **No notification controls**: initAudioService() awaited (not .catchError); AudioService.init must complete before playback
4. **Mock data removed**: No MockData seeding; app starts empty; user adds real files via "Add Music" FAB
5. **Responsive UI**: All fixed sizes replaced with MediaQuery-based clamps; MiniPlayer in SafeArea; Flexible buttons
6. **Platform builds**: flutter create --overwrite (not --force); macOS tarball uses `cd dir && tar *.app`; Gradle 8.11.1 + AGP 8.9.1 + compileSdk 36

### CI/CD
- **CI workflow**: analyze + test + build web + build APK (all pass)
- **Release workflow**: 6 platforms + publish; `if: always()` on publish
- **GitHub Actions versions**: checkout@v5, codecov@v5, upload-artifact@v4, setup-java@v5, action-gh-release@v3
- **Branch protection**: main requires "Analyze & Test" check, linear history, no force push

### Known Issues / TODO
- OAuth placeholder credentials need real app keys (Google/Dropbox/Microsoft)
- EqualizerService native EQ deferred (Dart-only state for now)
- 4 cloud provider stubs remain: FTP, SFTP, NAS, LocalNetwork
- Some test files skipped (mocktail stub mismatch with just_audio method signatures)

### Important File Paths
- Design spec: /home/z/my-project/upload/sonic_cloud.md
- App icon: assets/icon/icon.png (user's custom 1024x1024 PNG)
- Sample audio: assets/audio/sample_track.wav (5s 220Hz tone)
- Database: sqflite at getApplicationDocumentsPath()/sonic_cloud.sqlite
- Push clone: /tmp/sonic-cloud-fresh (re-clone if deleted: git clone https://github.com/Exon101/sonic-cloud-flutter.git)

### Flutter SDK (in this environment)
- Path: /tmp/flutter/bin/flutter
- Version: 3.32.0 stable
- No Android SDK / emulator available
- Web builds work: `flutter build web --release`
- Can serve locally: `python3 -m http.server 8099 -d build/web`
- Tests pass: 112 passed, 1 skipped
- Analyze: 0 errors, 146 info-level warnings

### Git Remote
- Remote: https://github.com/Exon101/sonic-cloud-flutter.git
- Branch protection on main — must push via fresh clone at /tmp/sonic-cloud-fresh
- Cannot force push to main
