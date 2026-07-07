import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accessibility/accessibility_service.dart';
import 'models/models.dart';
import 'api/local_api_service.dart';
import 'db/app_database.dart';
import 'fingerprint/audio_fingerprinter.dart';
import 'screens/cloud_storage_screen.dart';
import 'screens/equalizer/equalizer_screen.dart';
import 'screens/library_browse/library_browse_screen.dart';
import 'screens/my_library_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/settings_screen.dart';
import 'security/security_service.dart';
import 'services/app_settings_service.dart';
import 'services/equalizer_service.dart';
import 'services/library_service.dart';
import 'services/oauth_service.dart';
import 'services/lyrics_service.dart';
import 'services/playback_service.dart';
import 'services/playlist_service.dart';
import 'services/search_service.dart';
import 'services/sync_service.dart';
import 'services/theme_service.dart';
import 'services/universal_library_service.dart';
import 'theme/app_theme.dart';
import 'widgets/glass_card.dart';
import 'widgets/mini_player.dart';
import 'widgets/bottom_nav_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SonicCloudApp());
}

class SonicCloudApp extends StatefulWidget {
  const SonicCloudApp({super.key});

  @override
  State<SonicCloudApp> createState() => _SonicCloudAppState();
}

class _SonicCloudAppState extends State<SonicCloudApp> {
  AudioPlayer? _audioPlayer;
  PlaybackService? _playback;
  EqualizerService? _equalizer;
  LibraryService? _library;
  UniversalLibraryService? _universalLibrary;
  SearchService? _search;
  LyricsService? _lyrics;
  PlaylistService? _playlists;
  AudioFingerprinter? _fingerprinter;
  AppSettingsService? _settings;
  ThemeService? _theme;
  SecurityService? _security;
  AccessibilityService? _accessibility;
  SyncService? _sync;
  LocalApiService? _api;
  OAuthService? _oauth;

  bool _initialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      // Step 1: Create all services synchronously
      _audioPlayer = AudioPlayer();
      _playback = PlaybackService(player: _audioPlayer!);
      _equalizer = EqualizerService(player: _audioPlayer!);
      _library = LibraryService(database: AppDatabase.instance);
      _universalLibrary = UniversalLibraryService(_library!, []);
      _search = SearchService();
      _lyrics = LyricsService();
      _playlists = PlaylistService();
      _fingerprinter = AudioFingerprinter();
      _security = SecurityService();
      _oauth = OAuthService();
      _sync = LocalSyncService();

      // Step 2: SharedPreferences (3s timeout)
      SharedPreferences prefs;
      try {
        prefs = await SharedPreferences.getInstance()
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('SharedPreferences failed, retrying: $e');
        prefs = await SharedPreferences.getInstance();
      }

      _settings = AppSettingsService(prefs);
      _accessibility = AccessibilityService(prefs);
      // CRITICAL: _accessibility must be created BEFORE _theme
      _theme = ThemeService(_settings!, _accessibility!);
      _api = LocalApiService(_playback!, _universalLibrary!);

      // Step 3: Database (5s timeout)
      try {
        await AppDatabase.instance.open().timeout(const Duration(seconds: 5));
        await _library!.loadFromDatabase().timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Database init failed: $e');
      }

      // Step 4: Index search
      _search!.index(_library!.tracks);

      // Step 5: Audio service (5s timeout, non-fatal)
      try {
        await _playback!.initAudioService().timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('AudioService init failed: $e');
      }

