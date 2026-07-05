import 'package:flutter/material.dart' hide RepeatMode;
import '../gestures/gesture_controls.dart';
import '../models/models.dart';
import '../services/lyrics_service.dart';
import '../services/playback_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart' as r;
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/sonic_glow_button.dart';
import '../widgets/waveform_progress.dart';
import 'lyrics/lyrics_screen.dart';
import 'lyrics/sleep_timer_sheet.dart';

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
  final LyricsService? lyricsService;

  const NowPlayingScreen({
    super.key,
    required this.track,
    required this.onClose,
    required this.playback,
    this.lyricsService,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  @override
  void initState() {
    super.initState();
    // If nothing is playing yet, start playing this track.
    // Don't replay if the caller (onPlayTrack) already started it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.playback.isPlaying && widget.playback.currentTrack == null) {
        widget.playback.playAll([widget.track]);
      }
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.edgeMargin,
                ),
                child: Column(
                  children: [
                    _TopBar(
                      onClose: widget.onClose,
                      onOpenLyrics: widget.lyricsService != null
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LyricsScreen(
                                    lyricsService: widget.lyricsService!,
                                    track:
                                        widget.playback.currentTrack ??
                                        widget.track,
                                    currentPosition: () =>
                                        widget.playback.position,
                                    positionStream: Stream.periodic(
                                      const Duration(milliseconds: 500),
                                      (_) {
                                        return widget.playback.position;
                                      },
                                    ),
                                    onSeek: (d) => widget.playback.seek(d),
                                  ),
                                ),
                              );
                            }
                          : null,
                      onOpenSleepTimer: () {
                        SleepTimerSheet.show(
                          context,
                          onStart: (duration) {
                            widget.playback.startSleepTimer(duration);
                          },
                          onCancel: () {
                            widget.playback.cancelSleepTimer();
                          },
                          currentAction: SleepTimerEndAction.pause,
                          onActionChanged: (action) {
                            // The action is set on the service when startSleepTimer is called
                          },
                        );
                      },
                    ),
                    const Spacer(),
                    _VinylArt(
                      artUrl: widget.track.artUrl,
                      isPlaying: widget.playback.isPlaying,
                    ),
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
                      onShuffle: () => widget.playback.toggleShuffle(),
                      onPrevious: () => widget.playback.skipToPrevious(),
                      onNext: () => widget.playback.skipToNext(),
                      onRepeat: () => widget.playback.cycleRepeatMode(),
                      shuffleEnabled: widget.playback.shuffleEnabled,
                      repeatMode: widget.playback.repeatMode,
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
  final VoidCallback? onOpenLyrics;
  final VoidCallback? onOpenSleepTimer;
  const _TopBar({
    required this.onClose,
    this.onOpenLyrics,
    this.onOpenSleepTimer,
  });

  @override
  Widget build(BuildContext context) {
    // Use smaller touch targets on narrow screens to prevent overflow
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 360;
    final buttonSize = isNarrow ? 36.0 : 44.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.onSurface,
              size: 28,
            ),
            tooltip: 'Collapse',
            constraints: BoxConstraints(
              minWidth: buttonSize,
              minHeight: buttonSize,
            ),
            padding: EdgeInsets.zero,
          ),
          Flexible(
            child: Text(
              'NOW PLAYING',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant.withOpacity(0.8),
                letterSpacing: 2.0,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onOpenLyrics != null)
                IconButton(
                  onPressed: onOpenLyrics,
                  icon: const Icon(
                    Icons.lyrics_rounded,
                    color: AppColors.onSurface,
                    size: 22,
                  ),
                  tooltip: 'Lyrics',
                  constraints: BoxConstraints(
                    minWidth: buttonSize,
                    minHeight: buttonSize,
                  ),
                  padding: EdgeInsets.zero,
                ),
              if (onOpenSleepTimer != null)
                IconButton(
                  onPressed: onOpenSleepTimer,
                  icon: const Icon(
                    Icons.bedtime_rounded,
                    color: AppColors.onSurface,
                    size: 22,
                  ),
                  tooltip: 'Sleep timer',
                  constraints: BoxConstraints(
                    minWidth: buttonSize,
                    minHeight: buttonSize,
                  ),
                  padding: EdgeInsets.zero,
                ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.onSurface,
                  size: 24,
                ),
                tooltip: 'More',
                constraints: BoxConstraints(
                  minWidth: buttonSize,
                  minHeight: buttonSize,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vinyl-style album art
// ─────────────────────────────────────────────────────────────────────────────
class _VinylArt extends StatefulWidget {
  final String artUrl;
  final bool isPlaying;
  const _VinylArt({required this.artUrl, this.isPlaying = true});

  @override
  State<_VinylArt> createState() => _VinylArtState();
}

class _VinylArtState extends State<_VinylArt> with TickerProviderStateMixin {
  late final AnimationController _rotationCtrl;

  @override
  void initState() {
    super.initState();
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // 20s per rotation = 33⅓ RPM
    );
    if (widget.isPlaying) _rotationCtrl.repeat();
  }

  @override
  void didUpdateWidget(_VinylArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _rotationCtrl.repeat();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _rotationCtrl.stop();
    }
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Responsive sizing: use min(screenWidth * 0.85, 320) for the vinyl
    final screenWidth = MediaQuery.sizeOf(context).width;
    final artSize = (screenWidth * 0.85).clamp(200.0, 320.0);
    final discSize = artSize * 0.92;

    return SizedBox(
      width: artSize,
      height: artSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _PulsingRing(artSize: artSize),
          // Rotating vinyl disc
          AnimatedBuilder(
            animation: _rotationCtrl,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationCtrl.value * 2 * 3.141592653589793,
                child: child,
              );
            },
            child: Container(
              width: discSize,
              height: discSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: NetworkImage(widget.artUrl),
                  fit: BoxFit.cover,
                ),
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
                  // Vinyl grooves (subtle rings) — responsive to disc size
                  ...List.generate(5, (i) {
                    final size = discSize * 0.4 + i * (discSize * 0.1);
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.03),
                          width: 0.5,
                        ),
                      ),
                    );
                  }),
                  // Center spindle hole
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
          ),
        ],
      ),
    );
  }
}

