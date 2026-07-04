import 'package:flutter/material.dart';
import '../gestures/gesture_controls.dart';
import '../models/models.dart';
import '../services/playback_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart' as r;
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/sonic_glow_button.dart';
import '../widgets/waveform_progress.dart';

/// Now Playing screen.
///
/// Spec:
///   - Immersive full-screen view, bottom nav suppressed
///   - Minimal top bar (collapse / Now Playing / more)
///   - Circular album art with glassmorphic outer ring + sonic glow pulse
///   - Center spindle hole like a vinyl record
///   - Track title + cloud_sync icon + artist subtitle
///   - Waveform seek bar with timestamps
///   - Glassmorphic playback control pill: shuffle / prev / play-pause / next / repeat
///
/// Playback wiring:
///   - Receives a [PlaybackService] (typically shared across the app).
///   - Loads the track's audio URL on first build via `service.load(...)`.
///   - Listens to the service via [ListenableBuilder] so the UI updates
///     whenever position / playing state changes.
///   - Waveform drag → `service.seekToProgress(...)`.
///   - Play/pause button → `service.togglePlayPause()`.
class NowPlayingScreen extends StatefulWidget {
  final Track track;
  final VoidCallback onClose;
  final PlaybackService playback;

  const NowPlayingScreen({
    super.key,
    required this.track,
    required this.onClose,
    required this.playback,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  @override
  void initState() {
    super.initState();
    // Load the audio source asynchronously. The widget rebuilds when the
    // service notifies listeners (position/duration/isPlaying).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.playback.load(widget.track.audioUrl).then((_) {
        if (mounted) widget.playback.play();
      });
    });
  }

  @override
  void dispose() {
    // Pause (but don't dispose — the service is owned higher up).
    widget.playback.pause();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.abs();
    final s = (d.inSeconds.abs() % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GestureControls(
          onTogglePlay: () => widget.playback.togglePlayPause(),
          onNext: () => widget.playback.skipToNext(),
          onPrevious: () => widget.playback.skipToPrevious(),
          child: AnimatedBuilder(
            animation: widget.playback,
            builder: (context, _) {
              final pos = widget.playback.position;
              final dur = widget.playback.duration > Duration.zero
                  ? widget.playback.duration
                  : widget.track.duration;
              final remaining = dur - pos;
              final progress = widget.playback.duration > Duration.zero
                  ? widget.playback.progress
                  : 0.35; // fallback mock position before audio loads

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.edgeMargin),
                child: Column(
                  children: [
                    _TopBar(onClose: widget.onClose),
                    const Spacer(),
                    _VinylArt(artUrl: widget.track.artUrl),
                    const SizedBox(height: AppSpacing.md),
                    _TrackInfo(track: widget.track),
                    const Spacer(),
                    _WaveformSection(
                      progress: progress,
                      position: _fmt(pos),
                      remaining: _fmt(remaining),
                      onSeek: (p) => widget.playback.seekToProgress(p),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _Controls(
                      isPlaying: widget.playback.isPlaying,
                      onPlayPause: () => widget.playback.togglePlayPause(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.onSurface, size: 28),
            tooltip: 'Collapse',
            constraints: const BoxConstraints(
              minWidth: AppSpacing.touchTarget,
              minHeight: AppSpacing.touchTarget,
            ),
          ),
          Text(
            'NOW PLAYING',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant.withOpacity(0.8),
              letterSpacing: 2.0,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.onSurface, size: 24),
            tooltip: 'More',
            constraints: const BoxConstraints(
              minWidth: AppSpacing.touchTarget,
              minHeight: AppSpacing.touchTarget,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vinyl-style album art
// ─────────────────────────────────────────────────────────────────────────────
class _VinylArt extends StatelessWidget {
  final String artUrl;
  const _VinylArt({required this.artUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _PulsingRing(),
          Container(
            width: 295,
            height: 295,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(image: NetworkImage(artUrl), fit: BoxFit.cover),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background.withOpacity(0.8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingRing extends StatefulWidget {
  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final blurSigma = 40 + 30 * t;
        final glowAlpha = 0.30 + 0.30 * t;
        return Container(
          width: 330,
          height: 330,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface.withOpacity(0.20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: AppColors.sonicGlow.withOpacity(glowAlpha),
                blurRadius: blurSigma,
                spreadRadius: -10,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Track info
// ─────────────────────────────────────────────────────────────────────────────
class _TrackInfo extends StatelessWidget {
  final Track track;
  const _TrackInfo({required this.track});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                track.title,
                style: AppTypography.headlineXl.copyWith(color: AppColors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.cloud_sync_rounded,
                color: AppColors.secondaryContainer, size: 24),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          track.artist,
          style: AppTypography.bodyLg.copyWith(
            color: AppColors.primary.withOpacity(0.8),
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Waveform + timestamps
// ─────────────────────────────────────────────────────────────────────────────
class _WaveformSection extends StatelessWidget {
  final double progress;
  final String position;
  final String remaining;
  final ValueChanged<double> onSeek;

  const _WaveformSection({
    required this.progress,
    required this.position,
    required this.remaining,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        WaveformProgress(progress: progress, onSeek: onSeek),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(position,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant.withOpacity(0.7),
                  letterSpacing: 1.5,
                )),
            Text('-$remaining',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant.withOpacity(0.7),
                  letterSpacing: 1.5,
                )),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Playback controls pill
// ─────────────────────────────────────────────────────────────────────────────
class _Controls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;

  const _Controls({required this.isPlaying, required this.onPlayPause});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withOpacity(0.30),
        borderRadius: BorderRadius.circular(r.AppRadius.full),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.shuffle_rounded,
                color: AppColors.onSurfaceVariant, size: 20),
            tooltip: 'Shuffle',
            constraints: const BoxConstraints(
              minWidth: AppSpacing.touchTarget,
              minHeight: AppSpacing.touchTarget,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.skip_previous_rounded,
                color: AppColors.onSurface, size: 36),
            tooltip: 'Previous',
            constraints: const BoxConstraints(
              minWidth: AppSpacing.touchTarget,
              minHeight: AppSpacing.touchTarget,
            ),
          ),
          SonicGlowButton(isPlaying: isPlaying, onTap: onPlayPause, size: 80),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.skip_next_rounded,
                color: AppColors.onSurface, size: 36),
            tooltip: 'Next',
            constraints: const BoxConstraints(
              minWidth: AppSpacing.touchTarget,
              minHeight: AppSpacing.touchTarget,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.repeat_rounded,
                color: AppColors.secondaryContainer, size: 20),
            tooltip: 'Repeat',
            constraints: const BoxConstraints(
              minWidth: AppSpacing.touchTarget,
              minHeight: AppSpacing.touchTarget,
            ),
          ),
        ],
      ),
    );
  }
}
