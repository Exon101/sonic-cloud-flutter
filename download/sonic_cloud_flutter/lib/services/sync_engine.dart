import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'library_service.dart';
import 'playlist_service.dart';
import 'vercel_sync_service.dart';

/// SyncEngine — the M2 realtime polling + offline write queue.
///
/// Responsibilities:
///   1. **Pull** — every [pollInterval], call `/api/sync/pull?since=<last>`,
///      `/api/library?since=<last>`, and `/api/playlists?since=<last>`. Apply
///      any changes to the local [LibraryService] / [PlaylistService] /
///      [VercelSyncService] so the UI updates in near-realtime.
///   2. **Push** — when a local mutation happens (favorite toggled, rating
///      set, playlist edited, playback state changed), enqueue it via
///      [enqueueWrite]. A debounce timer flushes the queue to the API.
///      If offline, writes sit in the queue and flush on reconnect.
///   3. **Status** — exposes [state] (a [SyncEngineState]) so the UI can
///      show "Syncing…", "Up to date", "Offline (3 pending)", etc.
///
/// The engine is designed for personal use (1-3 devices). Polling every
/// 30-60s gives sub-minute sync latency without the complexity of
/// WebSocket / SSE infrastructure. See BACKEND_SYNC_PLAN.md §6.6 for the
/// upgrade path to SSE.
class SyncEngine extends ChangeNotifier {
  SyncEngine({
    required ApiClient client,
    required VercelSyncService sync,
    required LibraryService library,
    required PlaylistService playlists,
    Duration pollInterval = const Duration(seconds: 45),
  })  : _client = client,
        _sync = sync,
        _library = library,
        _playlists = playlists,
        _pollInterval = pollInterval;

  final ApiClient _client;
  final VercelSyncService _sync;
  final LibraryService _library;
  final PlaylistService _playlists;
  final Duration _pollInterval;

  // ── State ──────────────────────────────────────────────────────────────────

  SyncEngineState _state = SyncEngineState.idle;
  int _pendingCount = 0;
  String? _lastError;
  DateTime? _lastSyncedAt;
  bool _isOnline = true;

  SyncEngineState get state => _state;
  int get pendingCount => _pendingCount;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isOnline => _isOnline;

  // High-water marks for incremental polling
  int _lastSyncAt = 0;
  int _lastLibraryAt = 0;
  int _lastPlaylistsAt = 0;

  // ── Timers ─────────────────────────────────────────────────────────────────

  Timer? _pollTimer;
  Timer? _pushDebounce;
  bool _flushing = false;