class _PulsingRing extends StatefulWidget {
  final double artSize;
  const _PulsingRing({this.artSize = 320});

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
          width: widget.artSize * 1.03,
          height: widget.artSize * 1.03,
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
                style: AppTypography.headlineXl.copyWith(
                  color: AppColors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.cloud_sync_rounded,
              color: AppColors.secondaryContainer,
              size: 24,
            ),
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
            Text(
              position,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant.withOpacity(0.7),
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '-$remaining',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant.withOpacity(0.7),
                letterSpacing: 1.5,
              ),
            ),
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
  final VoidCallback? onShuffle;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onRepeat;
  final bool shuffleEnabled;
  final RepeatMode repeatMode;

  const _Controls({
    required this.isPlaying,
    required this.onPlayPause,
    this.onShuffle,
    this.onPrevious,
    this.onNext,
    this.onRepeat,
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
  });

  @override
  Widget build(BuildContext context) {
    // Responsive: cap at 320 but shrink on narrow screens
    final screenWidth = MediaQuery.sizeOf(context).width;
    final barWidth = (screenWidth - AppSpacing.edgeMargin * 2).clamp(
      200.0,
      360.0,
    );

    return Container(
      width: barWidth,
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: IconButton(
              onPressed: onShuffle,
              icon: Icon(
                Icons.shuffle_rounded,
                color: shuffleEnabled
                    ? AppColors.secondaryContainer
                    : AppColors.onSurfaceVariant,
                size: 20,
              ),
              tooltip: 'Shuffle',
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
          ),
          Flexible(
            child: IconButton(
              onPressed: onPrevious,
              icon: const Icon(
                Icons.skip_previous_rounded,
                color: AppColors.onSurface,
                size: 32,
              ),
              tooltip: 'Previous',
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
          ),
          SonicGlowButton(isPlaying: isPlaying, onTap: onPlayPause, size: 72),
          Flexible(
            child: IconButton(
              onPressed: onNext,
              icon: const Icon(
                Icons.skip_next_rounded,
                color: AppColors.onSurface,
                size: 32,
              ),
              tooltip: 'Next',
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
          ),
          Flexible(
            child: IconButton(
              onPressed: onRepeat,
              icon: Icon(
                Icons.repeat_rounded,
                color: repeatMode != RepeatMode.off
                    ? AppColors.secondaryContainer
                    : AppColors.onSurfaceVariant,
                size: 20,
              ),
              tooltip: 'Repeat (${repeatMode.name})',
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
