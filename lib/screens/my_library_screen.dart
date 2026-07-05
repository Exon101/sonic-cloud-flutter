import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/library_service.dart';
import '../services/playback_service.dart';
import '../services/search_service.dart';
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
/// v3.2: wired to LibraryService + SearchService for real data + instant search.
class MyLibraryScreen extends StatefulWidget {
  final VoidCallback onOpenPlayer;
  final VoidCallback onOpenCloud;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenBrowse;
  final VoidCallback? onOpenEqualizer;
  final LibraryService library;
  final SearchService search;
  final void Function(Track) onPlayTrack;

  const MyLibraryScreen({
    super.key,
    required this.onOpenPlayer,
    required this.onOpenCloud,
    required this.onOpenSettings,
    this.onOpenBrowse,
    this.onOpenEqualizer,
    required this.library,
    required this.search,
    required this.onPlayTrack,
  });

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  String _searchQuery = '';
  List<Track> _searchResults = [];

  void _runSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _searchResults = [];
      } else {
        final results = widget.search.search(query);
        _searchResults = results.tracks;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Index the library on first load
    widget.search.index(widget.library.tracks);
  }

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
            onPressed: widget.onOpenEqualizer,
          ),
          IconButton(
            icon: const Icon(Icons.apps_rounded, color: AppColors.primary),
            tooltip: 'Browse library',
            onPressed: widget.onOpenBrowse,
          ),
        ],
      ),
      body: SafeArea(
        minimum: const EdgeInsets.only(top: 16),
        child: AnimatedBuilder(
          animation: widget.library,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.edgeMargin,
                8,
                AppSpacing.edgeMargin,
                120,
              ),
              children: [
                _SearchField(onChanged: _runSearch),
                const SizedBox(height: AppSpacing.sm),
                if (_searchQuery.isNotEmpty) ...[
                  _SearchResults(
                    results: _searchResults,
                    onTapTrack: widget.onPlayTrack,
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle('Recently Played'),
                  const SizedBox(height: AppSpacing.md),
                  _RecentlyPlayedCarousel(
                    tracks: widget.library.recentlyPlayed,
                    onTapTrack: widget.onPlayTrack,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _AllSongsSection(
                    tracks: widget.library.tracks,
                    onTapTrack: widget.onPlayTrack,
                  ),
                ],
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SonicBottomNavBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) widget.onOpenPlayer();
          if (i == 2) widget.onOpenCloud();
          if (i == 3) widget.onOpenSettings();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search
// ─────────────────────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(r.AppRadius.full),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        onChanged: onChanged,
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
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<Track> results;
  final void Function(Track) onTapTrack;
  const _SearchResults({required this.results, required this.onTapTrack});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'No results found.',
          style: AppTypography.bodyLg.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${results.length} results',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...results.map((t) => TrackRow(track: t, onTap: () => onTapTrack(t))),
      ],
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
  final List<Track> tracks;
  final void Function(Track) onTapTrack;
  const _RecentlyPlayedCarousel({
    required this.tracks,
    required this.onTapTrack,
  });

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'No recently played tracks.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    // Convert tracks to albums for the carousel
    final albums = <Album>[];
    final seenAlbums = <String>{};
    for (final t in tracks) {
      final key = '${t.album}|${t.primaryArtist}';
      if (seenAlbums.add(key)) {
        albums.add(
          Album(
            id: key,
            title: t.album,
            artist: t.primaryArtist,
            year: t.year,
            artUrl: t.artUrl.isNotEmpty ? t.artUrl : null,
          ),
        );
      }
    }
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: albums.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) => AlbumCard(album: albums[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// All Songs list
// ─────────────────────────────────────────────────────────────────────────────
class _AllSongsSection extends StatelessWidget {
  final List<Track> tracks;
  final void Function(Track) onTapTrack;
  const _AllSongsSection({required this.tracks, required this.onTapTrack});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'All Songs (${tracks.length})',
              style: AppTypography.headlineMd.copyWith(
                color: AppColors.onSurface,
              ),
            ),
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
        if (tracks.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'No tracks in library. Scan a folder to add music.',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          )
        else
          ...tracks.asMap().entries.map(
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
