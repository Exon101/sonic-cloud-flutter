import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api_client.dart';

/// Bridges the local [LibraryService] with the cloud `/api/library` endpoint.
///
/// Two responsibilities:
///   1. `pushTrack(Track)` — upsert a local track into the cloud library.
///   2. `pullTracks()` — fetch all cloud tracks and convert them to [Track]
///      objects (with `audioUrl` left empty since audio bytes are not hosted
///      server-side; the player falls back to the local file or asset).
///
/// The cloud library is metadata-only — the server remembers *what's in the
/// user's library* so it can be synced across devices. The actual audio
/// stream URL is device-specific (asset, file path, or cloud-provider URL)
/// and stays client-side.
class ApiLibrarySync extends ChangeNotifier {
  ApiLibrarySync(this._client);

  final ApiClient _client;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Pushes a single track to the cloud library.
  Future<void> pushTrack(Track track) async {
    await _client.post('library', body: _trackToJson(track));
  }

  /// Pushes multiple tracks in sequence. The server has no batch endpoint
  /// yet — this issues one request per track.
  Future<void> pushTracks(Iterable<Track> tracks) async {
    for (final t in tracks) {
      try {
        await pushTrack(t);
      } catch (e) {
        debugPrint('ApiLibrarySync: failed to push ${t.id}: $e');
      }
    }
  }

  /// Fetches all cloud tracks for the current user.
  ///
  /// Returns a list of [Track] objects with the metadata fields populated
  /// and `audioUrl` set to the empty string (caller resolves the actual
  /// audio source locally).
  Future<List<Track>> pullTracks({int limit = 500}) async {
    final all = <Track>[];
    String? cursor;
    do {
      final query = <String, String>{'limit': limit.toString()};
      if (cursor != null) query['cursor'] = cursor;
      final res = await _client.get('library', query: query);
      final tracks = (res['tracks'] as List?) ?? [];
      for (final t in tracks) {
        all.add(_trackFromJson(t as Map<String, dynamic>));
      }
      cursor = res['nextCursor'] as String?;
    } while (cursor != null);
    return all;
  }

  /// Deletes a track from the cloud library.
  Future<void> deleteTrack(String trackId) async {
    await _client.delete('library/$trackId');
  }

  // ── JSON mappers ───────────────────────────────────────────────────────────
  //
  // Server track shape:
  //   { id, title, artist, album, albumArtist, genre, composer, year,
  //     duration (seconds), format, fileSize, fileSystemPath, source,
  //     cloudProvider, rating, lastPlayedAt (ms), playCount, updatedAt }
  //
  // Flutter Track has: artUrl, audioUrl, isFavorite, isCloudOnly, embeddedLyrics,
  // replayGain*, dateAdded, etc. — server has no equivalents. We send only
  // the fields the server understands; on pull we leave the extras as defaults.

  Map<String, dynamic> _trackToJson(Track t) => {
        'id': t.id,
        'title': t.title,
        'artist': t.artist,
        'album': t.album,
        'albumArtist': t.albumArtist,
        'genre': t.genre,
        'composer': t.composer,
        'year': t.year,
        'duration': t.duration.inSeconds.toDouble(),
        if (t.format != null) 'format': t.format!.name,
        if (t.fileSystemPath != null) 'fileSystemPath': t.fileSystemPath,
        'source': t.isCloudOnly ? 'cloud' : 'local',
        'rating': t.rating,
        if (t.lastPlayedAt != null) 'lastPlayedAt': t.lastPlayedAt!.millisecondsSinceEpoch,
        'playCount': t.playCount,
      };

  Track _trackFromJson(Map<String, dynamic> j) {
    final durationSec = (j['duration'] as num?)?.toDouble() ?? 0.0;
    final formatStr = j['format'] as String?;
    return Track(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? 'Unknown',
      artist: (j['artist'] as String?) ?? 'Unknown Artist',
      album: (j['album'] as String?) ?? 'Unknown Album',
      albumArtist: (j['albumArtist'] as String?) ?? '',
      genre: (j['genre'] as String?) ?? '',
      composer: (j['composer'] as String?) ?? '',
      year: (j['year'] as int?) ?? 0,
      duration: Duration(seconds: durationSec.toInt()),
      artUrl: '', // Server has no art URL — caller fills from local cache.
      audioUrl: '', // Server has no audio URL — caller resolves locally.
      fileSystemPath: j['fileSystemPath'] as String?,
      format: formatStr != null ? _formatFromString(formatStr) : null,
      isCloudOnly: (j['source'] as String?) == 'cloud',
      rating: (j['rating'] as num?)?.toInt() ?? 0,
      playCount: (j['playCount'] as num?)?.toInt() ?? 0,
      lastPlayedAt: j['lastPlayedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((j['lastPlayedAt'] as num).toInt())
          : null,
    );
  }

  AudioFormat? _formatFromString(String s) {
    for (final f in AudioFormat.values) {
      if (f.name == s) return f;
    }
    return null;
  }
}
