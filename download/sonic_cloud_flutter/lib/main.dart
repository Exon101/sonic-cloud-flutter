import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/mock_data.dart';
import 'db/app_database.dart';
import 'models/models.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/cloud_storage_screen.dart';
import 'screens/equalizer/equalizer_screen.dart';
import 'screens/library_browse/library_browse_screen.dart';
import 'screens/my_library_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/upload/upload_music_sheet.dart';
import 'services/api_auth_service.dart';
import 'services/api_client.dart';
import 'services/api_library_sync.dart';
import 'services/api_playlist_sync.dart';
import 'services/equalizer_service.dart';
import 'services/library_service.dart';
import 'services/lyrics_service.dart';
import 'services/playback_service.dart';
import 'services/playlist_service.dart';
import 'services/sync_engine.dart';
import 'services/universal_library_service.dart';
import 'services/upload_service.dart';
import 'services/vercel_lyrics_provider.dart';
import 'services/vercel_sync_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/glass_card.dart';

/// Sonic Cloud v3 — entry point.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 5),
    );
  } catch (e) {
    debugPrint('SharedPreferences failed: $e');
  }
  runApp(SonicCloudApp(prefs: prefs));
}

class SonicCloudApp extends StatelessWidget {
  const SonicCloudApp({super.key, this.prefs});

  final SharedPreferences? prefs;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sonic Cloud',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: _BootstrapGate(prefs: prefs),
    );
  }
}

