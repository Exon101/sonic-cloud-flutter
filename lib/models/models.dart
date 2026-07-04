import 'package:uuid/uuid.dart';

/// Supported audio file formats.
enum AudioFormat {
  mp3('audio/mpeg', '.mp3'),
  flac('audio/flac', '.flac'),
  wav('audio/wav', '.wav'),
  aac('audio/aac', '.aac'),
  ogg('audio/ogg', '.ogg'),
  m4a('audio/mp4', '.m4a'),
  opus('audio/opus', '.opus');

  const AudioFormat(this.mimeType, this.extension);
  final String mimeType;
  final String extension;

  static AudioFormat? fromPath(String path) {
    final lower = path.toLowerCase();
    for (final f in values) {
      if (lower.endsWith(f.extension)) return f;
    }
    return null;
  }
}

/// A single audio track.
///
/// v2 adds: fileSystemPath, format, genre, composer, trackNumber, discNumber,
/// replayGainTrackGain, replayGainAlbumGain, rating, lastPlayedAt, playCount,
/// dateAdded, lyrics (embedded), audioUrl (streaming).
class Track {
  final String id;
  final String title;
  final String artist;
  final String albumArtist;
  final String album;
  final String genre;
  final String composer;
  final int year;
  final int? trackNumber;
  final int? discNumber;
  final Duration duration;
  final String artUrl;
  final String audioUrl;
  final String? fileSystemPath;
  final AudioFormat? format;
  final bool isCloudOnly;
  final bool isFavorite;
  final int rating; // 0..5
  final int playCount;
  final DateTime? lastPlayedAt;
  final DateTime? dateAdded;
  final double? replayGainTrackGain; // dB
  final double? replayGainAlbumGain; // dB
  final String? embeddedLyrics;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.year,
    required this.duration,
    required this.artUrl,
    required this.audioUrl,
    this.albumArtist = '',
    this.genre = '',
    this.composer = '',
    this.trackNumber,
    this.discNumber,
    this.fileSystemPath,
    this.format,
    this.isCloudOnly = false,
    this.isFavorite = false,
    this.rating = 0,
    this.playCount = 0,
    this.lastPlayedAt,
    this.dateAdded,
    this.replayGainTrackGain,
    this.replayGainAlbumGain,
    this.embeddedLyrics,
  });

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? albumArtist,
    String? album,
    String? genre,
    String? composer,
    int? year,
    int? trackNumber,
    int? discNumber,
    Duration? duration,
    String? artUrl,
    String? audioUrl,
    String? fileSystemPath,
    AudioFormat? format,
    bool? isCloudOnly,
    bool? isFavorite,
    int? rating,
    int? playCount,
    DateTime? lastPlayedAt,
    DateTime? dateAdded,
    double? replayGainTrackGain,
    double? replayGainAlbumGain,
    String? embeddedLyrics,
  }) => Track(
    id: id ?? this.id,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    albumArtist: albumArtist ?? this.albumArtist,
    album: album ?? this.album,
    genre: genre ?? this.genre,
    composer: composer ?? this.composer,
    year: year ?? this.year,
    trackNumber: trackNumber ?? this.trackNumber,
    discNumber: discNumber ?? this.discNumber,
    duration: duration ?? this.duration,
    artUrl: artUrl ?? this.artUrl,
    audioUrl: audioUrl ?? this.audioUrl,
    fileSystemPath: fileSystemPath ?? this.fileSystemPath,
    format: format ?? this.format,
    isCloudOnly: isCloudOnly ?? this.isCloudOnly,
    isFavorite: isFavorite ?? this.isFavorite,
    rating: rating ?? this.rating,
    playCount: playCount ?? this.playCount,
    lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    dateAdded: dateAdded ?? this.dateAdded,
    replayGainTrackGain: replayGainTrackGain ?? this.replayGainTrackGain,
    replayGainAlbumGain: replayGainAlbumGain ?? this.replayGainAlbumGain,
    embeddedLyrics: embeddedLyrics ?? this.embeddedLyrics,
  );

  String get formattedDuration {
    final m = duration.inMinutes;
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Album artist or fallback to track artist.
  String get primaryArtist => albumArtist.isNotEmpty ? albumArtist : artist;
}

/// An artist (aggregate of all tracks by the same primary artist).
class Artist {
  final String id;
  final String name;
  final List<String> albumIds;
  final int trackCount;
  final String? artUrl;

  const Artist({
    required this.id,
    required this.name,
    this.albumIds = const [],
    this.trackCount = 0,
    this.artUrl,
  });
}

/// An album (collection of tracks sharing album + albumArtist).
class Album {
  final String id;
  final String title;
  final String artist;
  final int year;
  final String? artUrl;
  final List<String> trackIds;
  final Duration totalDuration;
  final String? genre;

  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.year,
    this.artUrl,
    this.trackIds = const [],
    this.totalDuration = Duration.zero,
    this.genre,
  });
}

/// Genre aggregate.
class Genre {
  final String name;
  final int trackCount;
  final List<String> trackIds;
  const Genre({
    required this.name,
    this.trackCount = 0,
    this.trackIds = const [],
  });
}

