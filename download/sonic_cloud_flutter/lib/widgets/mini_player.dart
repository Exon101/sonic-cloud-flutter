import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/playback_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart' as r;
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// MiniPlayer — a persistent mini-player bar shown at the bottom of the
/// screen (above the bottom nav) when a track is loaded.
///
/// Shows: album art thumbnail, track title + artist, play/pause button,
/// and a thin progress bar. Tapping the bar opens the full Now Playing
/// screen.
class MiniPlayer extends StatelessWidget {
  final PlaybackService playback;
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.playback, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final track = playback.currentTrack;
        if (track == null) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 4),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.edgeMargin,
                0,
                AppSpacing.edgeMargin,
                0,
              ),
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.sizeOf(context).width -
                    AppSpacing.edgeMargin * 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer.withOpacity(0.95),
                borderRadius: BorderRadius.circular(r.AppRadius.lg),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(r.AppRadius.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress bar (thin, at the top)
                    LinearProgressIndicator(
                      value: playback.progress,
                      minHeight: 2,
                      backgroundColor: AppColors.surfaceContainerHighest,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.secondaryContainer,
                      ),
                    ),
                    // Main content
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // Album art thumbnail
                          _AlbumThumbnail(track: track),
                          const SizedBox(width: 12),
                          // Title + artist
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  track.title,
                                  style: AppTypography.labelMd.copyWith(
                                    color: AppColors.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  track.artist,
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Play/pause button
                          IconButton(
                            onPressed: () => playback.togglePlayPause(),
                            icon: Icon(
                              playback.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppColors.secondaryContainer,
                              size: 28,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                          ),
                          // Next button
                          IconButton(
                            onPressed: () => playback.skipToNext(),
                            icon: const Icon(
                              Icons.skip_next_rounded,
                              color: AppColors.onSurfaceVariant,
                              size: 24,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AlbumThumbnail extends StatelessWidget {
  final Track track;
  const _AlbumThumbnail({required this.track});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r.AppRadius.def),
        color: AppColors.surfaceContainerHigh,
        image: track.artUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(track.artUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: track.artUrl.isEmpty
          ? const Icon(
              Icons.music_note_rounded,
              color: AppColors.onSurfaceVariant,
              size: 24,
            )
          : null,
    );
  }
}
