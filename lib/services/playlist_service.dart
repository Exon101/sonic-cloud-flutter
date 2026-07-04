import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

/// PlaylistService — manages manual, smart, folder, and auto playlists.
///
/// Smart playlists are re-evaluated against the library on demand via
/// [evaluateSmartPlaylist]. Auto playlists (Recently Added, Most Played, etc.)
/// are generated on demand via [autoPlaylist].
class PlaylistService extends ChangeNotifier {
  final Map<String, Playlist> _playlists = {};

  List<Playlist> get playlists =>
      _playlists.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  Playlist? byId(String id) => _playlists[id];

  // ── Manual playlists ───────────────────────────────────────────────────────
  Playlist createPlaylist(String name, {String? description}) {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final pl = Playlist(
      id: id,
      name: name,
      description: description,
      kind: PlaylistKind.manual,
      createdAt: now,
      updatedAt: now,
    );
    _playlists[id] = pl;
    notifyListeners();
    return pl;
  }

  Future<void> addToPlaylist(String playlistId, List<String> trackIds) async {
    final pl = _playlists[playlistId];
    if (pl == null) return;
    _playlists[playlistId] = pl.copyWith(
      trackIds: [...pl.trackIds, ...trackIds],
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> removeFromPlaylist(
    String playlistId,
    List<String> trackIds,
  ) async {
    final pl = _playlists[playlistId];
    if (pl == null) return;
    _playlists[playlistId] = pl.copyWith(
      trackIds: pl.trackIds.where((id) => !trackIds.contains(id)).toList(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final pl = _playlists[playlistId];
    if (pl == null) return;
    _playlists[playlistId] = pl.copyWith(
      name: newName,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.remove(playlistId);
    notifyListeners();
  }

  // ── Smart playlists ────────────────────────────────────────────────────────
  Playlist createSmartPlaylist(
    String name, {
    required List<SmartPlaylistRule> rules,
  }) {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final pl = Playlist(
      id: id,
      name: name,
      kind: PlaylistKind.smart,
      rules: rules,
      createdAt: now,
      updatedAt: now,
    );
    _playlists[id] = pl;
    notifyListeners();
    return pl;
  }

  /// Evaluate a smart playlist's rules against [tracks] and return matching ids.
  List<String> evaluateSmartPlaylist(Playlist pl, List<Track> tracks) {
    if (pl.kind != PlaylistKind.smart) return pl.trackIds;
    return tracks
        .where((t) => pl.rules.every((r) => r.matches(t)))
        .map((t) => t.id)
        .toList();
  }

  // ── Auto playlists (built-in, always present) ──────────────────────────────
  Playlist autoPlaylist(AutoPlaylistKind kind, List<Track> tracks) {
    final ids = switch (kind) {
      AutoPlaylistKind.recentlyAdded => _recentlyAdded(tracks),
      AutoPlaylistKind.recentlyPlayed => _recentlyPlayed(tracks),
      AutoPlaylistKind.mostPlayed => _mostPlayed(tracks),
      AutoPlaylistKind.leastPlayed => _leastPlayed(tracks),
      AutoPlaylistKind.neverPlayed => _neverPlayed(tracks),
      AutoPlaylistKind.favorites =>
        tracks.where((t) => t.isFavorite).map((t) => t.id).toList(),
    };

    return Playlist(
      id: 'auto_${kind.name}',
      name: kind.displayName,
      kind: PlaylistKind.auto,
      trackIds: ids,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  List<String> _recentlyAdded(List<Track> tracks) {
    final sorted = tracks.where((t) => t.dateAdded != null).toList()
      ..sort((a, b) => b.dateAdded!.compareTo(a.dateAdded!));
    return sorted.take(50).map((t) => t.id).toList();
  }

  List<String> _recentlyPlayed(List<Track> tracks) {
    final sorted = tracks.where((t) => t.lastPlayedAt != null).toList()
      ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
    return sorted.take(50).map((t) => t.id).toList();
  }

  List<String> _mostPlayed(List<Track> tracks) {
    final sorted = tracks.toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    return sorted.take(50).map((t) => t.id).toList();
  }

  List<String> _leastPlayed(List<Track> tracks) {
    final sorted = tracks.toList()
      ..sort((a, b) => a.playCount.compareTo(b.playCount));
    return sorted.take(50).map((t) => t.id).toList();
  }

  List<String> _neverPlayed(List<Track> tracks) {
    return tracks.where((t) => t.playCount == 0).map((t) => t.id).toList();
  }
}

enum AutoPlaylistKind {
  recentlyAdded('Recently Added'),
  recentlyPlayed('Recently Played'),
  mostPlayed('Most Played'),
  leastPlayed('Least Played'),
  neverPlayed('Never Played'),
  favorites('Favorites');

  const AutoPlaylistKind(this.displayName);
  final String displayName;
}