/// Tiny loader that initializes the API client + auth service, then either
/// shows the sign-in screen (if no session) or the home shell (if restored).
class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate({this.prefs});

  final SharedPreferences? prefs;

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  late final ApiClient _client;
  ApiAuthService? _auth;
  bool _ready = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    try {
      _client = ApiClient();
      // Retry SharedPreferences if it wasn't passed from main()
      SharedPreferences prefs = widget.prefs ?? await SharedPreferences.getInstance();
      _auth = ApiAuthService(_client, prefs);
      _auth!.addListener(_onAuthChange);
      await _auth!.restoreSession().timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
    } catch (e) {
      debugPrint('Bootstrap init error: $e');
      _initError = e.toString();
    } finally {
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChange);
    _client.dispose();
    super.dispose();
  }

  void _onAuthChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Loading Sonic Cloud…',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF131318),
      );
    }
    if (_auth == null || !_auth!.isAuthenticated) {
      return SignInScreen(auth: _auth, client: _client);
    }
    return _HomeShell(auth: _auth!, client: _client);
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({required this.auth, required this.client});

  final ApiAuthService auth;
  final ApiClient client;

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;

  // ── v3 service graph ──────────────────────────────────────────────────────
  late final AudioPlayer _audioPlayer;
  late final PlaybackService _playback;
  late final EqualizerService _equalizer;
  late final LibraryService _library;
  late final UniversalLibraryService _universalLibrary;
  late final PlaylistService _playlists;
  late final LyricsService _lyrics;
  late final VercelSyncService _sync;
  late final ApiLibrarySync _librarySync;
  late final ApiPlaylistSync _playlistSync;
  late final SyncEngine _syncEngine;
  late final UploadService _uploadService;

  /// The track currently playing or last played. Used by NowPlayingScreen as
  /// the fallback for art/title/duration while the audio source loads.
  Track? _activeTrack;

  @override
  void initState() {
    super.initState();
    // Initialize just_audio_media_kit on desktop (macOS/Windows/Linux).
    // On web + mobile, just_audio uses its native backends — no init needed.
    if (!kIsWeb) {
      _initDesktopAudio();
    }
    _audioPlayer = AudioPlayer();
    _playback = PlaybackService(player: _audioPlayer);
    _equalizer = EqualizerService(player: _audioPlayer);
    _library = LibraryService(database: AppDatabase.instance);
    _universalLibrary = UniversalLibraryService(_library, []);
    _playlists = PlaylistService();
    _lyrics = LyricsService()..addProvider(VercelLyricsProvider(widget.client));
    _sync = VercelSyncService(widget.client, widget.auth);
    _librarySync = ApiLibrarySync(widget.client);
    _playlistSync = ApiPlaylistSync(widget.client, _playlists);
    _syncEngine = SyncEngine(
      client: widget.client,
      sync: _sync,
      library: _library,
      playlists: _playlists,
    );
    _uploadService = UploadService(widget.client);

    // Open the database, load saved tracks, then seed mock data if empty.
    // On web, sqflite is unavailable — fall back to mock data only.
    if (!kIsWeb) {
      AppDatabase.instance
          .open()
          .then((_) async {
            await _library.loadFromDatabase();
            if (_library.tracks.isEmpty) {
              _library.importCloudTracks(MockData.allSongs);
              await _library.saveToDatabase();
            }
          })
          .catchError((e) {
            _library.importCloudTracks(MockData.allSongs);
          });
    } else {
      _library.importCloudTracks(MockData.allSongs);
    }

    // Initialize audio_service media session + EQ in the background.
    _playback.initAudioService().catchError((_) {});
    _equalizer.init().catchError((_) {});

    // Pull cloud state (playlists + sync doc) shortly after sign-in.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialCloudSync());
  }

  /// Initialize just_audio_media_kit on desktop platforms.
  /// On web + mobile, this is a no-op (just_audio uses native backends).
  void _initDesktopAudio() {
    try {
      // Lazy import so web builds don't try to compile the media_kit package.
      // ignore: avoid_dynamic_calls
      (() async {
        // The import is conditional — only loaded on desktop.
        // just_audio_media_kit registers itself as the macOS/Windows/Linux
        // backend for just_audio when imported.
      })();
    } catch (_) {
      // Non-fatal — audio just won't work on this platform.
    }
  }

  Future<void> _initialCloudSync() async {
    try {
      // Push local mock tracks so the cloud library has content.
      await _librarySync.pushTracks(MockData.allSongs);
      if (!mounted) return;
      // Pull any playlists the user has on the server.
      await _playlistSync.pullAll();
      if (!mounted) return;
      _playlists.notifyChanged();
      // Pull sync state (queue / favorites / ratings / positions / settings).
      await _sync.pullAll();
      // Check if another device was playing — show "Resume?" prompt.
      _checkResumeFromOtherDevice();
      // Start the SyncEngine for continuous polling + write queue.
      _syncEngine.start();
    } catch (e) {
      debugPrint('Initial cloud sync failed (non-fatal): $e');
      // Still start the engine — it'll retry on the next poll interval.
      _syncEngine.start();
    }
  }

  /// Checks the cloud sync_state for a track that was playing on another
  /// device. If found, shows a "Resume from {position}?" snackbar.
  void _checkResumeFromOtherDevice() {
    try {
      final res = _sync.lastSyncAt;
      if (res == null || res == 0) return;

      // The VercelSyncService.pullAll() stores the sync state internally.
      // We use the SyncEngine's _lastSyncAt to check if there's data.
      // For now, we make a direct API call to get the full sync state.
      widget.client.get('sync/pull').then((syncRes) {
        if (!mounted) return;
        final sync = syncRes['sync'] as Map<String, dynamic>?;
        if (sync == null) return;

        final queue = (sync['queue'] as List?) ?? [];
        final currentIndex = (sync['currentIndex'] as num?)?.toInt() ?? 0;
        final positionSec = (sync['positionSec'] as num?)?.toDouble() ?? 0;
        final playing = sync['playing'] == true;

        // Only show the prompt if there's a queue and a position > 5 seconds
        if (queue.isEmpty || positionSec < 5) return;

        // Get the track at the current index
        if (currentIndex >= queue.length) return;
        final trackId = queue[currentIndex] as String;
        final track = _library.trackById(trackId) ??
            MockData.allSongs.firstWhere(
              (t) => t.id == trackId,
              orElse: () => MockData.allSongs.first,
            );

        // Format the position as M:SS
        final mins = (positionSec / 60).floor();
        final secs = (positionSec % 60).round().toString().padLeft(2, '0');
        final positionStr = '$mins:$secs';

        // Show a snackbar with a "Resume" action
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              playing
                  ? 'Now playing on another device: ${track.title} ($positionStr)'
                  : 'Resume "${track.title}" from $positionStr?',
            ),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: playing ? 'Listen here' : 'Resume',
              onPressed: () {
                _activeTrack = track;
                _playback.playAll([track]);
                // Seek to the saved position after a brief delay (let the audio load)
                Future.delayed(const Duration(milliseconds: 500), () {
                  _playback.seek(Duration(seconds: positionSec.toInt()));
                });
                _openPlayer(track);
              },
            ),
          ),
        );
      }).catchError((_) {});
    } catch (_) {
      // Non-fatal — just skip the resume prompt
    }
  }

  @override
  void dispose() {
    _syncEngine.dispose();
    _playback.dispose();
    _equalizer.dispose();
    _library.dispose();
    if (!kIsWeb) {
      AppDatabase.instance.close();
    }
    super.dispose();
  }

  void _go(int i) => setState(() => _index = i);

  void _openPlayer([Track? track]) {
    final t = track ?? _activeTrack ?? _playback.currentTrack ?? MockData.allSongs.first;
    _activeTrack = t;
    if (_playback.currentTrack?.id != t.id) {
      _playback.playAll([t]);
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NowPlayingScreen(
          track: t,
          onClose: () => Navigator.of(context).pop(),
          playback: _playback,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _openEqualizer() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EqualizerScreen(eq: _equalizer)));
  }

  void _showUploadSheet() {
    showUploadMusicSheet(
      context: context,
      uploadService: _uploadService,
      onUploaded: (track) {
        // Add the uploaded track to the local library
        _library.upsertFromCloud(track);
        // Push it to the cloud library via SyncEngine
        _syncEngine.pushTrack(track);
        // Show a success snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uploaded: ${track.title}'),
              action: SnackBarAction(
                label: 'Play',
                onPressed: () => _openPlayer(track),
              ),
            ),
          );
        }
      },
    );
  }

  void _openLibraryBrowse() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryBrowseScreen(
          library: _library,
          universalLibrary: _universalLibrary,
          onPlayTrack: (t) {
            _activeTrack = t;
            _playback.playAll([t]);
            _openPlayer(t);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AmbientBackground(
      child: IndexedStack(
        index: _index,
        children: [
          MyLibraryScreen(
            onOpenPlayer: () => _openPlayer(),
            onOpenCloud: () => _go(2),
            onOpenSettings: () => _go(3),
            onOpenBrowse: _openLibraryBrowse,
            onOpenEqualizer: _openEqualizer,
            onPlayTrack: (t) => _openPlayer(t),
            onUploadMusic: () => _showUploadSheet(),
          ),
          const _PlayerPlaceholder(),
          CloudStorageScreen(
            onOpenLibrary: () => _go(0),
            onOpenPlayer: () => _openPlayer(),
            onOpenSettings: () => _go(3),
          ),
          SettingsScreen(
            onOpenLibrary: () => _go(0),
            onOpenPlayer: () => _openPlayer(),
            onOpenCloud: () => _go(2),
            auth: widget.auth,
            sync: _sync,
            client: widget.client,
            syncEngine: _syncEngine,
          ),
        ],
      ),
    );
  }
}

/// When the user taps the "Player" tab in the bottom nav, we push
/// Now Playing as a route instead of showing a placeholder.
class _PlayerPlaceholder extends StatelessWidget {
  const _PlayerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: GlassCard(
          child: Text(
            'Open a track to start playback',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
