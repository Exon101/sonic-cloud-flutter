import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/models/models.dart';
import 'package:sonic_cloud/services/lyrics_service.dart';

void main() {
  group('LyricsService sidecar LRC', () {
    final svc = LyricsService();

    test(
      'saveSidecarLrc returns false when track has no fileSystemPath',
      () async {
        const track = Track(
          id: 't1',
          title: 'Test',
          artist: 'Artist',
          album: 'Album',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: '',
        );
        final result = await svc.saveSidecarLrc(track, Lyrics.empty);
        expect(result, isFalse);
      },
    );
  });

  group('LyricsService.parseLrc edge cases', () {
    test('handles empty lines between lyrics', () {
      const lrc = '''
[00:01.00]First

[00:03.00]Second
''';
      final lyrics = LyricsService.parseLrc(lrc);
      expect(lyrics.lines.length, 2); // empty line should be skipped
      expect(lyrics.lines[0].text, 'First');
      expect(lyrics.lines[1].text, 'Second');
    });

    test('handles metadata with special characters', () {
      const lrc = '''
[ti:Song "Title" (Remix)]
[ar:Artist & Friends]
[00:00.00]Lyric
''';
      final lyrics = LyricsService.parseLrc(lrc);
      expect(lyrics.title, 'Song "Title" (Remix)');
      expect(lyrics.author, 'Artist & Friends');
    });

    test('handles mm:ss.xxx (3-digit ms) format', () {
      const lrc = '[00:01.123]Test';
      final lyrics = LyricsService.parseLrc(lrc);
      expect(lyrics.lines.first.timestamp, const Duration(milliseconds: 1123));
    });

    test('handles mm:ss.xx (2-digit centiseconds) format', () {
      const lrc = '[00:01.50]Test';
      final lyrics = LyricsService.parseLrc(lrc);
      expect(lyrics.lines.first.timestamp, const Duration(milliseconds: 1500));
    });

    test('handles multiple timestamps on one line', () {
      const lrc = '[00:01.00][00:05.00][00:10.00]Repeated';
      final lyrics = LyricsService.parseLrc(lrc);
      expect(lyrics.lines.length, 3);
      expect(lyrics.lines[0].timestamp, const Duration(seconds: 1));
      expect(lyrics.lines[1].timestamp, const Duration(seconds: 5));
      expect(lyrics.lines[2].timestamp, const Duration(seconds: 10));
      expect(lyrics.lines.every((l) => l.text == 'Repeated'), isTrue);
    });
  });
}
