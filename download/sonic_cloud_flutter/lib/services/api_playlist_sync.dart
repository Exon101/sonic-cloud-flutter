import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'playlist_service.dart';

/// Bridges the local [PlaylistService] with the cloud `/api/playlists` endpoint.
///
/// Two sync directions:
///   - [pushAll] — every local manual/smart playlist → server (upsert).
///   - [pullAll] — every server playlist → local (replace by id).
///
/// The caller (main.dart) orchestrates: on sign-in, pullAll; on local mutation,
/// push the affected playlist.
///
/// Server playlist shape:
///   { id, name, kind: 'manual'|'smart'|'auto', trackIds: string[],
///     rules?: [{field, op, value}], autoKind?: string,
///     createdAt, updatedAt }
///
/// Flutter `PlaylistKind.folder` is not representable server-side — those are
/// skipped on push and never appear on pull.
class ApiPlaylistSync extends ChangeNotifier {
  ApiPlaylistSync(this._client, this._playlists);

  final ApiClient _client;
  final PlaylistService _playlists;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Pushes a single playlist to the server. Used after local mutations.
  Future<void> push(Playlist pl) async {
    if (pl.kind == PlaylistKind.folder) return; // Server can't represent.
    try {
      await _client.put('playlists/${pl.id}', body: _playlistToJson(pl));
    } catch (e) {
      debugPrint('ApiPlaylistSync.push(${pl.id}): $e');
    }
  }

  /// Pushes every local playlist. Used after sign-in.
  Future<void> pushAll() async {
    _isSyncing = true;
    notifyListeners();
    try {
      for (final pl in _playlists.playlists) {
        await push(pl);
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Pulls every server-side playlist into the local service.
  ///
  /// Replaces any local playlist with the same id; otherwise creates a new
  /// local playlist entry. Local-only playlists (folder kind, or never-pushed)
  /// are left untouched.
  Future<List<Playlist>> pullAll() async {
    _isSyncing = true;
    notifyListeners();
    try {
      final res = await _client.get('playlists');
      final list = (res['playlists'] as List?) ?? [];
      final pulled = <Playlist>[];
      for (final p in list) {
        final pl = _playlistFromJson(p as Map<String, dynamic>);
        if (pl != null) {
          pulled.add(pl);
          _playlists.upsertFromSync(pl);
        }
      }
      return pulled;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Deletes a playlist from the server (called when the user deletes locally).
  Future<void> delete(String playlistId) async {
    try {
      await _client.delete('playlists/$playlistId');
    } catch (e) {
      debugPrint('ApiPlaylistSync.delete($playlistId): $e');
    }
  }

  // ── JSON mappers ───────────────────────────────────────────────────────────

  Map<String, dynamic> _playlistToJson(Playlist pl) {
    final kindStr = switch (pl.kind) {
      PlaylistKind.manual => 'manual',
      PlaylistKind.smart => 'smart',
      PlaylistKind.auto => 'auto',
      PlaylistKind.folder => 'manual', // Fallback — folder treated as manual.
    };
    return {
      'id': pl.id,
      'name': pl.name,
      'kind': kindStr,
      'trackIds': pl.trackIds,
      if (pl.kind == PlaylistKind.smart)
        'rules': pl.rules.map(_ruleToJson).toList(),
    };
  }

  Map<String, dynamic> _ruleToJson(SmartPlaylistRule r) => {
        'field': r.field.name,
        'op': r.op.name,
        'value': r.value,
      };

  Playlist? _playlistFromJson(Map<String, dynamic> j) {
    final kindStr = j['kind'] as String?;
    final kind = switch (kindStr) {
      'manual' => PlaylistKind.manual,
      'smart' => PlaylistKind.smart,
      'auto' => PlaylistKind.auto,
      _ => null,
    };
    if (kind == null) return null;

    final trackIds = ((j['trackIds'] as List?) ?? []).map((e) => e.toString()).toList();
    final rules = ((j['rules'] as List?) ?? [])
        .map((r) => _ruleFromJson(r as Map<String, dynamic>))
        .toList();
    final createdAt = j['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt())
        : DateTime.now();
    final updatedAt = j['updatedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch((j['updatedAt'] as num).toInt())
        : DateTime.now();

    return Playlist(
      id: j['id'] as String,
      name: (j['name'] as String?) ?? 'Untitled',
      kind: kind,
      trackIds: trackIds,
      rules: rules,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  SmartPlaylistRule _ruleFromJson(Map<String, dynamic> j) {
    return SmartPlaylistRule(
      field: SmartPlaylistField.values.firstWhere(
        (f) => f.name == j['field'],
        orElse: () => SmartPlaylistField.artist,
      ),
      op: SmartPlaylistOperator.values.firstWhere(
        (o) => o.name == j['op'],
        orElse: () => SmartPlaylistOperator.contains,
      ),
      value: (j['value'] ?? '').toString(),
    );
  }
}
