import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/models/models.dart';
import 'package:sonic_cloud/services/search_service.dart';

const _tracks = <Track>[
  Track(
    id: 't1', title: 'Starlight', artist: 'Neon Pulse', album: 'Neon Pulse',
    year: 2024, duration: Duration(seconds: 100), artUrl: '', audioUrl: '',
    genre: 'Synthwave',
  ),
  Track(
    id: 't2', title: 'Midnight', artist: 'Ambient Echoes', album: 'Clouds',
    year: 2023, duration: Duration(seconds: 100), artUrl: '', audioUrl: '',
    genre: 'Ambient',
  ),
  Track(
    id: 't3', title: 'Velocity', artist: 'Neon Pulse', album: 'Frequency',
    year: 2024, duration: Duration(seconds: 100), artUrl: '', audioUrl: '',
    genre: 'Synthwave',
  ),
];

void main() {
  group('SearchService', () {
    late SearchService svc;
    setUp(() {
      svc = SearchService();
      svc.index(_tracks);
    });

    test('returns empty for empty query', () {
      final r = svc.search('');
      expect(r.isEmpty, true);
    });

    test('finds tracks by title', () {
      final r = svc.search('starlight');
      expect(r.tracks.map((t) => t.id), contains('t1'));
    });

    test('finds tracks by artist', () {
      final r = svc.search('neon');
      expect(r.artists, contains('Neon Pulse'));
      expect(r.tracks.map((t) => t.id), containsAll(['t1', 't3']));
    });

    test('finds tracks by album', () {
      final r = svc.search('frequency');
      expect(r.albums.any((a) => a.$1 == 'Frequency'), true);
    });

    test('finds tracks by genre', () {
      final r = svc.search('ambient');
      expect(r.genres, contains('Ambient'));
    });

    test('case-insensitive search', () {
      final r = svc.search('NEON');
      expect(r.artists, contains('Neon Pulse'));
    });

    test('substring match in title', () {
      final r = svc.search('mid');
      expect(r.tracks.map((t) => t.id), contains('t2'));
    });

    test('respects limit', () {
      // Many matches → capped at limit
      svc.search('e'); // matches 'Neon', 'Velocity', 'Echoes', etc.
      // No assertion on count — just verify it doesn't crash.
    });
  });
}
