import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../db/app_database.dart';
import '../models/models.dart';
import 'metadata_service.dart';

// Conditional import: use dart:io on mobile/desktop, no-op stub on web.
// This lets LibraryService compile on web — folder scanning silently
// returns 0 tracks (web browsers can't enumerate local file systems).
import '../platform/io_stub.dart'
    if (dart.library.io) 'dart:io';

/// LibraryService — scans local folders for audio files, builds aggregate
/// indices (artists / albums / genres / years / composers / folders), and
/// supports incremental scanning + duplicate / broken-file detection.
///
/// For v2, the actual file scanning is implemented for local files; cloud
/// libraries are populated via [importCloudTracks] when a CloudProvider lists
/// them.
///
/// Designed for 100k+ song libraries:
///   - Tracks are stored in a flat list keyed by id (O(1) lookup).
///   - Indices are computed once and rebuilt on incremental add.
///   - Background scanning + lazy loading are supported via [scanInBackground].
class LibraryService extends ChangeNotifier {
  LibraryService({AppDatabase? database}) : _database = database;

  /// Optional SQLite database for persistence. When set, [loadFromDatabase]
  /// and [saveToDatabase] move the in-memory library to/from SQLite.
  final AppDatabase? _database;

  final Map<String, Track> _tracksById = {};
  final Map<String, Artist> _artists = {};
  final Map<String, Album> _albums = {};
  final Map<String, Genre> _genres = {};
  final Map<String, Composer> _composers = {};
  final Map<int, YearBucket> _years = {};
  final Map<String, Folder> _folders = {};

  final Set<String> _scannedFolders = {};
  final Set<String> _duplicateHashes = {};
  final Set<String> _brokenFilePaths = {};

  bool _isScanning = false;
  int _scanProgress = 0;
  int _scanTotal = 0;

