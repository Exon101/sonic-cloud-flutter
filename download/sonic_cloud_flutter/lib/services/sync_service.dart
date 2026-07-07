import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// SyncService — abstract cross-device sync.
///
/// What gets synced:
///   - Playlists (manual + smart rules)
///   - Queue state
///   - Favorites
///   - Ratings
///   - Last played position (resume)
///   - Playback history
///   - Settings (equalizer presets, themes, etc.)
///
/// Implementation: this is the abstract contract. A concrete
/// [FirebaseSyncService] or [SelfHostedSyncService] would implement these
/// methods. For v2, [LocalSyncService] is the no-op default that just stores
/// everything locally.
abstract class SyncService extends ChangeNotifier {
  UserAccount? get currentUser;
  SyncState get state;

  // ── Auth ───────────────────────────────────────────────────────────────────
  Future<UserAccount> signInWithEmail(String email, String password);
  Future<UserAccount> signInAnonymously();
  Future<void> signOut();

  // ── Device management ──────────────────────────────────────────────────────
  Future<List<DeviceInfo>> listDevices();
  Future<void> revokeDevice(String deviceId);
  Future<List<SessionInfo>> listSessions();
  Future<void> revokeSession(String sessionId);

  // ── Data sync ──────────────────────────────────────────────────────────────
  Future<void> pushPlaylists(List<Playlist> playlists);
  Future<List<Playlist>> pullPlaylists();

  Future<void> pushQueue(List<String> trackIds);
  Future<List<String>> pullQueue();

  Future<void> pushFavorites(Set<String> trackIds);
  Future<Set<String>> pullFavorites();

  Future<void> pushRatings(Map<String, int> ratings);
  Future<Map<String, int>> pullRatings();

  Future<void> pushResumePositions(Map<String, Duration> positions);
  Future<Map<String, Duration>> pullResumePositions();

  Future<void> pushSettings(Map<String, dynamic> settings);
  Future<Map<String, dynamic>> pullSettings();

  /// Full sync: push all local changes, pull all remote changes.
  Future<void> fullSync();
}

/// LocalSyncService — no-op default that stores nothing remotely.
///
/// Use this when the user has not signed in. All push* methods are no-ops;
/// all pull* methods return empty collections.
class LocalSyncService extends SyncService {
  UserAccount? _user;
  SyncState _state = SyncState.idle;

  @override
  UserAccount? get currentUser => _user;
  @override
  SyncState get state => _state;

  @override
  Future<UserAccount> signInWithEmail(String email, String password) async {
    _user = UserAccount(id: 'local-$email', email: email);
    notifyListeners();
    return _user!;
  }

  @override
  Future<UserAccount> signInAnonymously() async {
    _user = UserAccount(
      id: 'anon-${DateTime.now().millisecondsSinceEpoch}',
      email: 'anonymous@local',
      isAnonymous: true,
    );
    notifyListeners();
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    notifyListeners();
  }

  @override
  Future<List<DeviceInfo>> listDevices() async => [];
  @override
  Future<void> revokeDevice(String deviceId) async {}
  @override
  Future<List<SessionInfo>> listSessions() async => [];
  @override
  Future<void> revokeSession(String sessionId) async {}

  @override
  Future<void> pushPlaylists(List<Playlist> playlists) async {}
  @override
  Future<List<Playlist>> pullPlaylists() async => [];
  @override
  Future<void> pushQueue(List<String> trackIds) async {}
  @override
  Future<List<String>> pullQueue() async => [];
  @override
  Future<void> pushFavorites(Set<String> trackIds) async {}
  @override
  Future<Set<String>> pullFavorites() async => {};
  @override
  Future<void> pushRatings(Map<String, int> ratings) async {}
  @override
  Future<Map<String, int>> pullRatings() async => {};
  @override
  Future<void> pushResumePositions(Map<String, Duration> positions) async {}
  @override
  Future<Map<String, Duration>> pullResumePositions() async => {};
  @override
  Future<void> pushSettings(Map<String, dynamic> settings) async {}
  @override
  Future<Map<String, dynamic>> pullSettings() async => {};
  @override
  Future<void> fullSync() async {
    _state = SyncState.success;
    notifyListeners();
  }
}
