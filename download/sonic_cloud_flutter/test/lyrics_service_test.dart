import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/services/lyrics_service.dart';

void main() {
  group('LyricsService.parseLrc', () {
    test('parses plain (unsynced) lines', () {
      const lrc = '''
Hello world
This is a song
Goodbye
''';
      final lyrics = LyricsService.parseLrc(lrc);
      expect(lyrics.isSynced, false);
      expect(lyrics.lines.length, 3);
      expect(lyrics.lines[0].text, 'Hello world');
      expect(lyrics.lines[1].text, 'This is a song');
      expect(lyrics.lines[2].text, 'Goodbye');
    });

    test('parses single-timestamp lines (mm:ss.xx)', () {
      const lrc = '''
[00:01.50]First line
[00:03.00]Second line
[00:05.25]Third line
''';
      final lyrics = LyricsService.parseLrc(lrc);
      expect(lyrics.isSynced, true);
      expect(lyrics.lines.length, 3);
      expect(lyrics.lines[0].timestamp, const Duration(milliseconds: 1500));
      expect(lyrics.lines[1].timestamp, const Duration(seconds: 3));
      expect(lyrics.lines[2].timestamp, const Duration(milliseconds: 5250));
    });

    test('parses multiple timestamps per line', () {
      const lrc = '[00:01.00][00:05.00]Repeated line';
      final lyrics = LyricsService.parseLrc(lrc);
      expect(lyrics.lines.length, 2);
      expect(lyrics.lines[0].timestamp, const Duration(seconds: 1));
      expect(lyrics.lines[1].timestamp, const Duration(seconds: 5));
      expect(lyrics.lines[0].text, 'Repeated line');
      expect(lyrics.lines[1].text, 'Repeated line');
    });

    test('parses millisecond-precision timestamps (mm:ss.xxx)', () {
      const lrc = '[00:01.123]Hi';
      final lyrics = LyricsService.parseLrc(lrc);
      expect(lyrics.lines.first.timestamp, const Duration(milliseconds: 1123));
    });

    test('parses metadata header (ti, ar)', () {
      const lrc = '''
[ti:Song Title]
[ar:Artist Name]
[00:00.00]Lyric
''';
      final lyrics = LyricsService.parseLrc(lrc);
      expect(lyrics.title, 'Song Title');
      expect(lyrics.author, 'Artist Name');
    });

    test('sorts lines by timestamp ascending', () {
      const lrc = '''
[00:05.00]Fifth
[00:01.00]First
[00:03.00]Third
''';
      final lyrics = LyricsService.parseLrc(lrc);
      expect(lyrics.lines[0].timestamp!.inSeconds, 1);
      expect(lyrics.lines[1].timestamp!.inSeconds, 3);
      expect(lyrics.lines[2].timestamp!.inSeconds, 5);
    });

    test('returns empty for empty input', () {
      final lyrics = LyricsService.parseLrc('');
      expect(lyrics.isEmpty, true);
      expect(lyrics.lines, isEmpty);
    });
  });

  group('LyricsService.activeLineIndex', () {
    final svc = LyricsService();

    test('returns -1 for unsynced lyrics', () {
      const lyrics = Lyrics(lines: [LyricLine(text: 'no timestamp')]);
      expect(svc.activeLineIndex(lyrics, Duration.zero), -1);
    });

    test('returns -1 before the first timestamp', () {
      const lyrics = Lyrics(
        isSynced: true,
        lines: [
          LyricLine(timestamp: Duration(seconds: 5), text: 'first'),
          LyricLine(timestamp: Duration(seconds: 10), text: 'second'),
        ],
      );
      expect(svc.activeLineIndex(lyrics, Duration(seconds: 2)), -1);
    });

    test('returns the index of the most recent timestamp', () {
      const lyrics = Lyrics(
        isSynced: true,
        lines: [
          LyricLine(timestamp: Duration(seconds: 5), text: 'first'),
          LyricLine(timestamp: Duration(seconds: 10), text: 'second'),
          LyricLine(timestamp: Duration(seconds: 15), text: 'third'),
        ],
      );
      expect(svc.activeLineIndex(lyrics, Duration(seconds: 7)), 0);
      expect(svc.activeLineIndex(lyrics, Duration(seconds: 12)), 1);
      expect(svc.activeLineIndex(lyrics, Duration(seconds: 100)), 2);
    });
  });
}
