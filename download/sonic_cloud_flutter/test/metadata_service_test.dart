import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/models/models.dart';
import 'package:sonic_cloud/services/metadata_service.dart';

void main() {
  group('TrackMetadata', () {
    test('copyWith merges non-null fields from other', () {
      const base = TrackMetadata(
        title: 'Original Title',
        artist: 'Original Artist',
        album: 'Original Album',
        year: 2023,
      );
      const updates = TrackMetadata(title: 'New Title', year: 2024);
      final merged = base.copyWith(updates);
      expect(merged.title, 'New Title'); // overridden
      expect(merged.artist, 'Original Artist'); // kept
      expect(merged.album, 'Original Album'); // kept
      expect(merged.year, 2024); // overridden
    });

    test('copyWith with all-null other preserves everything', () {
      const base = TrackMetadata(
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        year: 2023,
      );
      final merged = base.copyWith(const TrackMetadata());
      expect(merged.title, 'Title');
      expect(merged.artist, 'Artist');
      expect(merged.album, 'Album');
      expect(merged.year, 2023);
    });

    test('fromTrack extracts fields from a Track', () {
      const track = Track(
        id: 't1',
        title: 'Song',
        artist: 'Band',
        albumArtist: 'Band',
        album: 'Album',
        genre: 'Rock',
        composer: 'Writer',
        year: 2024,
        trackNumber: 5,
        discNumber: 1,
        duration: Duration.zero,
        artUrl: '',
        audioUrl: '',
        embeddedLyrics: 'la la la',
      );
      final meta = TrackMetadata.fromTrack(track);
      expect(meta.title, 'Song');
      expect(meta.artist, 'Band');
      expect(meta.albumArtist, 'Band');
      expect(meta.album, 'Album');
      expect(meta.genre, 'Rock');
      expect(meta.composer, 'Writer');
      expect(meta.year, 2024);
      expect(meta.trackNumber, 5);
      expect(meta.discNumber, 1);
      expect(meta.lyrics, 'la la la');
    });

    test('fromTrack converts empty strings to null', () {
      const track = Track(
        id: 't1',
        title: 'Song',
        artist: 'Band',
        album: '',
        genre: '',
        composer: '',
        year: 0,
        duration: Duration.zero,
        artUrl: '',
        audioUrl: '',
      );
      final meta = TrackMetadata.fromTrack(track);
      expect(meta.album, isNull);
      expect(meta.genre, isNull);
      expect(meta.composer, isNull);
      expect(meta.year, isNull);
    });
  });

  group('MetadataService', () {
    test('readMetadata returns null for non-existent file', () async {
      final result = await MetadataService.instance.readMetadata(
        '/nonexistent/file.mp3',
      );
      expect(result, isNull);
    });

    test('writeMetadata returns false for non-existent file', () async {
      final result = await MetadataService.instance.writeMetadata(
        '/nonexistent/file.mp3',
        const TrackMetadata(title: 'Test'),
      );
      expect(result, isFalse);
    });

    test('batchEdit returns results for each file', () async {
      final results = await MetadataService.instance.batchEdit([
        '/file1.mp3',
        '/file2.mp3',
        '/file3.mp3',
      ], const TrackMetadata(artist: 'New Artist'));
      expect(results.length, 3);
      expect(results.values.every((v) => v == false), isTrue);
    });
  });
}
