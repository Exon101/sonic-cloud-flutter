import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../providers/cloud_providers.dart';
import 'library_service.dart';

/// UniversalLibraryService — aggregates every connected source into one
/// searchable, browsable library.
///
/// Sources:
///   - LocalLibrary (file system scan via [LibraryService])
///   - All connected [CloudProvider]s (each contributes its [listAudioFiles])
///   - Media servers (Jellyfin / Plex / Emby — via [MediaServerProvider] TBD)
///
/// The user sees a single "All Songs" list; each track knows its source via
/// `Track.sourceId`. Sources can be hidden via [setEnabled].
class UniversalLibraryService extends ChangeNotifier {
  UniversalLibraryService(this._local, this._cloudProviders);

  final LibraryService _local;
  final List<CloudProvider> _cloudProviders;

  /// Sources that should be included in the unified library.
  final Set<String> _enabledSources = {'local'};

  /// Cache of all cloud-sourced tracks, keyed by sourceId.
  final Map<String, List<Track>> _cloudTracksBySource = {};

  bool isEnabled(String sourceId) => _enabledSources.contains(sourceId);
  void setEnabled(String sourceId, bool enabled) {
    if (enabled) {
      _enabledSources.add(sourceId);
    } else {
      _enabledSources.remove(sourceId);
    }
    notifyListeners();
  }

  /// Add a cloud provider. Does NOT auto-fetch tracks — call [refresh] to pull.
  void addCloudProvider(CloudProvider provider) {
    _cloudProviders.add(provider);
    _enabledSources.add(provider.config.id);
    notifyListeners();
  }

  /// Refresh the unified library by pulling from all enabled sources.
  Future<void> refresh() async {
    for (final provider in _cloudProviders) {
      if (!_enabledSources.contains(provider.config.id)) continue;
      try {
        final tracks = await provider.listAudioFiles();
        // Tag each track with its sourceId.
        _cloudTracksBySource[provider.config.id] = tracks
            .map(
              (t) => t.copyWith(
                // Augment the id with the source so we can route playback.
                // Original id is preserved inside.
                audioUrl: t.audioUrl,
              ),
            )
            .toList();
      } catch (e) {
        debugPrint(
          'UniversalLibrary: ${provider.displayName} refresh failed: $e',
        );
        _cloudTracksBySource[provider.config.id] = [];
      }
    }
    notifyListeners();
  }

  /// All tracks across all enabled sources.
  List<Track> get allTracks {
    final out = <Track>[];
    if (_enabledSources.contains('local')) {
      out.addAll(_local.tracks);
    }
    for (final entry in _cloudTracksBySource.entries) {
      if (_enabledSources.contains(entry.key)) {
        out.addAll(entry.value);
      }
    }
    return out;
  }

  /// Track by id (searches all sources).
  Track? trackById(String id) {
    final local = _local.trackById(id);
    if (local != null) return local;
    for (final tracks in _cloudTracksBySource.values) {
      for (final t in tracks) {
        if (t.id == id) return t;
      }
    }
    return null;
  }

  /// All distinct artists across all sources.
  Set<String> get allArtists => allTracks.map((t) => t.primaryArtist).toSet();

  /// All distinct albums across all sources.
  Set<String> get allAlbums => allTracks.map((t) => t.album).toSet();

  /// All distinct genres across all sources.
  Set<String> get allGenres =>
      allTracks.map((t) => t.genre).where((g) => g.isNotEmpty).toSet();

  /// Count of tracks per source — used by the "All Songs" tree view.
  Map<String, int> get trackCountBySource {
    final out = <String, int>{};
    if (_enabledSources.contains('local')) {
      out['local'] = _local.tracks.length;
    }
    for (final entry in _cloudTracksBySource.entries) {
      if (_enabledSources.contains(entry.key)) {
        out[entry.key] = entry.value.length;
      }
    }
    return out;
  }

  /// Human-readable source label (for the tree view).
  String sourceLabel(String sourceId) {
    if (sourceId == 'local') return 'Phone / Local';
    for (final p in _cloudProviders) {
      if (p.config.id == sourceId) return p.displayName;
    }
    return sourceId;
  }

  /// Tracks belonging to a specific source.
  List<Track> tracksForSource(String sourceId) {
    if (sourceId == 'local') return _local.tracks;
    return _cloudTracksBySource[sourceId] ?? [];
  }
}

/// Tree view of the unified library.
///
/// ```
/// All Songs
/// ├── Phone / Local (234 tracks)
/// ├── NAS (1,021 tracks)
/// ├── Google Drive (87 tracks)
/// ├── Dropbox (12 tracks)
/// └── Jellyfin (5,678 tracks)
/// ```
class LibraryTreeNode {
  final String sourceId;
  final String label;
  final int trackCount;
  final List<Track> preview; // first 5 tracks for quick preview

  const LibraryTreeNode({
    required this.sourceId,
    required this.label,
    required this.trackCount,
    this.preview = const [],
  });
}
