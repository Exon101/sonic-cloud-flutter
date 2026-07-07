import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/models/models.dart';
import 'package:sonic_cloud/services/library_service.dart';

void main() {
  group('LibraryService', () {
    late LibraryService svc;
    setUp(() => svc = LibraryService());

    test('importCloudTracks adds tracks and rebuilds indices', () {
      svc.importCloudTracks([
        const Track(
          id: 't1',
          title: 'A',
          artist: 'X',
          album: 'L1',
          year: 2024,
          duration: Duration(seconds: 100),
          artUrl: '',
          audioUrl: '',
          genre: 'Rock',
          composer: 'C1',
        ),
        const Track(
          id: 't2',
          title: 'B',
          artist: 'Y',
          album: 'L2',
          year: 2023,
          duration: Duration(seconds: 200),
          artUrl: '',
          audioUrl: '',
          genre: 'Jazz',
        ),
      ]);

      expect(svc.tracks.length, 2);
      expect(svc.artists.length, 2);
      expect(svc.albums.length, 2);
      expect(svc.genres.length, 2);
      expect(svc.composers.length, 1); // only t1 has composer
      expect(svc.years.length, 2); // 2024 and 2023
    });

    test('tracksByArtist returns matching tracks', () {
      svc.importCloudTracks([
        const Track(
          id: 't1',
          title: 'A',
          artist: 'X',
          album: 'L1',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: '',
        ),
        const Track(
          id: 't2',
          title: 'B',
          artist: 'X',
          album: 'L2',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: '',
        ),
        const Track(
          id: 't3',
          title: 'C',
          artist: 'Y',
          album: 'L3',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: '',
        ),
      ]);
      expect(svc.tracksByArtist('X').length, 2);
      expect(svc.tracksByArtist('Y').length, 1);
    });

    test('trackById returns null for unknown id', () {
      expect(svc.trackById('does-not-exist'), isNull);
    });

    test('markPlayed increments playCount and sets lastPlayedAt', () {
      svc.importCloudTracks([
        const Track(
          id: 't1',
          title: 'A',
          artist: 'X',
          album: 'L1',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: '',
        ),
      ]);
      expect(svc.trackById('t1')!.playCount, 0);
      svc.markPlayed('t1');
      expect(svc.trackById('t1')!.playCount, 1);
      expect(svc.trackById('t1')!.lastPlayedAt, isNotNull);
    });

    test('setFavorite flips isFavorite', () {
      svc.importCloudTracks([
        const Track(
          id: 't1',
          title: 'A',
          artist: 'X',
          album: 'L1',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: '',
        ),
      ]);
      expect(svc.trackById('t1')!.isFavorite, false);
      svc.setFavorite('t1', true);
      expect(svc.trackById('t1')!.isFavorite, true);
    });

    test('setRating clamps to 0..5', () {
      svc.importCloudTracks([
        const Track(
          id: 't1',
          title: 'A',
          artist: 'X',
          album: 'L1',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: '',
        ),
      ]);
      svc.setRating('t1', 99);
      expect(svc.trackById('t1')!.rating, 5);
      svc.setRating('t1', -3);
      expect(svc.trackById('t1')!.rating, 0);
    });

    test('favorites filter returns only favorited tracks', () {
      svc.importCloudTracks([
        const Track(
          id: 't1',
          title: 'A',
          artist: 'X',
          album: 'L1',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: '',
          isFavorite: true,
        ),
        const Track(
          id: 't2',
          title: 'B',
          artist: 'X',
          album: 'L2',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: '',
        ),
      ]);
      expect(svc.favorites.map((t) => t.id), ['t1']);
    });

    test('mostPlayed returns tracks ordered by playCount desc', () {
      svc.importCloudTracks([
        const Track(
          id: 't1',
          title: 'A',
          artist: 'X',
          album: 'L1',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: '',
          playCount: 5,
        ),
        const Track(
          id: 't2',
          title: 'B',
          artist: 'X',
          album: 'L2',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: '',
          playCount: 10,
        ),
        const Track(
          id: 't3',
          title: 'C',
          artist: 'X',
          album: 'L3',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: '',
          playCount: 1,
        ),
      ]);
      expect(svc.mostPlayed.first.id, 't2');
      expect(svc.mostPlayed[1].id, 't1');
    });
  });

  group('AudioFormat.fromPath', () {
    test('detects mp3', () {
      expect(AudioFormat.fromPath('/foo/bar.MP3'), AudioFormat.mp3);
    });
    test('detects flac', () {
      expect(AudioFormat.fromPath('song.flac'), AudioFormat.flac);
    });
    test('detects wav', () {
      expect(AudioFormat.fromPath('song.wav'), AudioFormat.wav);
    });
    test('detects m4a', () {
      expect(AudioFormat.fromPath('song.m4a'), AudioFormat.m4a);
    });
    test('detects opus', () {
      expect(AudioFormat.fromPath('song.opus'), AudioFormat.opus);
    });
    test('returns null for non-audio', () {
      expect(AudioFormat.fromPath('song.txt'), isNull);
    });
  });
}