      // Step 6: EQ (3s timeout, non-fatal)
      try {
        await _equalizer!.init().timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('EQ init failed: $e');
      }
    } catch (e) {
      debugPrint('_initServices error: $e');
      _initError = e.toString();
    }

    // ALWAYS set _initialized = true
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _playback?.dispose();
    _equalizer?.dispose();
    _library?.dispose();
    _api?.stop();
    AppDatabase.instance.close();
    super.dispose();
  }

  int _index = 0;
  void _go(int i) => setState(() => _index = i);

  void _openPlayer() {
    final playback = _playback;
    if (playback == null) return;
    final track = playback.currentTrack ??
        (playback.queue.isNotEmpty ? playback.queue.first : null);
    if (track == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No track loaded. Tap "Add Music" to pick files.'),
          duration: Duration(seconds: 3),
        ),
      );
      setState(() => _index = 1);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NowPlayingScreen(
          track: track,
          onClose: () => Navigator.of(context).pop(),
          playback: playback,
          lyricsService: _lyrics,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _openEqualizer() {
    if (_equalizer == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EqualizerScreen(eq: _equalizer!)),
    );
  }

  void _openLibraryBrowse() {
    if (_library == null || _universalLibrary == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryBrowseScreen(
          library: _library!,
          universalLibrary: _universalLibrary!,
          onPlayTrack: (t) async {
            await _playback?.playAll([t]);
            _openPlayer();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Not initialized — show splash (separate MaterialApp, no nesting)
    if (!_initialized) {
      return MaterialApp(
        title: 'Sonic Cloud',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF131318),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: Color(0xFF00F4FE),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sonic Cloud',
                  style: TextStyle(
                    color: Color(0xFFC5C3E5),
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Init failed — show error
    if (_settings == null || _theme == null || _playback == null) {
      return MaterialApp(
        title: 'Sonic Cloud',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF131318),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 64, color: Color(0xFFFFB4AB)),
                  const SizedBox(height: 16),
                  const Text('Initialization Failed',
                      style: TextStyle(
                          color: Color(0xFFE4E1E9),
                          fontSize: 20,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(_initError ?? 'Unknown error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFC8C5CE), fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Normal app
    return AnimatedBuilder(
      animation: Listenable.merge([_theme!, _settings!, _accessibility!]),
      builder: (context, _) {
        return MaterialApp(
          title: 'Sonic Cloud',
          debugShowCheckedModeBanner: false,
          theme: _theme!.themeData,
          home: _HomeShell(
            index: _index,
            onGo: _go,
            onOpenPlayer: _openPlayer,
            onOpenEqualizer: _openEqualizer,
            onOpenLibraryBrowse: _openLibraryBrowse,
            playback: _playback!,
            library: _library!,
            universalLibrary: _universalLibrary!,
            search: _search!,
            lyrics: _lyrics!,
            playlists: _playlists!,
            settings: _settings!,
            security: _security!,
            accessibility: _accessibility!,
            api: _api!,
            oauth: _oauth!,
            onPlayTrack: (track) async {
              await _playback!.playAll([track]);
              _openPlayer();
            },
          ),
        );
      },
    );
  }
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({
    required this.index,
    required this.onGo,
    required this.onOpenPlayer,
    required this.onOpenEqualizer,
    required this.onOpenLibraryBrowse,
    required this.playback,
    required this.library,
    required this.universalLibrary,
    required this.search,
    required this.lyrics,
    required this.playlists,
    required this.settings,
    required this.security,
    required this.accessibility,
    required this.api,
    required this.oauth,
    required this.onPlayTrack,
  });

  final int index;
  final ValueChanged<int> onGo;
  final VoidCallback onOpenPlayer;
  final VoidCallback onOpenEqualizer;
  final VoidCallback onOpenLibraryBrowse;
  final PlaybackService playback;
  final LibraryService library;
  final UniversalLibraryService universalLibrary;
  final SearchService search;
  final LyricsService lyrics;
  final PlaylistService playlists;
  final AppSettingsService settings;
  final SecurityService security;
  final AccessibilityService accessibility;
  final LocalApiService api;
  final OAuthService oauth;
  final void Function(Track) onPlayTrack;

  @override
  Widget build(BuildContext context) {
    return AmbientBackground(
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // Main content
            Expanded(
              child: IndexedStack(
                index: index,
                children: [
                  MyLibraryScreen(
                    onOpenPlayer: onOpenPlayer,
                    onOpenCloud: () => onGo(2),
                    onOpenSettings: () => onGo(3),
                    onOpenBrowse: onOpenLibraryBrowse,
                    onOpenEqualizer: onOpenEqualizer,
                    library: library,
                    search: search,
                    onPlayTrack: onPlayTrack,
                  ),
                  _PlayerTabPlaceholder(onOpenPlayer: onOpenPlayer),
                  CloudStorageScreen(
                    oauth: oauth,
                    onOpenLibrary: () => onGo(0),
                    onOpenPlayer: onOpenPlayer,
                    onOpenSettings: () => onGo(3),
                  ),
                  SettingsScreen(
                    onOpenLibrary: () => onGo(0),
                    onOpenPlayer: onOpenPlayer,
                    onOpenCloud: () => onGo(2),
                    settings: settings,
                    security: security,
                    accessibility: accessibility,
                    api: api,
                  ),
                ],
              ),
            ),
            // Mini player (above bottom nav bar)
            AnimatedBuilder(
              animation: playback,
              builder: (context, _) {
                if (playback.currentTrack == null) {
                  return const SizedBox.shrink();
                }
                return MiniPlayer(playback: playback, onTap: onOpenPlayer);
              },
            ),
            // Shared bottom navigation bar
            SonicBottomNavBar(
              currentIndex: index,
              onTap: (i) {
                if (i == 1) {
                  onOpenPlayer();
                } else {
                  onGo(i);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerTabPlaceholder extends StatelessWidget {
  const _PlayerTabPlaceholder({required this.onOpenPlayer});
  final VoidCallback onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_outline,
                size: 64, color: Color(0xFF00F4FE)),
            const SizedBox(height: 16),
            Text('Open a track to start playback',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: const Color(0xFFC8C5CE))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onOpenPlayer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F4FE),
                foregroundColor: const Color(0xFF0E0E13),
              ),
              child: const Text('Open Now Playing'),
            ),
          ],
        ),
      ),
    );
  }
}
