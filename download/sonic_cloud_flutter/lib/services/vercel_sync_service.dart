import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api_auth_service.dart';
import 'api_client.dart';

/// Vercel-backed implementation of [SyncService].
///
/// Delegates auth to [ApiAuthService] (so the two stay in sync) and routes
/// every data method to the matching `/api/sync/*` or `/api/devices`
/// endpoint. The server stores queue, favorites, ratings, resume positions,
/// and settings under a single merged sync document per user.
///
/// All push* methods issue a single `POST /api/sync/push` call containing
/// just the field they own — the server shallow-merges per field so partial
/// pushes don't clobber unrelated state.
class VercelSyncService extends SyncService {
  VercelSyncService(this._client, this._auth);

  final ApiClient _client;
  final ApiAuthService _auth;

  SyncState _state = SyncState.idle;
  int? _lastSyncAt;

  @override
  UserAccount? get currentUser => _auth.currentUser;

  @override
  SyncState get state => _state;

  /// Server-side timestamp (ms epoch) of the most recent successful pull.
  /// Pass to [pullAll] to short-circuit when nothing has changed.
  int? get lastSyncAt => _lastSyncAt;

  // ── Auth ───────────────────────────────────────────────────────────────────

  @override
  Future<UserAccount> signInWithEmail(String email, String password) =>
      _auth.signInWithEmail(email);

  @override
  Future<UserAccount> signInAnonymously() => _auth.signInAnonymously();

  @override
  Future<void> signOut() => _auth.signOut();

  // ── Devices ────────────────────────────────────────────────────────────────

  @override
  Future<List<DeviceInfo>> listDevices() async {
    final res = await _client.get('devices');
    final sessions = (res['sessions'] as List?) ?? [];
    return sessions.map((s) {
      final j = s as Map<String, dynamic>;
      return DeviceInfo(
        id: (j['token'] as String?) ?? '',
        name: (j['deviceId'] as String?) ?? 'Unknown device',
        platform: 'web',
        lastSeen: DateTime.fromMillisecondsSinceEpoch((j['lastSeenAt'] as num?)?.toInt() ?? 0),
      );
    }).toList();
  }

  @override
  Future<void> revokeDevice(String deviceId) async {
    // `deviceId` here is the token prefix returned by listDevices.
    await _client.delete('devices', query: {'prefix': deviceId});
  }

  @override
  Future<List<SessionInfo>> listSessions() async {
    final res = await _client.get('devices');
    final sessions = (res['sessions'] as List?) ?? [];
    return sessions.map((s) {
      final j = s as Map<String, dynamic>;
      return SessionInfo(
        id: (j['token'] as String?) ?? '',
        deviceName: (j['deviceId'] as String?) ?? 'Unknown device',
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num?)?.toInt() ?? 0),
        lastActiveAt: j['lastSeenAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch((j['lastSeenAt'] as num).toInt())
            : null,
      );
    }).toList();
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    await _client.delete('devices', query: {'prefix': sessionId});
  }

  // ── Data sync ──────────────────────────────────────────────────────────────
  //
  // Playlists are managed by the dedicated Playlist API (see /api/playlists),
  // so pushPlaylists/pullPlaylists are no-ops here. The playlist sync logic
  // lives in `ApiPlaylistSync` and is invoked from main.dart's fullSync.

  @override
  Future<void> pushPlaylists(List<Playlist> playlists) async {
    // Handled by ApiPlaylistSync — no-op here to avoid double work.
  }

  @override
  Future<List<Playlist>> pullPlaylists() async => [];

  @override
  Future<void> pushQueue(List<String> trackIds) async {
    await _client.post('sync/push', body: {'queue': trackIds});
  }

  @override
  Future<List<String>> pullQueue() async {
    final res = await _client.get('sync/pull');
    final sync = res['sync'] as Map<String, dynamic>?;
    if (sync == null) return [];
    return ((sync['queue'] as List?) ?? []).map((e) => e.toString()).toList();
  }

  @override
  Future<void> pushFavorites(Set<String> trackIds) async {
    await _client.post('sync/push', body: {'favorites': trackIds.toList()});
  }

  @override
  Future<Set<String>> pullFavorites() async {
    final res = await _client.get('sync/pull');
    final sync = res['sync'] as Map<String, dynamic>?;
    if (sync == null) return {};
    return ((sync['favorites'] as List?) ?? []).map((e) => e.toString()).toSet();
  }

  @override
  Future<void> pushRatings(Map<String, int> ratings) async {
    await _client.post('sync/push', body: {'ratings': ratings});
  }

  @override
  Future<Map<String, int>> pullRatings() async {
    final res = await _client.get('sync/pull');
    final sync = res['sync'] as Map<String, dynamic>?;
    if (sync == null) return {};
    final ratings = sync['ratings'] as Map<String, dynamic>? ?? {};
    return ratings.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  @override
  Future<void> pushResumePositions(Map<String, Duration> positions) async {
    final encoded = positions.map((k, v) => MapEntry(k, v.inSeconds.toDouble()));
    await _client.post('sync/push', body: {'positions': encoded});
  }

  @override
  Future<Map<String, Duration>> pullResumePositions() async {
    final res = await _client.get('sync/pull');
    final sync = res['sync'] as Map<String, dynamic>?;
    if (sync == null) return {};
    final positions = sync['positions'] as Map<String, dynamic>? ?? {};
    return positions.map((k, v) => MapEntry(k, Duration(seconds: (v as num).toInt())));
  }

  @override
  Future<void> pushSettings(Map<String, dynamic> settings) async {
    await _client.post('sync/push', body: {'settings': settings});
  }

  @override
  Future<Map<String, dynamic>> pullSettings() async {
    final res = await _client.get('sync/pull');
    final sync = res['sync'] as Map<String, dynamic>?;
    if (sync == null) return {};
    return (sync['settings'] as Map<String, dynamic>?) ?? {};
  }

  /// Pulls the merged sync state, recording the server timestamp so future
  /// pulls can short-circuit with `?since=`.
  Future<Map<String, dynamic>?> pullAll({int? since}) async {
    _state = SyncState.syncing;
    notifyListeners();
    try {
      final query = since != null ? {'since': since.toString()} : null;
      final res = await _client.get('sync/pull', query: query);
      if (res['unchanged'] == true) {
        _state = SyncState.success;
        notifyListeners();
        return null;
      }
      final sync = res['sync'] as Map<String, dynamic>?;
      _lastSyncAt = (res['serverTime'] as num?)?.toInt();
      _state = SyncState.success;
      notifyListeners();
      return sync;
    } catch (e) {
      _state = SyncState.error;
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> fullSync() async {
    // Just pull — pushes happen as the user mutates state.
    await pullAll();
  }
}
