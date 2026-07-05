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

/// Sonic Cloud v3.2 — entry point.
///
/// All services are instantiated here and passed down to screens.
/// This is the single source of truth for the service graph.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SonicCloudApp());
}

class SonicCloudApp extends StatefulWidget {
  const SonicCloudApp({super.key});

  @override
  State<SonicCloudApp> createState() => _SonicCloudAppState();
}

class _SonicCloudAppState extends State<SonicCloudApp> {
  // ── Core services ──────────────────────────────────────────────────────────
  late final AudioPlayer _audioPlayer;
  late final PlaybackService _playback;
  late final EqualizerService _equalizer;
  late final LibraryService _library;
  late final UniversalLibraryService _universalLibrary;
  late final SearchService _search;
  late final LyricsService _lyrics;
  late final PlaylistService _playlists;
  late final AudioFingerprinter _fingerprinter;
  late final AppSettingsService _settings;
  late final ThemeService _theme;
  late final SecurityService _security;
  late final AccessibilityService _accessibility;
  late final SyncService _sync;
  late final LocalApiService _api;
  late final OAuthService _oauth;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    // Core audio
    _audioPlayer = AudioPlayer();
    _playback = PlaybackService(player: _audioPlayer);
    _equalizer = EqualizerService(player: _audioPlayer);

    // Library + search
    _library = LibraryService(database: AppDatabase.instance);
    _universalLibrary = UniversalLibraryService(_library, []);
    _search = SearchService();

    // Lyrics + playlists + fingerprinting
    _lyrics = LyricsService();
    _playlists = PlaylistService();
    _fingerprinter = AudioFingerprinter();

    // Settings + theme + security + accessibility
    final prefs = await SharedPreferences.getInstance();
    _settings = AppSettingsService(prefs);
    _theme = ThemeService(_settings);
    _security = SecurityService();
    _accessibility = AccessibilityService(prefs);

    // Sync (local-only default)
    _sync = LocalSyncService();

    // Local API (opt-in — start manually from settings)
    _api = LocalApiService(_playback, _universalLibrary);
    _oauth = OAuthService();

    // Open database, load saved tracks
    try {
      await AppDatabase.instance.open();
      await _library.loadFromDatabase();
    } catch (e) {
      debugPrint('Database load failed: $e');
    }

    // Index search
    _search.index(_library.tracks);

    // Init audio service (for notification + lock screen controls).
    // This MUST succeed for playback to work — don't swallow errors.
    try {
      await _playback.initAudioService();
    } catch (e) {
      debugPrint(
        'AudioService init failed (playback will still work without notification controls): $e',
      );
    }

    // Init EQ (non-fatal)
    _equalizer.init().catchError((_) {});

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _playback.dispose();
    _equalizer.dispose();
    _library.dispose();
    _api.stop();
    AppDatabase.instance.close();
    super.dispose();
  }

  void _go(int i) => setState(() => _index = i);
  int _index = 0;

  void _openPlayer() {
    final track =
        _playback.currentTrack ??
        (_playback.queue.isNotEmpty ? _playback.queue.first : null);
    if (track == null) {
      // No track loaded — switch to Library tab so user can add music
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No track loaded. Tap "Add Music" to pick files.'),
          duration: Duration(seconds: 3),
        ),
      );
      setState(() => _index = 0);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NowPlayingScreen(
          track: track,
          onClose: () => Navigator.of(context).pop(),
          playback: _playback,
          lyricsService: _lyrics,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _openEqualizer() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EqualizerScreen(eq: _equalizer)));
  }

  void _openLibraryBrowse() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryBrowseScreen(
          library: _library,
          universalLibrary: _universalLibrary,
          onPlayTrack: (t) async {
            await _playback.playAll([t]);
            _openPlayer();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder ensures the entire app rebuilds when theme/settings change
    return AnimatedBuilder(
      animation: Listenable.merge([_theme, _settings, _accessibility]),
      builder: (context, _) {
        return MaterialApp(
          title: 'Sonic Cloud',
          debugShowCheckedModeBanner: false,
          theme: _initialized ? _theme.themeData : AppTheme.dark(),
          home: _initialized
              ? _HomeShell(
                  index: _index,
                  onGo: _go,
                  onOpenPlayer: _openPlayer,
                  onOpenEqualizer: _openEqualizer,
                  onOpenLibraryBrowse: _openLibraryBrowse,
                  playback: _playback,
                  library: _library,
                  universalLibrary: _universalLibrary,
                  search: _search,
                  lyrics: _lyrics,
                  playlists: _playlists,
                  settings: _settings,
                  security: _security,
                  accessibility: _accessibility,
                  api: _api,
                  oauth: _oauth,
                  onPlayTrack: (track) async {
                    await _playback.playAll([track]);
                    _openPlayer();
                  },
                )
              : const _SplashScreen(),
        );
      },
    );
  }
}

/// Splash screen shown while services initialize.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF131318),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF00F4FE)),
              const SizedBox(height: 24),
              Text(
                'Sonic Cloud',
                style: TextStyle(
                  color: const Color(0xFFC5C3E5),
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home shell with bottom navigation and all screens.
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
      child: Column(
        children: [
          // Main content fills available space
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
                // Player tab → opens Now Playing
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
          // Mini-player bar (shown when a track is loaded)
          AnimatedBuilder(
            animation: playback,
            builder: (context, _) {
              if (playback.currentTrack == null) {
                return const SizedBox.shrink();
              }
              return MiniPlayer(playback: playback, onTap: onOpenPlayer);
            },
          ),
        ],
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
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_circle_outline,
                size: 64,
                color: Color(0xFF00F4FE),
              ),
              const SizedBox(height: 16),
              Text(
                'Open a track to start playback',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFC8C5CE),
                ),
              ),
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
      ),
    );
  }
}
