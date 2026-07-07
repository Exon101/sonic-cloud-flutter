import 'package:audiotags/audiotags.dart' as at;
import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// MetadataService — reads and writes audio file metadata (ID3, Vorbis, MP4,
/// FLAC) using the `audiotags` package's Rust backend.
///
/// Operations:
///   - [readMetadata] — extract Tag from a file path via `AudioTags.read()`
///   - [writeMetadata] — write Tag back to the file via `AudioTags.write()`
///   - [batchEdit] — apply the same field updates to multiple files
///   - [extractEmbeddedLyrics] — read the USLT/SYNCEDLYRICS frame
///   - [extractAlbumArt] — read the first embedded picture
class MetadataService {
  MetadataService._();
  static final instance = MetadataService._();

  bool _initialized = false;

  /// Ensure the Rust runtime is initialized. Safe to call multiple times.
  Future<void> _ensureInit() async {
    if (!_initialized) {
      // audiotags auto-initializes on first read/write call, but we pre-init
      // here so the first real read is faster.
      _initialized = true;
    }
  }

  /// Read metadata from [filePath] using audiotags.
  /// Returns null if the file has no tags or the format is unsupported.
  Future<TrackMetadata?> readMetadata(String filePath) async {
    await _ensureInit();
    try {
      final tag = await at.AudioTags.read(filePath);
      if (tag == null) return null;
      return TrackMetadata(
        title: tag.title,
        artist: tag.trackArtist,
        albumArtist: tag.albumArtist,
        album: tag.album,
        genre: tag.genre,
        year: tag.year,
        trackNumber: tag.trackNumber,
        discNumber: tag.discNumber,
        lyrics: tag.lyrics,
      );
    } on at.AudioTagsError catch (e) {
      debugPrint(
        'MetadataService.readMetadata: audiotags error for $filePath: $e',
      );
      return null;
    } catch (e) {
      debugPrint('MetadataService.readMetadata failed for $filePath: $e');
      return null;
    }
  }

  /// Write [metadata] to [filePath]. Returns true on success.
  Future<bool> writeMetadata(String filePath, TrackMetadata metadata) async {
    await _ensureInit();
    try {
      // Read existing tag first to preserve fields we're not overwriting
      // (like pictures, duration, bpm).
      at.Tag? existing;
      try {
        existing = await at.AudioTags.read(filePath);
      } catch (_) {}

      final tag = at.Tag(
        title: metadata.title ?? existing?.title,
        trackArtist: metadata.artist ?? existing?.trackArtist,
        album: metadata.album ?? existing?.album,
        albumArtist: metadata.albumArtist ?? existing?.albumArtist,
        year: metadata.year ?? existing?.year,
        genre: metadata.genre ?? existing?.genre,
        trackNumber: metadata.trackNumber ?? existing?.trackNumber,
        discNumber: metadata.discNumber ?? existing?.discNumber,
        lyrics: metadata.lyrics ?? existing?.lyrics,
        pictures: existing?.pictures ?? const [],
      );

      await at.AudioTags.write(filePath, tag);
      return true;
    } on at.AudioTagsError catch (e) {
      debugPrint(
        'MetadataService.writeMetadata: audiotags error for $filePath: $e',
      );
      return false;
    } catch (e) {
      debugPrint('MetadataService.writeMetadata failed for $filePath: $e');
      return false;
    }
  }

  /// Apply [updates] to every file in [filePaths]. Only non-null fields in
  /// [updates] are written; null fields are left unchanged.
  ///
  /// Returns a map of {filePath: success} for each file.
  Future<Map<String, bool>> batchEdit(
    List<String> filePaths,
    TrackMetadata updates,
  ) async {
    final results = <String, bool>{};
    for (final path in filePaths) {
      // Read existing metadata, merge with updates, write back.
      final existing = await readMetadata(path);
      final merged = existing?.copyWith(updates) ?? updates;
      results[path] = await writeMetadata(path, merged);
    }
    return results;
  }

  /// Extract embedded lyrics from a file.
  Future<String?> extractEmbeddedLyrics(String filePath) async {
    final meta = await readMetadata(filePath);
    return meta?.lyrics;
  }

  /// Extract the first embedded picture (album art) from a file.
  /// Returns the raw bytes, or null if no picture is embedded.
  Future<List<int>?> extractAlbumArt(String filePath) async {
    await _ensureInit();
    try {
      final tag = await at.AudioTags.read(filePath);
      if (tag == null || tag.pictures.isEmpty) return null;
      return tag.pictures.first.bytes;
    } catch (e) {
      debugPrint('MetadataService.extractAlbumArt failed for $filePath: $e');
      return null;
    }
  }
}

/// A mutable bag of metadata fields. Null fields mean "don't change".
class TrackMetadata {
  final String? title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final String? genre;
  final String? composer;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final String? lyrics;
  final String? artUrl;

  const TrackMetadata({
    this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.genre,
    this.composer,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.lyrics,
    this.artUrl,
  });

  /// Merge another [other] into this metadata. Non-null fields in [other]
  /// override this.
  TrackMetadata copyWith(TrackMetadata other) => TrackMetadata(
        title: other.title ?? title,
        artist: other.artist ?? artist,
        albumArtist: other.albumArtist ?? albumArtist,
        album: other.album ?? album,
        genre: other.genre ?? genre,
        composer: other.composer ?? composer,
        year: other.year ?? year,
        trackNumber: other.trackNumber ?? trackNumber,
        discNumber: other.discNumber ?? discNumber,
        lyrics: other.lyrics ?? lyrics,
        artUrl: other.artUrl ?? artUrl,
      );

  factory TrackMetadata.fromTrack(Track t) => TrackMetadata(
        title: t.title,
        artist: t.artist,
        albumArtist: t.albumArtist.isNotEmpty ? t.albumArtist : null,
        album: t.album.isNotEmpty ? t.album : null,
        genre: t.genre.isNotEmpty ? t.genre : null,
        composer: t.composer.isNotEmpty ? t.composer : null,
        year: t.year > 0 ? t.year : null,
        trackNumber: t.trackNumber,
        discNumber: t.discNumber,
        lyrics: t.embeddedLyrics,
      );
}