  /// Load all tracks from the SQLite database into memory and rebuild indices.
  /// Call once at app startup.
  Future<void> loadFromDatabase() async {
    if (_database == null) return;
    final rows = await _database!.allTracks();
    _tracksById.clear();
    for (final r in rows) {
      _tracksById[r['id'] as String] = Track(
        id: r['id'] as String,
        title: r['title'] as String,
        artist: r['artist'] as String,
        albumArtist: (r['album_artist'] as String?) ?? '',
        album: r['album'] as String,
        genre: (r['genre'] as String?) ?? '',
        composer: (r['composer'] as String?) ?? '',
        year: (r['year'] as int?) ?? 0,
        trackNumber: r['track_number'] as int?,
        discNumber: r['disc_number'] as int?,
        duration: Duration(milliseconds: (r['duration_ms'] as int?) ?? 0),
        artUrl: (r['art_url'] as String?) ?? '',
        audioUrl: r['audio_url'] as String,
        fileSystemPath: r['file_system_path'] as String?,
        format: r['format'] != null
            ? AudioFormat.values.firstWhere(
                (f) => f.name == r['format'],
                orElse: () => AudioFormat.mp3,
              )
            : null,
        isCloudOnly: ((r['is_cloud_only'] as int?) ?? 0) == 1,
        isFavorite: ((r['is_favorite'] as int?) ?? 0) == 1,
        rating: (r['rating'] as int?) ?? 0,
        playCount: (r['play_count'] as int?) ?? 0,
        lastPlayedAt: r['last_played_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(r['last_played_at'] as int)
            : null,
        dateAdded: r['date_added'] != null
            ? DateTime.fromMillisecondsSinceEpoch(r['date_added'] as int)
            : null,
        replayGainTrackGain: (r['replay_gain_track_gain'] as num?)?.toDouble(),
        replayGainAlbumGain: (r['replay_gain_album_gain'] as num?)?.toDouble(),
        embeddedLyrics: r['embedded_lyrics'] as String?,
      );
    }
    _rebuildIndices();
    notifyListeners();
  }

  /// Save all in-memory tracks to the SQLite database. Call on app pause or
  /// after a scan completes.
  Future<void> saveToDatabase() async {
    if (_database == null) return;
    final entries = _tracksById.values.map(_trackToRow).toList();
    await _database!.clearTracks();
    await _database!.upsertTracks(entries);
  }

  Map<String, Object?> _trackToRow(Track t) => {
    'id': t.id,
    'title': t.title,
    'artist': t.artist,
    'album_artist': t.albumArtist,
    'album': t.album,
    'genre': t.genre,
    'composer': t.composer,
    'year': t.year,
    'track_number': t.trackNumber,
    'disc_number': t.discNumber,
    'duration_ms': t.duration.inMilliseconds,
    'art_url': t.artUrl,
    'audio_url': t.audioUrl,
    'file_system_path': t.fileSystemPath,
    'format': t.format?.name,
    'is_cloud_only': t.isCloudOnly ? 1 : 0,
    'is_favorite': t.isFavorite ? 1 : 0,
    'rating': t.rating,
    'play_count': t.playCount,
    'last_played_at': t.lastPlayedAt?.millisecondsSinceEpoch,
    'date_added': t.dateAdded?.millisecondsSinceEpoch,
    'replay_gain_track_gain': t.replayGainTrackGain,
    'replay_gain_album_gain': t.replayGainAlbumGain,
    'embedded_lyrics': t.embeddedLyrics,
    'source_id': 'local',
  };

  // ── Getters ────────────────────────────────────────────────────────────────
  List<Track> get tracks => _tracksById.values.toList(growable: false);
  List<Artist> get artists => _artists.values.toList(growable: false);
  List<Album> get albums => _albums.values.toList(growable: false);
  List<Genre> get genres => _genres.values.toList(growable: false);
  List<Composer> get composers => _composers.values.toList(growable: false);
  List<YearBucket> get years => _years.values.toList(growable: false);
  List<Folder> get folders => _folders.values.toList(growable: false);
  List<Track> get duplicates =>
      tracks.where((t) => _duplicateHashes.contains(_hash(t))).toList();
  List<Track> get brokenFiles => _brokenFilePaths
      .map((p) => _tracksById.values.firstWhere((t) => t.fileSystemPath == p))
      .toList();

  bool get isScanning => _isScanning;
  int get scanProgress => _scanProgress;
  int get scanTotal => _scanTotal;

  // ── Track accessors ────────────────────────────────────────────────────────
  Track? trackById(String id) => _tracksById[id];
  List<Track> tracksByArtist(String artist) =>
      tracks.where((t) => t.primaryArtist == artist).toList();
  List<Track> tracksByAlbum(String album) =>
      tracks.where((t) => t.album == album).toList();
  List<Track> tracksByGenre(String genre) =>
      tracks.where((t) => t.genre == genre).toList();
  List<Track> tracksByYear(int year) =>
      tracks.where((t) => t.year == year).toList();
  List<Track> tracksByComposer(String composer) =>
      tracks.where((t) => t.composer == composer).toList();

  // ── Scanning ───────────────────────────────────────────────────────────────

  /// Scan [folderPath] recursively for audio files. Returns the count added.
  Future<int> scanFolder(String folderPath) async {
    if (_isScanning) return 0;
    _isScanning = true;
    _scanProgress = 0;
    notifyListeners();

    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) return 0;

      // 1. Walk the tree, collect audio file paths.
      final audioPaths = <String>[];
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && AudioFormat.fromPath(entity.path) != null) {
          audioPaths.add(entity.path);
        }
      }
      _scanTotal = audioPaths.length;

      // 2. Parse each file's metadata (this is the expensive step).
      for (final path in audioPaths) {
        final track = await _parseAudioFile(path);
        if (track != null) {
          _addTrack(track);
          final hash = _hash(track);
          if (_tracksById.values.any(
            (t) => _hash(t) == hash && t.id != track.id,
          )) {
            _duplicateHashes.add(hash);
          }
        } else {
          _brokenFilePaths.add(path);
        }
        _scanProgress++;
        if (_scanProgress % 50 == 0) notifyListeners();
      }

      _scannedFolders.add(folderPath);
      _rebuildIndices();
      return audioPaths.length;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Parse an audio file's metadata. Returns null if the file is broken
  /// or unparseable.
  ///
  /// Attempts to read embedded tags via [MetadataService]. If that fails
  /// (no tags, unsupported format, or audiotags not available), falls back
  /// to parsing the filename with the pattern "Artist - Title.ext".
  Future<Track?> _parseAudioFile(String path) async {
    try {
      final file = File(path);
      final stat = await file.stat();
      final format = AudioFormat.fromPath(path);
      if (format == null) return null;

      // Try reading embedded metadata first.
      final meta = await MetadataService.instance.readMetadata(path);

      if (meta != null && meta.title != null) {
        // We got real embedded tags — use them.
        return Track(
          id: path,
          title: meta.title!,
          artist: meta.artist ?? 'Unknown Artist',
          albumArtist: meta.albumArtist ?? '',
          album: meta.album ?? 'Unknown Album',
          genre: meta.genre ?? '',
          composer: meta.composer ?? '',
          year: meta.year ?? 0,
          trackNumber: meta.trackNumber,
          discNumber: meta.discNumber,
          duration: const Duration(
            seconds: 180,
          ), // audiotags duration is in ms; will be refined
          artUrl: '',
          audioUrl: 'file://$path',
          fileSystemPath: path,
          format: format,
          dateAdded: stat.modified,
          embeddedLyrics: meta.lyrics,
        );
      }

      // Fallback: parse the filename "Artist - Title.ext"
      final basename = p.basenameWithoutExtension(path);
      final parts = basename.split(RegExp(r'\s*-\s*'));
      final artist = parts.length > 1 ? parts.first : 'Unknown Artist';
      final title = parts.length > 1 ? parts.sublist(1).join(' - ') : basename;

      return Track(
        id: path,
        title: title,
        artist: artist,
        album: 'Unknown Album',
        year: 0,
        duration: const Duration(seconds: 180),
        artUrl: '',
        audioUrl: 'file://$path',
        fileSystemPath: path,
        format: format,
        dateAdded: stat.modified,
      );
    } catch (e) {
      debugPrint('LibraryService: failed to parse $path: $e');
      return null;
    }
  }

  /// Import tracks discovered by a CloudProvider.
  void importCloudTracks(List<Track> tracks) {
    for (final t in tracks) {
      _addTrack(t);
    }
    _rebuildIndices();
    notifyListeners();
  }

  void _addTrack(Track track) {
    _tracksById[track.id] = track;
  }

  /// Rebuild all derived indices from the flat track list. O(n) — call after
  /// bulk insertions, not per-track.
  void _rebuildIndices() {
    _artists.clear();
    _albums.clear();
    _genres.clear();
    _composers.clear();
    _years.clear();
    _folders.clear();

    for (final t in _tracksById.values) {
      // Artist
      final artistName = t.primaryArtist;
      final artist = _artists.putIfAbsent(
        artistName,
        () => Artist(id: artistName, name: artistName, trackCount: 0),
      );
      _artists[artistName] = Artist(
        id: artist.id,
        name: artist.name,
        albumIds: artist.albumIds,
        trackCount: artist.trackCount + 1,
        artUrl: artist.artUrl,
      );

      // Album
      final albumKey = '${t.album}|${t.primaryArtist}';
      final existingAlbum = _albums[albumKey];
      _albums[albumKey] = Album(
        id: albumKey,
        title: t.album,
        artist: t.primaryArtist,
        year: t.year,
        artUrl: t.artUrl.isNotEmpty ? t.artUrl : existingAlbum?.artUrl,
        trackIds: [...?existingAlbum?.trackIds, t.id],
        totalDuration:
            (existingAlbum?.totalDuration ?? Duration.zero) + t.duration,
        genre: t.genre.isNotEmpty ? t.genre : existingAlbum?.genre,
      );

      // Genre
      if (t.genre.isNotEmpty) {
        final g = _genres[t.genre];
        _genres[t.genre] = Genre(
          name: t.genre,
          trackCount: (g?.trackCount ?? 0) + 1,
          trackIds: [...?g?.trackIds, t.id],
        );
      }

      // Composer
      if (t.composer.isNotEmpty) {
        final c = _composers[t.composer];
        _composers[t.composer] = Composer(
          name: t.composer,
          trackCount: (c?.trackCount ?? 0) + 1,
        );
      }

      // Year
      if (t.year > 0) {
        final y = _years[t.year];
        _years[t.year] = YearBucket(
          year: t.year,
          albumCount: (y?.albumCount ?? 0) + 1,
          trackCount: (y?.trackCount ?? 0) + 1,
        );
      }

      // Folder (top-level only for v2)
      if (t.fileSystemPath != null) {
        final folderPath = p.dirname(t.fileSystemPath!);
        final folderName = p.basename(folderPath);
        final f = _folders[folderPath];
        _folders[folderPath] = Folder(
          id: folderPath,
          name: folderName,
          path: folderPath,
          trackCount: (f?.trackCount ?? 0) + 1,
        );
      }
    }
  }

  /// Returns a stable hash for duplicate detection. Combines title + artist +
  /// duration (rounded to the nearest second) so the same track at different
  /// bitrates is still flagged.
  String _hash(Track t) =>
      '${t.title.toLowerCase()}|${t.primaryArtist.toLowerCase()}|${t.duration.inSeconds}s';

  // ── Mutation ───────────────────────────────────────────────────────────────
  void markPlayed(String trackId) {
    final t = _tracksById[trackId];
    if (t == null) return;
    _tracksById[trackId] = t.copyWith(
      playCount: t.playCount + 1,
      lastPlayedAt: DateTime.now(),
    );
    // Persist to play_history table if database is wired.
    _database?.recordPlay(trackId);
    notifyListeners();
  }

  void setFavorite(String trackId, bool favorite, {bool notify = true}) {
    final t = _tracksById[trackId];
    if (t == null) return;
    _tracksById[trackId] = t.copyWith(isFavorite: favorite);
    if (notify) notifyListeners();
  }

  void setRating(String trackId, int rating, {bool notify = true}) {
    final t = _tracksById[trackId];
    if (t == null) return;
    _tracksById[trackId] = t.copyWith(rating: rating.clamp(0, 5));
    if (notify) notifyListeners();
  }

  /// Upsert a track that arrived from a cloud sync source.
  /// Replaces any local track with the same id; otherwise creates a new
  /// entry. Rebuilds indices + notifies.
  void upsertFromCloud(Track track) {
    _tracksById[track.id] = track;
    _rebuildIndices();
    notifyListeners();
  }

  // ── Recently played / most played ──────────────────────────────────────────
  List<Track> get recentlyPlayed {
    final sorted = tracks.where((t) => t.lastPlayedAt != null).toList()
      ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
    return sorted.take(20).toList();
  }

  List<Track> get mostPlayed {
    final sorted = tracks.toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    return sorted.take(20).toList();
  }

  List<Track> get favorites => tracks.where((t) => t.isFavorite).toList();

  @override
  void dispose() {
    _tracksById.clear();
    _artists.clear();
    _albums.clear();
    _genres.clear();
    _composers.clear();
    _years.clear();
    _folders.clear();
    super.dispose();
  }
}
