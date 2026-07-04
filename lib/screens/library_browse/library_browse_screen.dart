import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/library_service.dart';
import '../../services/universal_library_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart' as r;
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/glass_card.dart';

/// Library Browse screen — multi-tab browser for the universal library.
///
/// Tabs:
///   - Sources     — tree view of all connected sources (Phone / NAS / Cloud)
///   - Artists     — alphabetical grid
///   - Albums      — grid of album cards
///   - Genres      — list
///   - Years       — list grouped by decade
///   - Composers   — list
///   - Folders     — filesystem tree view
class LibraryBrowseScreen extends StatefulWidget {
  final LibraryService library;
  final UniversalLibraryService universalLibrary;
  final void Function(Track track) onPlayTrack;

  const LibraryBrowseScreen({
    super.key,
    required this.library,
    required this.universalLibrary,
    required this.onPlayTrack,
  });

  @override
  State<LibraryBrowseScreen> createState() => _LibraryBrowseScreenState();
}

class _LibraryBrowseScreenState extends State<LibraryBrowseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  static const _tabs = [
    Tab(icon: Icon(Icons.cloud_queue_rounded), text: 'Sources'),
    Tab(icon: Icon(Icons.person_rounded), text: 'Artists'),
    Tab(icon: Icon(Icons.album_rounded), text: 'Albums'),
    Tab(icon: Icon(Icons.music_note_rounded), text: 'Genres'),
    Tab(icon: Icon(Icons.calendar_today_rounded), text: 'Years'),
    Tab(icon: Icon(Icons.edit_rounded), text: 'Composers'),
    Tab(icon: Icon(Icons.folder_rounded), text: 'Folders'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Library'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: _tabs,
          labelColor: AppColors.secondaryContainer,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          indicatorColor: AppColors.secondaryContainer,
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([widget.library, widget.universalLibrary]),
        builder: (context, _) {
          return TabBarView(
            controller: _tabCtrl,
            children: [
              _SourcesTab(
                universal: widget.universalLibrary,
                onPlayTrack: widget.onPlayTrack,
              ),
              _ArtistsTab(
                library: widget.library,
                onPlayTrack: widget.onPlayTrack,
              ),
              _AlbumsTab(
                library: widget.library,
                onPlayTrack: widget.onPlayTrack,
              ),
              _GenresTab(
                library: widget.library,
                onPlayTrack: widget.onPlayTrack,
              ),
              _YearsTab(
                library: widget.library,
                onPlayTrack: widget.onPlayTrack,
              ),
              _ComposersTab(
                library: widget.library,
                onPlayTrack: widget.onPlayTrack,
              ),
              _FoldersTab(
                library: widget.library,
                onPlayTrack: widget.onPlayTrack,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sources tab — universal library tree view
// ─────────────────────────────────────────────────────────────────────────────
class _SourcesTab extends StatelessWidget {
  final UniversalLibraryService universal;
  final void Function(Track) onPlayTrack;
  const _SourcesTab({required this.universal, required this.onPlayTrack});

  @override
  Widget build(BuildContext context) {
    final counts = universal.trackCountBySource;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.edgeMargin),
      children: [
        Text(
          'All Songs',
          style: AppTypography.headlineLg.copyWith(color: AppColors.onSurface),
        ),
        Text(
          '${universal.allTracks.length} tracks across ${counts.length} sources',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...counts.entries.map(
          (e) => _SourceTile(
            label: universal.sourceLabel(e.key),
            trackCount: e.value,
            onTap: () => _showSourceTracks(context, e.key),
          ),
        ),
      ],
    );
  }

  void _showSourceTracks(BuildContext context, String sourceId) {
    final tracks = universal.tracksForSource(sourceId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TrackListScreen(
          title: universal.sourceLabel(sourceId),
          tracks: tracks,
          onPlayTrack: onPlayTrack,
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String label;
  final int trackCount;
  final VoidCallback onTap;
  const _SourceTile({
    required this.label,
    required this.trackCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: onTap,
        child: Row(
          children: [
            const Icon(
              Icons.source_rounded,
              color: AppColors.secondaryContainer,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
            Text(
              '$trackCount',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Artists tab
// ─────────────────────────────────────────────────────────────────────────────
class _ArtistsTab extends StatelessWidget {
  final LibraryService library;
  final void Function(Track) onPlayTrack;
  const _ArtistsTab({required this.library, required this.onPlayTrack});

  @override
  Widget build(BuildContext context) {
    final artists = library.artists
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.edgeMargin),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: artists.length,
      itemBuilder: (context, i) {
        final a = artists[i];
        return _ArtistCard(
          artist: a,
          onTap: () => _showArtistTracks(context, a),
        );
      },
    );
  }

  void _showArtistTracks(BuildContext context, Artist artist) {
    final tracks = library.tracksByArtist(artist.name);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TrackListScreen(
          title: artist.name,
          tracks: tracks,
          onPlayTrack: onPlayTrack,
        ),
      ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final Artist artist;
  final VoidCallback onTap;
  const _ArtistCard({required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainer,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              image: artist.artUrl != null
                  ? DecorationImage(
                      image: NetworkImage(artist.artUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: artist.artUrl == null
                ? const Icon(
                    Icons.person_rounded,
                    size: 48,
                    color: AppColors.onSurfaceVariant,
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            artist.name,
            style: AppTypography.labelMd.copyWith(color: AppColors.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${artist.trackCount} tracks',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Albums tab
// ─────────────────────────────────────────────────────────────────────────────
class _AlbumsTab extends StatelessWidget {
  final LibraryService library;
  final void Function(Track) onPlayTrack;
  const _AlbumsTab({required this.library, required this.onPlayTrack});

  @override
  Widget build(BuildContext context) {
    final albums = library.albums
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.edgeMargin),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: albums.length,
      itemBuilder: (context, i) => _AlbumCard(
        album: albums[i],
        onTap: () => _showAlbumTracks(context, albums[i]),
      ),
    );
  }

  void _showAlbumTracks(BuildContext context, Album album) {
    final tracks = library.tracksByAlbum(album.title);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TrackListScreen(
          title: '${album.title} — ${album.artist}',
          tracks: tracks,
          onPlayTrack: onPlayTrack,
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;
  const _AlbumCard({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(r.AppRadius.lg),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.2)),
                  left: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                image: album.artUrl != null
                    ? DecorationImage(
                        image: NetworkImage(album.artUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: album.artUrl == null
                  ? const Icon(
                      Icons.album_rounded,
                      size: 48,
                      color: AppColors.onSurfaceVariant,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.title,
            style: AppTypography.labelMd.copyWith(color: AppColors.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            album.artist,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Genres / Years / Composers / Folders — simple lists
// ─────────────────────────────────────────────────────────────────────────────
class _GenresTab extends StatelessWidget {
  final LibraryService library;
  final void Function(Track) onPlayTrack;
  const _GenresTab({required this.library, required this.onPlayTrack});

  @override
  Widget build(BuildContext context) {
    final genres = library.genres
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.edgeMargin),
      itemCount: genres.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, i) {
        final g = genres[i];
        return ListTile(
          leading: const Icon(
            Icons.music_note_rounded,
            color: AppColors.secondaryContainer,
          ),
          title: Text(
            g.name,
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
          ),
          subtitle: Text(
            '${g.trackCount} tracks',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          onTap: () => _showGenreTracks(context, g),
        );
      },
    );
  }

  void _showGenreTracks(BuildContext context, Genre g) {
    final tracks = library.tracksByGenre(g.name);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TrackListScreen(
          title: g.name,
          tracks: tracks,
          onPlayTrack: onPlayTrack,
        ),
      ),
    );
  }
}

class _YearsTab extends StatelessWidget {
  final LibraryService library;
  final void Function(Track) onPlayTrack;
  const _YearsTab({required this.library, required this.onPlayTrack});

  @override
  Widget build(BuildContext context) {
    final years = library.years.toList()
      ..sort((a, b) => b.year.compareTo(a.year));
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.edgeMargin),
      itemCount: years.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, i) {
        final y = years[i];
        return ListTile(
          leading: const Icon(
            Icons.calendar_today_rounded,
            color: AppColors.secondaryContainer,
          ),
          title: Text(
            y.year.toString(),
            style: AppTypography.headlineMd.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          subtitle: Text(
            '${y.albumCount} albums · ${y.trackCount} tracks',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          onTap: () => _showYearTracks(context, y),
        );
      },
    );
  }

  void _showYearTracks(BuildContext context, YearBucket y) {
    final tracks = library.tracksByYear(y.year);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TrackListScreen(
          title: y.year.toString(),
          tracks: tracks,
          onPlayTrack: onPlayTrack,
        ),
      ),
    );
  }
}

class _ComposersTab extends StatelessWidget {
  final LibraryService library;
  final void Function(Track) onPlayTrack;
  const _ComposersTab({required this.library, required this.onPlayTrack});

  @override
  Widget build(BuildContext context) {
    final composers = library.composers.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.edgeMargin),
      itemCount: composers.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, i) {
        final c = composers[i];
        return ListTile(
          leading: const Icon(
            Icons.edit_rounded,
            color: AppColors.secondaryContainer,
          ),
          title: Text(
            c.name,
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
          ),
          subtitle: Text(
            '${c.trackCount} tracks',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          onTap: () => _showComposerTracks(context, c),
        );
      },
    );
  }

  void _showComposerTracks(BuildContext context, Composer c) {
    final tracks = library.tracksByComposer(c.name);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TrackListScreen(
          title: c.name,
          tracks: tracks,
          onPlayTrack: onPlayTrack,
        ),
      ),
    );
  }
}

class _FoldersTab extends StatelessWidget {
  final LibraryService library;
  final void Function(Track) onPlayTrack;
  const _FoldersTab({required this.library, required this.onPlayTrack});

  @override
  Widget build(BuildContext context) {
    final folders = library.folders
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.edgeMargin),
      itemCount: folders.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, i) {
        final f = folders[i];
        return ListTile(
          leading: const Icon(
            Icons.folder_rounded,
            color: AppColors.secondaryContainer,
          ),
          title: Text(
            f.name,
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
          ),
          subtitle: Text(
            '${f.trackCount} tracks · ${f.path}',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _showFolderTracks(context, f),
        );
      },
    );
  }

  void _showFolderTracks(BuildContext context, Folder f) {
    final tracks = library.tracks
        .where((t) => t.fileSystemPath?.startsWith(f.path) ?? false)
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TrackListScreen(
          title: f.name,
          tracks: tracks,
          onPlayTrack: onPlayTrack,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic track list screen (pushed when you tap an artist/album/genre/...)
// ─────────────────────────────────────────────────────────────────────────────
class _TrackListScreen extends StatelessWidget {
  final String title;
  final List<Track> tracks;
  final void Function(Track) onPlayTrack;

  const _TrackListScreen({
    required this.title,
    required this.tracks,
    required this.onPlayTrack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.edgeMargin),
        itemCount: tracks.length,
        itemBuilder: (context, i) {
          final t = tracks[i];
          return ListTile(
            leading: t.artUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(r.AppRadius.def),
                    child: Image.network(
                      t.artUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(r.AppRadius.def),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
            title: Text(
              t.title,
              style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
            ),
            subtitle: Text(
              '${t.artist} · ${t.formattedDuration}',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            onTap: () => onPlayTrack(t),
          );
        },
      ),
    );
  }
}
