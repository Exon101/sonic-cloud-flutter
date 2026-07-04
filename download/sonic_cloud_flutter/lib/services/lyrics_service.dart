import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// LyricsService — parses and provides lyrics for a track.
///
/// Sources (in priority order):
///   1. Embedded lyrics from the file's ID3/Vorbis/MP4 tags (USLT/SYNCEDLYRICS)
///   2. Sidecar .lrc file next to the audio file (synced or plain)
///   3. Cloud lyrics provider (pluggable via [addProvider])
///
/// LRC parsing supports:
///   - Multiple timestamps per line:  `[00:01.23][00:15.45]lyric text`
///   - Optional metadata header:      `[ti:Title][ar:Artist][al:Album]`
///   - Both mm:ss.xx and mm:ss.xxx formats
class LyricsService extends ChangeNotifier {
  final List<LyricsProvider> _providers = [];

  void addProvider(LyricsProvider provider) {
    _providers.add(provider);
  }

  /// Fetches lyrics for [track]. Returns [Lyrics.empty] if none found.
  Future<Lyrics> getLyrics(Track track) async {
    // 1. Embedded lyrics
    if (track.embeddedLyrics != null && track.embeddedLyrics!.isNotEmpty) {
      final parsed = parseLrc(track.embeddedLyrics!);
      if (!parsed.isEmpty) return parsed;
    }

    // 2. Sidecar .lrc file (only meaningful if we know the on-disk path)
    if (track.fileSystemPath != null) {
      try {
        // Read sidecar via the platform file system. Stubbed here; production
        // code would use dart:io File('$path.lrc').
        // final lrcString = await File('${track.fileSystemPath}.lrc').readAsString();
        // return parseLrc(lrcString);
      } catch (_) {}
    }

    // 3. Cloud providers (in registration order)
    for (final provider in _providers) {
      try {
        final lyrics = await provider.fetch(track);
        if (!lyrics.isEmpty) return lyrics;
      } catch (e) {
        debugPrint('Lyrics provider ${provider.runtimeType} failed: $e');
      }
    }

    return Lyrics.empty;
  }

  /// Parse an LRC string into a [Lyrics] object.
  ///
  /// Supports:
  ///   - Lines with multiple timestamps: `[00:01.23][00:15.45]text`
  ///   - Both .xx (centiseconds) and .xxx (milliseconds) fractional seconds
  ///   - Metadata lines: `[ti:title][ar:artist][al:album][by:author][offset:ms]`
  static Lyrics parseLrc(String lrc) {
    final lines = <LyricLine>[];
    String? title, author;
    final tagRe = RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\]');
    final metaRe = RegExp(r'\[(ti|ar|al|by|offset):(.+?)\]');

    for (final rawLine in lrc.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Metadata?
      final meta = metaRe.firstMatch(line);
      if (meta != null && !line.startsWith('[0')) {
        final key = meta.group(1)!;
        final value = meta.group(2)!.trim();
        switch (key) {
          case 'ti':
            title = value;
          case 'ar':
            author = value;
        }
        continue;
      }

      // Timestamped lyric?
      final matches = tagRe.allMatches(line);
      if (matches.isEmpty) {
        // Plain (unsynced) line.
        lines.add(LyricLine(text: line));
        continue;
      }

      // Extract text after the last timestamp tag.
      final lastMatch = matches.last;
      final text = line.substring(lastMatch.end).trim();
      for (final m in matches) {
        final min = int.parse(m.group(1)!);
        final sec = int.parse(m.group(2)!);
        final fracStr = m.group(3);
        int ms = 0;
        if (fracStr != null) {
          // Pad/truncate to 3 digits for milliseconds.
          final padded = fracStr.padRight(3, '0').substring(0, 3);
          ms = int.parse(padded);
        }
        final ts = Duration(minutes: min, seconds: sec, milliseconds: ms);
        lines.add(LyricLine(timestamp: ts, text: text));
      }
    }

    // Sort by timestamp; unsynced lines stay in order at the start.
    lines.sort((a, b) {
      if (a.timestamp == null && b.timestamp == null) return 0;
      if (a.timestamp == null) return -1;
      if (b.timestamp == null) return 1;
      return a.timestamp!.compareTo(b.timestamp!);
    });

    final isSynced = lines.any((l) => l.timestamp != null);
    return Lyrics(
      title: title,
      author: author,
      lines: lines,
      isSynced: isSynced,
    );
  }

  /// Returns the index of the lyric line currently active at [position].
  /// Returns -1 if not synced or before the first timestamp.
  int activeLineIndex(Lyrics lyrics, Duration position) {
    if (!lyrics.isSynced) return -1;
    var active = -1;
    for (var i = 0; i < lyrics.lines.length; i++) {
      final ts = lyrics.lines[i].timestamp;
      if (ts == null) continue;
      if (ts <= position) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }
}

/// Pluggable lyrics provider (e.g. LRCLIB, Musixmatch, NetEase).
abstract class LyricsProvider {
  String get name;
  Future<Lyrics> fetch(Track track);
}
