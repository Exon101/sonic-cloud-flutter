import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// SearchService — instant in-memory search across all library fields.
///
/// Supports searching by: artist, album, song, folder, lyrics, genre.
/// Returns ranked [SearchResult]s.
///
/// Designed for libraries up to ~100k tracks. For larger libraries,
/// consider a FTS index (SQLite FTS5 or a custom inverted index).
class SearchService extends ChangeNotifier {
  List<Track> _index = [];

  void index(List<Track> tracks) {
    _index = tracks;
    notifyListeners();
  }

  /// Run a search. Returns up to [limit] results per category.
  SearchResults search(String query, {int limit = 20}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const SearchResults();

    final tracks = <Track>[];
    final artists = <String>{};
    final albums = <(String, String)>{};
    final genres = <String>{};

    for (final t in _index) {
      final tMatch = t.title.toLowerCase().contains(q);
      final arMatch =
          t.artist.toLowerCase().contains(q) ||
          t.albumArtist.toLowerCase().contains(q);
      final alMatch = t.album.toLowerCase().contains(q);
      final gMatch = t.genre.toLowerCase().contains(q);
      final lMatch = t.embeddedLyrics?.toLowerCase().contains(q) ?? false;

      if (tMatch || arMatch || alMatch || gMatch || lMatch) {
        if (tracks.length < limit) tracks.add(t);
        if (arMatch) artists.add(t.primaryArtist);
        if (alMatch) albums.add((t.album, t.primaryArtist));
        if (gMatch) genres.add(t.genre);
      }
    }

    return SearchResults(
      query: query,
      tracks: tracks,
      artists: artists.take(limit).toList(),
      albums: albums.take(limit).toList(),
      genres: genres.take(limit).toList(),
    );
  }
}

/// Aggregated search results.
class SearchResults {
  final String query;
  final List<Track> tracks;
  final List<String> artists;
  final List<(String album, String artist)> albums;
  final List<String> genres;

  const SearchResults({
    this.query = '',
    this.tracks = const [],
    this.artists = const [],
    this.albums = const [],
    this.genres = const [],
  });

  bool get isEmpty =>
      tracks.isEmpty && artists.isEmpty && albums.isEmpty && genres.isEmpty;
}
