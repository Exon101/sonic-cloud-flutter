import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Drift database for Sonic Cloud — persists tracks, playlists, play history,
/// and fingerprints across app restarts.
///
/// Tables:
///   - [Tracks] — full track metadata (mirrors the Track model)
///   - [Playlists] — manual + smart playlist definitions
///   - [PlaylistEntries] — ordered track ids per playlist
///   - [PlayHistory] — every play event (track id + timestamp)
///   - [Fingerprints] — chromaprint-style hashes for duplicate detection
///   - [CloudProviderConfigs] — saved cloud provider connections
///   - [Settings] — key-value store for misc preferences
///
/// Run code generation with:
///   dart run build_runner build --delete-conflicting-outputs
class Tracks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get albumArtist => text().withDefault(const Constant(''))();
  TextColumn get album => text()();
  TextColumn get genre => text().withDefault(const Constant(''))();
  TextColumn get composer => text().withDefault(const Constant(''))();
  IntColumn get year => integer().withDefault(const Constant(0))();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();
  IntColumn get durationMs => integer()();
  TextColumn get artUrl => text().withDefault(const Constant(''))();
  TextColumn get audioUrl => text()();
  TextColumn get fileSystemPath => text().nullable()();
  TextColumn get format => text().nullable()();
  BoolColumn get isCloudOnly => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get rating => integer().withDefault(const Constant(0))();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
  DateTimeColumn get dateAdded => dateTime().nullable()();
  RealColumn get replayGainTrackGain => real().nullable()();
  RealColumn get replayGainAlbumGain => real().nullable()();
  TextColumn get embeddedLyrics => text().nullable()();
  TextColumn get sourceId => text().withDefault(const Constant('local'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get kind => text()(); // manual/smart/folder/auto
  TextColumn get rulesJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get artUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PlaylistEntries extends Table {
  TextColumn get playlistId => text()();
  TextColumn get trackId => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {playlistId, trackId, position};
}

class PlayHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trackId => text()();
  DateTimeColumn get playedAt => dateTime()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
}

class Fingerprints extends Table {
  TextColumn get trackId => text()();
  TextColumn get hash => text()();
  TextColumn get algorithm => text().withDefault(const Constant('chromaprint-v1'))();
  IntColumn get durationMs => integer()();

  @override
  Set<Column> get primaryKey => {trackId, algorithm};
}

class CloudProviderConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get displayName => text()();
  TextColumn get account => text().nullable()();
  TextColumn get rootPath => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('disconnected'))();
  BoolColumn get streamMode => boolean().withDefault(const Constant(true))();
  BoolColumn get downloadForOffline => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Tracks, Playlists, PlaylistEntries, PlayHistory, Fingerprints, CloudProviderConfigs, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ── Tracks ──────────────────────────────────────────────────────────────────
  Future<List<TracksData>> allTracks() => select(tracks).get();

  Future<void> upsertTrack(TracksCompanion entry) =>
      into(tracks).insertOnConflictUpdate(entry);

  Future<void> upsertTracks(List<TracksCompanion> entries) async {
    await batch((b) => b.insertAll(tracks, entries, mode: InsertMode.insertOrReplace));
  }

  Future<void> deleteTrack(String id) =>
      (delete(tracks)..where((t) => t.id.equals(id))).go();

  Future<void> clearTracks() => delete(tracks).go();

  // ── Play history ────────────────────────────────────────────────────────────
  Future<void> recordPlay(String trackId, {Duration position = Duration.zero}) =>
      into(playHistory).insert(PlayHistoryCompanion.insert(
        trackId: trackId,
        playedAt: DateTime.now(),
        positionMs: Value(position.inMilliseconds),
      ));

  Future<List<PlayHistoryData>> recentHistory({int limit = 100}) =>
      (select(playHistory)
            ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
            ..limit(limit))
          .get();

  // ── Fingerprints ────────────────────────────────────────────────────────────
  Future<void> upsertFingerprint(FingerprintsCompanion entry) =>
      into(fingerprints).insertOnConflictUpdate(entry);

  Future<List<FingerprintsData>> allFingerprints() => select(fingerprints).get();

  Future<List<FingerprintsData>> findDuplicatesOf(String hash) =>
      (select(fingerprints)..where((f) => f.hash.equals(hash))).get();

  // ── Cloud providers ─────────────────────────────────────────────────────────
  Future<List<CloudProviderConfigsData>> allCloudConfigs() =>
      select(cloudProviderConfigs).get();

  Future<void> upsertCloudConfig(CloudProviderConfigsCompanion entry) =>
      into(cloudProviderConfigs).insertOnConflictUpdate(entry);

  Future<void> deleteCloudConfig(String id) =>
      (delete(cloudProviderConfigs)..where((c) => c.id.equals(id))).go();

  // ── Settings (key-value) ───────────────────────────────────────────────────
  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> deleteSetting(String key) =>
      (delete(settings)..where((s) => s.key.equals(key))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'sonic_cloud.sqlite'));
    return NativeDatabase.createInBackground(file, logStatements: false);
  });
}
