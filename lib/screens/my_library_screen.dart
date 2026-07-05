import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/library_service.dart';
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
/// v3.3: supports playing local files via file picker + folder scanning.
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
  bool _scanning = false;

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
    widget.search.index(widget.library.tracks);
  }

  /// Pick one or more audio files from the device and play them.
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      final tracks = <Track>[];
      for (final file in result.files) {
        final path = file.path;
        if (path == null) continue;
        final format = AudioFormat.fromPath(path);
        if (format == null) continue;

        // Build a Track from the file
        final baseName = path
            .split('/')
            .last
            .replaceAll(RegExp(r'\.[^.]+$'), '');
        final parts = baseName.split(RegExp(r'\s*-\s*'));
        tracks.add(
          Track(
            id: 'local:$path',
            title: parts.length > 1 ? parts.sublist(1).join(' - ') : baseName,
            artist: parts.length > 1 ? parts.first : 'Unknown Artist',
            album: 'Local Files',
            year: 0,
            duration: Duration.zero,
            artUrl: '',
            audioUrl: 'file://$path',
            fileSystemPath: path,
            format: format,
            dateAdded: DateTime.now(),
          ),
        );
      }

      if (tracks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No supported audio files selected.')),
          );
        }
        return;
      }

      // Add to library + play
      widget.library.importCloudTracks(tracks);
      await widget.library.saveToDatabase();
      widget.search.index(widget.library.tracks);
      widget.onPlayTrack(tracks.first);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playing ${tracks.length} file(s)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick files: $e')));
      }
    }
  }

  /// Pick a folder and scan it for audio files.
  Future<void> _scanFolder() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null) return;

      setState(() => _scanning = true);

      // Scan the folder — LibraryService.walks the tree and parses metadata
      final count = await widget.library.scanFolder(path);
      await widget.library.saveToDatabase();
      widget.search.index(widget.library.tracks);

      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'Scanned $count audio file(s) from folder'
                  : 'No audio files found in selected folder',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to scan folder: $e')));
      }
    }
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(r.AppRadius.xl),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(
                Icons.audio_file_rounded,
                color: AppColors.secondaryContainer,
                size: 28,
              ),
              title: Text(
                'Open Audio Files',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              subtitle: Text(
                'Pick one or more audio files to play',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickFiles();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.folder_open_rounded,
                color: AppColors.secondaryContainer,
                size: 28,
              ),
              title: Text(
                'Scan Folder',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              subtitle: Text(
                'Scan a folder for all audio files',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _scanFolder();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanning ? null : _showAddMenu,
        backgroundColor: AppColors.secondaryContainer,
        foregroundColor: AppColors.surfaceLowest,
        icon: _scanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.surfaceLowest,
                ),
              )
            : const Icon(Icons.add_rounded),
        label: Text(_scanning ? 'Scanning...' : 'Add Music'),
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
            child: Column(
              children: [
                const Icon(
                  Icons.library_music_rounded,
                  size: 48,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'No tracks in library.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Tap "Add Music" to pick files or scan a folder.',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
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