/// Composer aggregate.
class Composer {
  final String name;
  final int trackCount;
  const Composer({required this.name, this.trackCount = 0});
}

/// Year aggregate (for "Browse by Year").
class YearBucket {
  final int year;
  final int albumCount;
  final int trackCount;
  const YearBucket({
    required this.year,
    this.albumCount = 0,
    this.trackCount = 0,
  });
}

/// Folder in the file-system library view.
class Folder {
  final String id;
  final String name;
  final String path;
  final int trackCount;
  final List<Folder> subfolders;
  const Folder({
    required this.id,
    required this.name,
    required this.path,
    this.trackCount = 0,
    this.subfolders = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Playlists
// ─────────────────────────────────────────────────────────────────────────────

enum PlaylistKind { manual, smart, folder, auto }

/// A playlist. Manual playlists have an explicit [trackIds] list; smart
/// playlists are generated by evaluating [rules] against the library.
class Playlist {
  final String id;
  final String name;
  final String? description;
  final PlaylistKind kind;
  final List<String> trackIds;
  final List<SmartPlaylistRule> rules;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? artUrl;

  const Playlist({
    required this.id,
    required this.name,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.trackIds = const [],
    this.rules = const [],
    this.artUrl,
  });

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    PlaylistKind? kind,
    List<String>? trackIds,
    List<SmartPlaylistRule>? rules,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? artUrl,
  }) => Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    kind: kind ?? this.kind,
    trackIds: trackIds ?? this.trackIds,
    rules: rules ?? this.rules,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    artUrl: artUrl ?? this.artUrl,
  );

  static String newId() => const Uuid().v4();
}

/// A single rule for a smart playlist. All rules are AND-combined.
class SmartPlaylistRule {
  final SmartPlaylistField field;
  final SmartPlaylistOperator op;
  final String value;

  const SmartPlaylistRule({
    required this.field,
    required this.op,
    required this.value,
  });

  bool matches(Track track) {
    final fieldValue = switch (field) {
      SmartPlaylistField.artist => track.artist,
      SmartPlaylistField.album => track.album,
      SmartPlaylistField.genre => track.genre,
      SmartPlaylistField.composer => track.composer,
      SmartPlaylistField.year => track.year.toString(),
      SmartPlaylistField.playCount => track.playCount.toString(),
      SmartPlaylistField.lastPlayed =>
        track.lastPlayedAt?.millisecondsSinceEpoch.toString() ?? '0',
      SmartPlaylistField.dateAdded =>
        track.dateAdded?.millisecondsSinceEpoch.toString() ?? '0',
      SmartPlaylistField.rating => track.rating.toString(),
      SmartPlaylistField.mood => track.genre, // mood mapped to genre for v2
    };

    switch (op) {
      case SmartPlaylistOperator.equals:
        return fieldValue.toLowerCase() == value.toLowerCase();
      case SmartPlaylistOperator.contains:
        return fieldValue.toLowerCase().contains(value.toLowerCase());
      case SmartPlaylistOperator.greaterThan:
        return (int.tryParse(fieldValue) ?? 0) > (int.tryParse(value) ?? 0);
      case SmartPlaylistOperator.lessThan:
        return (int.tryParse(fieldValue) ?? 0) < (int.tryParse(value) ?? 0);
      case SmartPlaylistOperator.inLast:
        final days = int.tryParse(value) ?? 0;
        final cutoff = DateTime.now().subtract(Duration(days: days));
        final ts = int.tryParse(fieldValue) ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(ts).isAfter(cutoff);
      case SmartPlaylistOperator.notPlayed:
        return track.playCount == 0;
      case SmartPlaylistOperator.mostPlayed:
        return track.playCount > 0;
    }
  }
}

enum SmartPlaylistField {
  artist,
  album,
  genre,
  composer,
  year,
  playCount,
  lastPlayed,
  dateAdded,
  rating,
  mood,
}

enum SmartPlaylistOperator {
  equals,
  contains,
  greaterThan,
  lessThan,
  inLast,
  notPlayed,
  mostPlayed,
}

// ─────────────────────────────────────────────────────────────────────────────
// Lyrics
// ─────────────────────────────────────────────────────────────────────────────

/// A single line of (optionally synced) lyrics.
class LyricLine {
  final Duration? timestamp; // null = unsynced
  final String text;
  final String? translation;

  const LyricLine({this.timestamp, required this.text, this.translation});
}

/// Parsed lyrics with optional sync timestamps and translations.
class Lyrics {
  final String? title;
  final String? author;
  final List<LyricLine> lines;
  final bool isSynced;
  final String? translationLanguage;

  const Lyrics({
    this.title,
    this.author,
    required this.lines,
    this.isSynced = false,
    this.translationLanguage,
  });

  static const empty = Lyrics(lines: []);

