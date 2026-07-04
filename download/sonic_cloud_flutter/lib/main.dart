import 'package:flutter/material.dart';
import 'data/mock_data.dart';
import 'screens/cloud_storage_screen.dart';
import 'screens/equalizer/equalizer_screen.dart';
import 'screens/library_browse/library_browse_screen.dart';
import 'screens/my_library_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/settings_screen.dart';
import 'services/equalizer_service.dart';
import 'services/library_service.dart';
import 'services/playback_service.dart';
import 'services/universal_library_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/glass_card.dart';

/// Sonic Cloud v3 — entry point.
///
/// Wires together every service at startup and exposes the bottom-nav shell.
void main() {
  runApp(const SonicCloudApp());
}

class SonicCloudApp extends StatelessWidget {
  const SonicCloudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sonic Cloud',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const _HomeShell(),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;

  // ── v3 service graph ──────────────────────────────────────────────────────
  late final PlaybackService _playback;
  late final EqualizerService _equalizer;
  late final LibraryService _library;
  late final UniversalLibraryService _universalLibrary;

  @override
  void initState() {
    super.initState();
    _playback = PlaybackService();
    _equalizer = EqualizerService(player: null); // bound later via init()
    _library = LibraryService();
    _universalLibrary = UniversalLibraryService(_library, []);

    // Initialize audio_service media session + EQ in the background.
    _playback.initAudioService().catchError((_) {});
    _equalizer.init().catchError((_) {});

    // Seed library with mock data for demo purposes.
    _library.importCloudTracks(MockData.allSongs);
  }

  @override
  void dispose() {
    _playback.dispose();
    _equalizer.dispose();
    _library.dispose();
    super.dispose();
  }

  void _go(int i) => setState(() => _index = i);

  void _openPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NowPlayingScreen(
          track: MockData.allSongs.first,
          onClose: () => Navigator.of(context).pop(),
          playback: _playback,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _openEqualizer() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EqualizerScreen(eq: _equalizer)),
    );
  }

  void _openLibraryBrowse() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryBrowseScreen(
          library: _library,
          universalLibrary: _universalLibrary,
          onPlayTrack: (t) {
            _playback.playAll([t]);
            _openPlayer();
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
            onOpenPlayer: _openPlayer,
            onOpenCloud: () => _go(2),
            onOpenSettings: () => _go(3),
            onOpenBrowse: _openLibraryBrowse,
            onOpenEqualizer: _openEqualizer,
          ),
          // Player tab → opens Now Playing
          const _PlayerPlaceholder(),
          CloudStorageScreen(
            onOpenLibrary: () => _go(0),
            onOpenPlayer: _openPlayer,
            onOpenSettings: () => _go(3),
          ),
          SettingsScreen(
            onOpenLibrary: () => _go(0),
            onOpenPlayer: _openPlayer,
            onOpenCloud: () => _go(2),
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
