import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Platform detection without importing dart:io directly (which breaks web).
// On web, kIsWeb is true and Platform is never accessed.
import '../platform/io_stub.dart'
    if (dart.library.io) 'dart:io';

/// SQLite database for Sonic Cloud — persists tracks, playlists, play history,
/// fingerprints, and cloud-provider configs across app restarts.
///
/// Uses `sqflite` (not Drift) so there's no codegen step — the schema is plain
/// SQL strings. Run `flutter pub get` and the app is ready; no
/// `build_runner` needed.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  /// Open (or create) the database. Call once at app startup.
  ///
  /// Platform behavior:
  ///   - Mobile (Android/iOS): uses sqflite's default platform implementation
  ///   - Desktop (macOS/Windows/Linux): uses sqflite_common_ffi (SQLite via FFI)
  ///   - Web: throws UnsupportedError (sqflite not available on web — the
  ///     caller should catch this and fall back to in-memory storage)
  Future<void> open() async {
    if (_db != null) return;

    if (kIsWeb) {
      throw UnsupportedError('sqflite is not available on web — use in-memory storage');
    }

    // Desktop (macOS/Windows/Linux) needs sqflite_common_ffi
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'sonic_cloud.sqlite');
    _db = await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tracks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album_artist TEXT NOT NULL DEFAULT '',
        album TEXT NOT NULL,
        genre TEXT NOT NULL DEFAULT '',
        composer TEXT NOT NULL DEFAULT '',
        year INTEGER NOT NULL DEFAULT 0,
        track_number INTEGER,
        disc_number INTEGER,
        duration_ms INTEGER NOT NULL,
        art_url TEXT NOT NULL DEFAULT '',
        audio_url TEXT NOT NULL,
        file_system_path TEXT,
        format TEXT,
        is_cloud_only INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        rating INTEGER NOT NULL DEFAULT 0,
        play_count INTEGER NOT NULL DEFAULT 0,
        last_played_at INTEGER,
        date_added INTEGER,
        replay_gain_track_gain REAL,
        replay_gain_album_gain REAL,
        embedded_lyrics TEXT,
        source_id TEXT NOT NULL DEFAULT 'local'
      )
    ''');

    await db.execute('''
      CREATE TABLE playlists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        kind TEXT NOT NULL,
        rules_json TEXT NOT NULL DEFAULT '[]',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        art_url TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_entries (
        playlist_id TEXT NOT NULL,
        track_id TEXT NOT NULL,
        position INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, track_id, position)
      )
    ''');

    await db.execute('''
      CREATE TABLE play_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        track_id TEXT NOT NULL,
        played_at INTEGER NOT NULL,
        position_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE fingerprints (
        track_id TEXT NOT NULL,
        hash TEXT NOT NULL,
        algorithm TEXT NOT NULL DEFAULT 'chromaprint-v1',
        duration_ms INTEGER NOT NULL,
        PRIMARY KEY (track_id, algorithm)
      )
    ''');

    await db.execute('''
      CREATE TABLE cloud_provider_configs (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        display_name TEXT NOT NULL,
        account TEXT,
        root_path TEXT,
        status TEXT NOT NULL DEFAULT 'disconnected',
        stream_mode INTEGER NOT NULL DEFAULT 1,
        download_for_offline INTEGER NOT NULL DEFAULT 0,
        last_synced_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Pending writes queue for offline sync (M2).
    // Each row represents a single API call the client wants to make but
    // couldn't (or hasn't yet) because the network was unavailable or the
    // debounce timer hasn't fired. The SyncEngine drains this queue in
    // order when connectivity returns.
    await db.execute('''
      CREATE TABLE pending_writes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sequence INTEGER NOT NULL,
        method TEXT NOT NULL,
        path TEXT NOT NULL,
        body_json TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_pending_writes_sequence ON pending_writes(sequence ASC)',
    );

    // Indices for fast lookups
    await db.execute('CREATE INDEX idx_tracks_artist ON tracks(artist)');
    await db.execute('CREATE INDEX idx_tracks_album ON tracks(album)');
    await db.execute('CREATE INDEX idx_tracks_genre ON tracks(genre)');
    await db.execute('CREATE INDEX idx_tracks_year ON tracks(year)');
    await db.execute(
      'CREATE INDEX idx_tracks_favorite ON tracks(is_favorite) WHERE is_favorite = 1',
    );
    await db.execute(
      'CREATE INDEX idx_play_history_track ON play_history(track_id)',
    );
    await db.execute(
      'CREATE INDEX idx_play_history_played_at ON play_history(played_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_fingerprints_hash ON fingerprints(hash)',
    );
  }

  // ── Tracks ──────────────────────────────────────────────────────────────────
  Future<List<Map<String, Object?>>> allTracks() async {
    return _db!.query('tracks');
  }

  Future<void> upsertTrack(Map<String, Object?> entry) async {
    await _db!.insert(
      'tracks',
      entry,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertTracks(List<Map<String, Object?>> entries) async {
    final batch = _db!.batch();
    for (final e in entries) {
      batch.insert('tracks', e, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteTrack(String id) async {
    await _db!.delete('tracks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearTracks() async {
    await _db!.delete('tracks');
  }

  // ── Play history ────────────────────────────────────────────────────────────
  Future<void> recordPlay(
    String trackId, {
    Duration position = Duration.zero,
  }) async {
    await _db!.insert('play_history', {
      'track_id': trackId,
      'played_at': DateTime.now().millisecondsSinceEpoch,
      'position_ms': position.inMilliseconds,
    });
  }

  Future<List<Map<String, Object?>>> recentHistory({int limit = 100}) async {
    return _db!.query('play_history', orderBy: 'played_at DESC', limit: limit);
  }

  // ── Fingerprints ────────────────────────────────────────────────────────────
  Future<void> upsertFingerprint(Map<String, Object?> entry) async {
    await _db!.insert(
      'fingerprints',
      entry,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> allFingerprints() async {
    return _db!.query('fingerprints');
  }

  Future<List<Map<String, Object?>>> findDuplicatesOf(String hash) async {
    return _db!.query('fingerprints', where: 'hash = ?', whereArgs: [hash]);
  }

  // ── Cloud providers ─────────────────────────────────────────────────────────
  Future<List<Map<String, Object?>>> allCloudConfigs() async {
    return _db!.query('cloud_provider_configs');
  }

  Future<void> upsertCloudConfig(Map<String, Object?> entry) async {
    await _db!.insert(
      'cloud_provider_configs',
      entry,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCloudConfig(String id) async {
    await _db!.delete(
      'cloud_provider_configs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Settings (key-value) ───────────────────────────────────────────────────
  Future<String?> getSetting(String key) async {
    final rows = await _db!.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await _db!.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSetting(String key) async {
    await _db!.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  // ── Pending writes (M2 offline sync queue) ───────────────────────────────
  /// Enqueue a write that should be sent to the API. Returns the row id.
  Future<int> enqueuePendingWrite({
    required String method,
    required String path,
    String? bodyJson,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // sequence = current max + 1, so we can drain in FIFO order
    final maxRow = await _db!.rawQuery('SELECT MAX(sequence) as s FROM pending_writes');
    final nextSeq = (maxRow.first['s'] as int? ?? 0) + 1;
    return _db!.insert('pending_writes', {
      'sequence': nextSeq,
      'method': method,
      'path': path,
      'body_json': bodyJson,
      'created_at': now,
    });
  }

  /// Return all pending writes in FIFO order.
  Future<List<Map<String, Object?>>> allPendingWrites() async {
    return _db!.query('pending_writes', orderBy: 'sequence ASC');
  }

  /// Remove a pending write by id (after successful flush).
  Future<void> deletePendingWrite(int id) async {
    await _db!.delete('pending_writes', where: 'id = ?', whereArgs: [id]);
  }

  /// Count of pending writes (for UI badge / sync status).
  Future<int> pendingWriteCount() async {
    final r = await _db!.rawQuery('SELECT COUNT(*) as n FROM pending_writes');
    return (r.first['n'] as int?) ?? 0;
  }

  /// Delete all pending writes (used on sign-out).
  Future<void> clearPendingWrites() async {
    await _db!.delete('pending_writes');
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