  bool get isEmpty => lines.isEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// Equalizer
// ─────────────────────────────────────────────────────────────────────────────

/// A single EQ band (frequency in Hz, gain in dB).
class EqualizerBand {
  final double frequency;
  final double gain; // -12..+12 dB
  const EqualizerBand({required this.frequency, required this.gain});
}

/// An EQ preset (named set of band gains).
class EqualizerPreset {
  final String name;
  final List<double> gains; // matches band count
  final bool isBuiltIn;

  const EqualizerPreset({
    required this.name,
    required this.gains,
    this.isBuiltIn = false,
  });

  static const flat = EqualizerPreset(
    name: 'Flat',
    gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    isBuiltIn: true,
  );
  static const bassBoost = EqualizerPreset(
    name: 'Bass Boost',
    gains: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
    isBuiltIn: true,
  );
  static const trebleBoost = EqualizerPreset(
    name: 'Treble Boost',
    gains: [0, 0, 0, 0, 0, 2, 4, 5, 6, 6],
    isBuiltIn: true,
  );
  static const vocal = EqualizerPreset(
    name: 'Vocal',
    gains: [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1],
    isBuiltIn: true,
  );
  static const rock = EqualizerPreset(
    name: 'Rock',
    gains: [4, 3, 2, 0, -1, 0, 2, 3, 4, 4],
    isBuiltIn: true,
  );
  static const pop = EqualizerPreset(
    name: 'Pop',
    gains: [-1, 0, 2, 3, 3, 2, 1, 0, -1, -2],
    isBuiltIn: true,
  );
  static const jazz = EqualizerPreset(
    name: 'Jazz',
    gains: [3, 2, 1, 2, -1, -1, 0, 1, 2, 3],
    isBuiltIn: true,
  );
  static const classical = EqualizerPreset(
    name: 'Classical',
    gains: [4, 3, 2, 1, -1, -1, 0, 2, 3, 4],
    isBuiltIn: true,
  );
  static const electronic = EqualizerPreset(
    name: 'Electronic',
    gains: [5, 4, 1, 0, -2, 2, 1, 1, 3, 4],
    isBuiltIn: true,
  );

  static const builtIns = [
    flat,
    bassBoost,
    trebleBoost,
    vocal,
    rock,
    pop,
    jazz,
    classical,
    electronic,
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Cloud providers
// ─────────────────────────────────────────────────────────────────────────────

enum CloudProviderKind {
  googleDrive,
  dropbox,
  oneDrive,
  nextcloud,
  webdav,
  smb,
  ftp,
  sftp,
  nas,
  localNetwork,
}

enum CloudProviderStatus { disconnected, connecting, connected, error }

/// Persisted configuration for a cloud provider connection.
class CloudProviderConfig {
  final String id;
  final CloudProviderKind kind;
  final String displayName;
  final String? account;
  final String? rootPath;
  final CloudProviderStatus status;
  final bool streamMode;
  final bool downloadForOffline;
  final DateTime? lastSyncedAt;

  const CloudProviderConfig({
    required this.id,
    required this.kind,
    required this.displayName,
    this.account,
    this.rootPath,
    this.status = CloudProviderStatus.disconnected,
    this.streamMode = true,
    this.downloadForOffline = false,
    this.lastSyncedAt,
  });

  CloudProviderConfig copyWith({
    CloudProviderStatus? status,
    bool? streamMode,
    bool? downloadForOffline,
    DateTime? lastSyncedAt,
  }) => CloudProviderConfig(
    id: id,
    kind: kind,
    displayName: displayName,
    account: account,
    rootPath: rootPath,
    status: status ?? this.status,
    streamMode: streamMode ?? this.streamMode,
    downloadForOffline: downloadForOffline ?? this.downloadForOffline,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync
// ─────────────────────────────────────────────────────────────────────────────

enum SyncState { idle, syncing, success, error, offline }

/// A user account (for cross-device sync).
class UserAccount {
  final String id;
  final String email;
  final bool isAnonymous;
  final List<DeviceInfo> devices;
  final List<SessionInfo> sessions;

  const UserAccount({
    required this.id,
    required this.email,
    this.isAnonymous = false,
    this.devices = const [],
    this.sessions = const [],
  });
}

class DeviceInfo {
  final String id;
  final String name;
  final String platform;
  final DateTime lastSeen;
  const DeviceInfo({
    required this.id,
    required this.name,
    required this.platform,
    required this.lastSeen,
  });
}

class SessionInfo {
  final String id;
  final String deviceName;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  const SessionInfo({
    required this.id,
    required this.deviceName,
    required this.createdAt,
    this.lastActiveAt,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Repeat / shuffle
// ─────────────────────────────────────────────────────────────────────────────

enum RepeatMode { off, all, one }

// ─────────────────────────────────────────────────────────────────────────────
// Sleep timer
// ─────────────────────────────────────────────────────────────────────────────

enum SleepTimerEndAction { pause, stop, fadeOut }

class SleepTimer {
  final Duration? remaining;
  final DateTime? endsAt;
  final SleepTimerEndAction endAction;
  final bool isActive;

  const SleepTimer({
    this.remaining,
    this.endsAt,
    this.endAction = SleepTimerEndAction.pause,
    this.isActive = false,
  });
}