  /// Start the polling loop. Safe to call multiple times.
  void start() {
    if (_pollTimer?.isActive ?? false) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOnce());
    // Fire one immediate poll so the user doesn't have to wait for the first
    // interval to see fresh data.
    _pollOnce();
  }

  /// Stop polling + debouncer. Call on app close or sign-out.
  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pushDebounce?.cancel();
    _pushDebounce = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  // ── Pull (polling) ─────────────────────────────────────────────────────────

  Future<void> _pollOnce() async {
    if (!_isOnline) return;
    if (_state == SyncEngineState.syncing) return; // don't overlap

    _setState(SyncEngineState.syncing);
    try {
      await _pullSyncState();
      await _pullLibrary();
      await _pullPlaylists();
      _lastSyncedAt = DateTime.now();
      _lastError = null;
      _setState(SyncEngineState.idle);
    } catch (e) {
      _lastError = e.toString();
      // If the error looks network-related, mark offline
      if (_isNetworkError(e)) {
        _isOnline = false;
        _setState(SyncEngineState.offline);
      } else {
        _setState(SyncEngineState.error);
      }
      debugPrint('SyncEngine poll failed: $e');
    }
  }

  Future<void> _pullSyncState() async {
    final res = await _client.get('sync/pull', query: {
      if (_lastSyncAt > 0) 'since': _lastSyncAt.toString(),
    });
    if (res['unchanged'] == true) return;
    final sync = res['sync'] as Map<String, dynamic>?;
    if (sync == null) return;
    _lastSyncAt = (res['serverTime'] as num?)?.toInt() ?? _lastSyncAt;

    // Apply favorites + ratings to the local library
    final favorites = ((sync['favorites'] as List?) ?? []).cast<String>().toSet();
    final ratings = (sync['ratings'] as Map<String, dynamic>?) ?? {};
    for (final t in _library.tracks) {
      final isFav = favorites.contains(t.id);
      if (t.isFavorite != isFav) {
        _library.setFavorite(t.id, isFav, notify: false);
      }
      final rating = (ratings[t.id] as num?)?.toInt() ?? 0;
      if (t.rating != rating) {
        _library.setRating(t.id, rating, notify: false);
      }
    }
    _library.notifyListeners();
  }

  Future<void> _pullLibrary() async {
    final res = await _client.get('library', query: {
      if (_lastLibraryAt > 0) 'since': _lastLibraryAt.toString(),
    });
    if (res['unchanged'] == true) return;
    final tracks = (res['tracks'] as List?) ?? [];
    if (tracks.isEmpty) return;
    _lastLibraryAt = (res['serverTime'] as num?)?.toInt() ?? _lastLibraryAt;

    // Convert JSON tracks to Track objects and merge into local library
    for (final t in tracks) {
      final track = _trackFromJson(t as Map<String, dynamic>);
      if (track != null) {
        _library.upsertFromCloud(track);
      }
    }
    _library.notifyListeners();
  }

  Future<void> _pullPlaylists() async {
    final res = await _client.get('playlists', query: {
      if (_lastPlaylistsAt > 0) 'since': _lastPlaylistsAt.toString(),
    });
    if (res['unchanged'] == true) return;
    final playlists = (res['playlists'] as List?) ?? [];
    if (playlists.isEmpty) return;
    _lastPlaylistsAt = (res['serverTime'] as num?)?.toInt() ?? _lastPlaylistsAt;

    for (final p in playlists) {
      final pl = _playlistFromJson(p as Map<String, dynamic>);
      if (pl != null) {
        _playlists.upsertFromSync(pl);
      }
    }
    _playlists.notifyChanged();
  }

  // ── Push (write queue) ─────────────────────────────────────────────────────
  //
  // Writes are debounced: when [enqueueWrite] is called, we wait 2 seconds
  // for more writes to arrive, then flush them all in one batch. If the
  // app goes offline, writes sit in the in-memory queue and flush on the
  // next successful poll.

  final List<PendingWrite> _writeQueue = [];

  /// Enqueue a write to be sent to the API. The engine debounces and
  /// flushes automatically.
  void enqueueWrite({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) {
    _writeQueue.add(PendingWrite(
      method: method,
      path: path,
      body: body,
    ));
    _pendingCount = _writeQueue.length;
    notifyListeners();

    // Reset the debounce timer — flush 2s after the last write
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(seconds: 2), _flushWrites);
  }

  /// Force-flush all pending writes now (e.g. on app foreground).
  Future<void> flushNow() async {
    _pushDebounce?.cancel();
    await _flushWrites();
  }

  Future<void> _flushWrites() async {
    if (_flushing) return;
    if (_writeQueue.isEmpty) return;
    if (!_isOnline) return;
    _flushing = true;

    final batch = List<PendingWrite>.from(_writeQueue);
    _writeQueue.clear();
    _pendingCount = 0;
    notifyListeners();

    for (final w in batch) {
      try {
        await _client.request(w.method, w.path, body: w.body);
      } catch (e) {
        // Re-enqueue failed writes at the end of the queue
        _writeQueue.add(w);
        _pendingCount = _writeQueue.length;
        if (_isNetworkError(e)) {
          _isOnline = false;
          _setState(SyncEngineState.offline);
        }
        debugPrint('SyncEngine: write failed, re-queued: $e');
        break; // stop flushing — network is down
      }
    }

    _flushing = false;
    if (_isOnline && _state == SyncEngineState.offline) {
      _setState(SyncEngineState.idle);
    }
    if (_pendingCount > 0) notifyListeners();
  }

  // ── Convenience push helpers ───────────────────────────────────────────────

  /// Push a "toggle favorite" mutation.
  void pushFavorite(String trackId, bool isFavorite) {
    // The server stores favorites as a set in sync_state. We push the full
    // set each time (small for personal use).
    final currentFavorites = _library.favorites.map((t) => t.id).toSet();
    if (isFavorite) {
      currentFavorites.add(trackId);
    } else {
      currentFavorites.remove(trackId);
    }
    enqueueWrite(
      method: 'POST',
      path: 'sync/push',
      body: {'favorites': currentFavorites.toList()},
    );
  }

  /// Push a "set rating" mutation.
  void pushRating(String trackId, int rating) {
    enqueueWrite(
      method: 'POST',
      path: 'sync/push',
      body: {'ratings': {trackId: rating}},
    );
  }

  /// Push the current playback state (queue, position, playing).
  void pushPlaybackState({
    required List<String> queue,
    required int currentIndex,
    required bool shuffleEnabled,
    required String repeatMode,
    required double speed,
    required double positionSec,
    required bool playing,
    required String deviceId,
  }) {
    enqueueWrite(
      method: 'POST',
      path: 'sync/push',
      body: {
        'queue': queue,
        'currentIndex': currentIndex,
        'shuffleEnabled': shuffleEnabled,
        'repeatMode': repeatMode,
        'speed': speed,
        'positionSec': positionSec,
        'playing': playing,
        'updatedByDevice': deviceId,
      },
    );
  }

  /// Push a track upsert (e.g. when a new track is added to the library).
  void pushTrack(Track track) {
    enqueueWrite(
      method: 'POST',
      path: 'library',
      body: {
        'id': track.id,
        'title': track.title,
        'artist': track.artist,
        'album': track.album,
        'duration': track.duration.inSeconds.toDouble(),
        'isFavorite': track.isFavorite,
        'rating': track.rating,
        'playCount': track.playCount,
      },
    );
  }

  /// Push a playlist upsert.
  void pushPlaylist(Playlist pl) {
    enqueueWrite(
      method: 'PUT',
      path: 'playlists/${pl.id}',
      body: {
        'name': pl.name,
        'kind': pl.kind.name,
        'trackIds': pl.trackIds,
        if (pl.kind == PlaylistKind.smart) 'rules': pl.rules.map(_ruleToJson).toList(),
      },
    );
  }

  /// Push a settings change.
  void pushSettings(Map<String, dynamic> settings) {
    enqueueWrite(
      method: 'POST',
      path: 'sync/push',
      body: {'settings': settings},
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setState(SyncEngineState s) {
    if (_state == s) return;
    _state = s;
    notifyListeners();
  }

  bool _isNetworkError(dynamic e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('failed to') ||
        msg.contains('socket') ||
        msg.contains('connection');
  }

  Track? _trackFromJson(Map<String, dynamic> j) {
    try {
      final durationSec = (j['duration'] as num?)?.toDouble() ?? 0.0;
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
        artUrl: '',
        audioUrl: '',
        isCloudOnly: (j['isCloudOnly'] as bool?) == true,
        isFavorite: (j['isFavorite'] as bool?) == true,
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        playCount: (j['playCount'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('SyncEngine: failed to parse track: $e');
      return null;
    }
  }

  Playlist? _playlistFromJson(Map<String, dynamic> j) {
    final kindStr = j['kind'] as String?;
    final kind = switch (kindStr) {
      'manual' => PlaylistKind.manual,
      'smart' => PlaylistKind.smart,
      'auto' => PlaylistKind.auto,
      _ => null,
    };
    if (kind == null) return null;
    return Playlist(
      id: j['id'] as String,
      name: (j['name'] as String?) ?? 'Untitled',
      kind: kind,
      trackIds: ((j['trackIds'] as List?) ?? []).map((e) => e.toString()).toList(),
      rules: ((j['rules'] as List?) ?? [])
          .map((r) => _ruleFromJson(r as Map<String, dynamic>))
          .toList(),
      createdAt: j['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt())
          : DateTime.now(),
      updatedAt: j['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((j['updatedAt'] as num).toInt())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> _ruleToJson(SmartPlaylistRule r) => {
        'field': r.field.name,
        'op': r.op.name,
        'value': r.value,
      };

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

  /// Mark the engine as back online (e.g. when connectivity is restored).
  /// Triggers an immediate poll + write flush.
  void markOnline() {
    if (!_isOnline) {
      _isOnline = true;
      _setState(SyncEngineState.idle);
      _pollOnce();
      flushNow();
    }
  }
}

/// A queued API write pending flush.
class PendingWrite {
  final String method;
  final String path;
  final Map<String, dynamic>? body;
  const PendingWrite({required this.method, required this.path, this.body});
}

/// Sync engine states for UI display.
enum SyncEngineState {
  /// Idle — nothing to sync, last sync was successful.
  idle,
  /// Actively syncing — a poll or write flush is in progress.
  syncing,
  /// Offline — network is unavailable; writes are queued.
  offline,
  /// Error — last sync failed for a non-network reason.
  error,
}
