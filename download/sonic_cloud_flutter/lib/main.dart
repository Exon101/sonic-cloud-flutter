import 'package:flutter/material.dart';
import 'data/mock_data.dart';
import 'screens/cloud_storage_screen.dart';
import 'screens/my_library_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/settings_screen.dart';
import 'services/playback_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/glass_card.dart';

/// Sonic Cloud — entry point.
///
/// Holds the bottom-nav index in state and swaps the active screen.
/// Now Playing is pushed as a full-screen route (no bottom nav) to match
/// the spec's "navigation suppressed on Now Playing" rule.
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
  final PlaybackService _playback = PlaybackService();

  @override
  void dispose() {
    _playback.dispose();
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

  @override
  Widget build(BuildContext context) {
    // The ambient gradient + glow blob sit behind whichever screen is active.
    return AmbientBackground(
      child: IndexedStack(
        index: _index,
        children: [
          MyLibraryScreen(
            onOpenPlayer: _openPlayer,
            onOpenCloud: () => _go(2),
            onOpenSettings: () => _go(3),
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
/// Now Playing as a route instead of showing a placeholder. This widget
/// is only ever shown if IndexedStack renders index 1, which it won't,
/// because tapping that tab calls `_openPlayer()` instead of `_go(1)`.
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
