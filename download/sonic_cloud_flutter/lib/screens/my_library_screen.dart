import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart' as r;
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/album_card.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/glass_card.dart';
import '../widgets/top_app_bar.dart';
import '../widgets/track_row.dart';

/// Library screen — the app's home.
///
/// Sections:
///   1. Search field (rounded-full, glassmorphic)
///   2. Filter chips: All / Artists / Albums / Playlists
///   3. Recently Played horizontal carousel
///   4. All Songs list with one active track
class MyLibraryScreen extends StatelessWidget {
  final VoidCallback onOpenPlayer;
  final VoidCallback onOpenCloud;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenBrowse;
  final VoidCallback? onOpenEqualizer;
  /// Called when the user taps a specific track in the All Songs list.
  /// If null, falls back to [onOpenPlayer] (which plays the first track).
  final ValueChanged<Track>? onPlayTrack;

  const MyLibraryScreen({
    super.key,
    required this.onOpenPlayer,
    required this.onOpenCloud,
    required this.onOpenSettings,
    this.onOpenBrowse,
    this.onOpenEqualizer,
    this.onPlayTrack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SonicTopAppBar(
        avatarUrl: MockData.userProfile.avatarUrl,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.graphic_eq_rounded,
              color: AppColors.primary,
            ),
            tooltip: 'Equalizer',
            onPressed: onOpenEqualizer,
          ),
          IconButton(
            icon: const Icon(Icons.apps_rounded, color: AppColors.primary),
            tooltip: 'Browse library',
            onPressed: onOpenBrowse,
          ),
        ],
      ),
      body: SafeArea(
        minimum: const EdgeInsets.only(top: 16),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.edgeMargin,
            8,
            AppSpacing.edgeMargin,
            120,
          ),
          children: [
            const _SearchAndFilters(),
            const SizedBox(height: AppSpacing.lg),
            const _SectionTitle('Recently Played'),
            const SizedBox(height: AppSpacing.md),
            _RecentlyPlayedCarousel(
              onTapAlbum: (album) {
                // Play the first track from the tapped album, if any.
                final track = MockData.allSongs.firstWhere(
                  (t) => t.album == album.title,
                  orElse: () => MockData.allSongs.first,
                );
                if (onPlayTrack != null) {
                  onPlayTrack!(track);
                } else {
                  onOpenPlayer();
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _AllSongsSection(
              onTapTrack: (t) {
                if (onPlayTrack != null) {
                  onPlayTrack!(t);
                } else {
                  onOpenPlayer();
                }
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: SonicBottomNavBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) onOpenPlayer();
          if (i == 2) onOpenCloud();
          if (i == 3) onOpenSettings();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search + filter chips
// ─────────────────────────────────────────────────────────────────────────────
class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search field
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(r.AppRadius.full),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'Search your library...',
              hintStyle: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant.withOpacity(0.5),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.onSurfaceVariant,
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Filter chips
        const _FilterChips(),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips();

  static const _labels = ['All', 'Artists', 'Albums', 'Playlists'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = i == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.secondaryContainer.withOpacity(0.10)
                  : AppColors.surfaceContainer.withOpacity(0.30),
              borderRadius: BorderRadius.circular(r.AppRadius.full),
              border: Border.all(
                color: active
                    ? AppColors.secondaryContainer
                    : Colors.white.withOpacity(0.10),
              ),
            ),
            child: Center(
              child: Text(
                _labels[i],
                style: AppTypography.labelMd.copyWith(
                  color: active
                      ? AppColors.secondaryContainer
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section title + Recently Played carousel
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.headlineMd.copyWith(color: AppColors.onSurface),
    );
  }
}

class _RecentlyPlayedCarousel extends StatelessWidget {
  final ValueChanged<Album>? onTapAlbum;
  const _RecentlyPlayedCarousel({this.onTapAlbum});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: MockData.recentlyPlayed.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) => AlbumCard(
          album: MockData.recentlyPlayed[i],
          onTap: onTapAlbum != null ? () => onTapAlbum!(MockData.recentlyPlayed[i]) : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// All Songs list
// ─────────────────────────────────────────────────────────────────────────────
class _AllSongsSection extends StatelessWidget {
  final ValueChanged<Track> onTapTrack;
  const _AllSongsSection({required this.onTapTrack});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle('All Songs'),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(
                Icons.sort_rounded,
                size: 16,
                color: AppColors.secondaryContainer,
              ),
              label: Text(
                'Sort',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.secondaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // The first track is "active" (matches the HTML mockup).
        ...MockData.allSongs.asMap().entries.map(
          (e) => TrackRow(
            track: e.value,
            isActive: e.key == 0,
            onTap: () => onTapTrack(e.value),
          ),
        ),
      ],
    );
  }
}
