/// A single audio track.
class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int year;
  final Duration duration;
  final String artUrl;
  final bool isCloudOnly;
  final bool isFavorite;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.year,
    required this.duration,
    required this.artUrl,
    this.isCloudOnly = false,
    this.isFavorite = false,
  });

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? year,
    Duration? duration,
    String? artUrl,
    bool? isCloudOnly,
    bool? isFavorite,
  }) =>
      Track(
        id: id ?? this.id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        year: year ?? this.year,
        duration: duration ?? this.duration,
        artUrl: artUrl ?? this.artUrl,
        isCloudOnly: isCloudOnly ?? this.isCloudOnly,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  String get formattedDuration {
    final m = duration.inMinutes;
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// A music album (used in the Recently Played carousel).
class Album {
  final String id;
  final String title;
  final String artist;
  final String artUrl;

  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.artUrl,
  });
}

/// A connected cloud storage drive.
class CloudDrive {
  final String id;
  final String name;
  final String description;
  final CloudDriveKind kind;
  final bool streamMode;
  final bool downloadForOffline;

  const CloudDrive({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    this.streamMode = false,
    this.downloadForOffline = false,
  });
}

enum CloudDriveKind { googleDrive, dropbox, empty }

/// User profile shown in Settings & top app bars.
class UserProfile {
  final String name;
  final String tier;
  final String avatarUrl;

  const UserProfile({
    required this.name,
    required this.tier,
    required this.avatarUrl,
  });
}

/// A recent cloud sync activity entry.
class SyncActivity {
  final String id;
  final String fileName;
  final String status;
  final SyncState state;
  final double? progress; // 0..1, only for [SyncState.downloading]

  const SyncActivity({
    required this.id,
    required this.fileName,
    required this.status,
    required this.state,
    this.progress,
  });
}

enum SyncState { downloading, synced, failed }
