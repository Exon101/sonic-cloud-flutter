import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'lyrics_service.dart';

/// Cloud-backed [LyricsProvider] that calls `/api/lyrics`.
///
/// Storage flow:
///   - On [fetch]: GET /api/lyrics?trackId=<id> → return parsed [Lyrics] or
///     [Lyrics.empty] on 404.
///   - On [store]: PUT /api/lyrics?trackId=<id> with the raw LRC text.
///
/// The server parses LRC identically to the local [LyricsService.parseLrc],
/// so a fetched lyrics object round-trips losslessly.
class VercelLyricsProvider extends LyricsProvider {
  VercelLyricsProvider(this._client);

  final ApiClient _client;

  @override
  String get name => 'vercel';

  @override
  Future<Lyrics> fetch(Track track) async {
    try {
      final res = await _client.get('lyrics', query: {'trackId': track.id});
      final raw = res['raw'] as String?;
      if (raw == null || raw.isEmpty) return Lyrics.empty;
      return LyricsService.parseLrc(raw);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return Lyrics.empty;
      debugPrint('VercelLyricsProvider.fetch(${track.id}): $e');
      return Lyrics.empty;
    } catch (e) {
      debugPrint('VercelLyricsProvider.fetch(${track.id}): $e');
      return Lyrics.empty;
    }
  }

  /// Stores lyrics for [track] on the server.
  Future<void> store(Track track, String rawLrc) async {
    try {
      await _client.put('lyrics', query: {'trackId': track.id}, body: {
        'raw': rawLrc,
        'provider': 'user',
      });
    } catch (e) {
      debugPrint('VercelLyricsProvider.store(${track.id}): $e');
    }
  }
}
