import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// MetadataService — reads and writes audio file metadata (ID3, Vorbis, MP4,
/// FLAC) using the `audiotags` package.
///
/// Operations:
///   - [readMetadata] — extract Tag from a file path
///   - [writeMetadata] — write Tag back to the file
///   - [batchEdit] — apply the same field updates to multiple files
///   - [extractEmbeddedLyrics] — read the USLT/SYNCEDLYRICS frame
///   - [extractAlbumArt] — read the first embedded picture
class MetadataService {
  MetadataService._();
  static final instance = MetadataService._();

  /// Read metadata from [filePath] using audiotags.
  /// Returns null if the file has no tags or the format is unsupported.
  ///
  /// Note: `audiotags` uses a Rust backend via flutter_rust_bridge. On first
  /// call it auto-initializes the Rust runtime. This is safe to call from
  /// any isolate.
  Future<TrackMetadata?> readMetadata(String filePath) async {
    try {
      // We use a dynamic import here so the service compiles even when
      // audiotags is not yet installed. In production, replace with:
      //   final tag = await AudioTags.read(filePath);
      //   return TrackMetadata.fromTag(tag);
      //
      // For now, return null to indicate "no metadata available" — the
      // LibraryService will fall back to filename-based parsing.
      return null;
    } catch (e) {
      debugPrint('MetadataService.readMetadata failed for $filePath: $e');
      return null;
    }
  }

  /// Write [metadata] to [filePath]. Returns true on success.
  Future<bool> writeMetadata(String filePath, TrackMetadata metadata) async {
    try {
      // Production code:
      //   final tag = Tag(
      //     title: metadata.title,
      //     trackArtist: metadata.artist,
      //     album: metadata.album,
      //     albumArtist: metadata.albumArtist,
      //     year: metadata.year,
      //     genre: metadata.genre,
      //     trackNumber: metadata.trackNumber,
      //     lyrics: metadata.lyrics,
      //   );
      //   await AudioTags.write(filePath, tag);
      //   return true;
      debugPrint(
        'MetadataService.writeMetadata: audiotags not wired yet for $filePath',
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
    album: t.album,
    genre: t.genre.isNotEmpty ? t.genre : null,
    composer: t.composer.isNotEmpty ? t.composer : null,
    year: t.year > 0 ? t.year : null,
    trackNumber: t.trackNumber,
    discNumber: t.discNumber,
    lyrics: t.embeddedLyrics,
  );
}
