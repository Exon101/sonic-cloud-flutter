import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/models/models.dart';
import 'package:sonic_cloud/providers/cloud_providers.dart';
import 'package:sonic_cloud/services/library_service.dart';
import 'package:sonic_cloud/services/universal_library_service.dart';

const _localTracks = [
  Track(
    id: 'local1', title: 'Local A', artist: 'X', album: 'L1', year: 2024,
    duration: Duration.zero, artUrl: '', audioUrl: 'file:///a.mp3',
  ),
  Track(
    id: 'local2', title: 'Local B', artist: 'Y', album: 'L2', year: 2023,
    duration: Duration.zero, artUrl: '', audioUrl: 'file:///b.mp3',
  ),
];

const _cloudTracks = [
  Track(
    id: 'cloud1', title: 'Cloud A', artist: 'Z', album: 'C1', year: 2024,
    duration: Duration.zero, artUrl: '', audioUrl: 'https://cloud/a.mp3',
    isCloudOnly: true,
  ),
];

void main() {
  group('UniversalLibraryService', () {
    late LibraryService local;
    late UniversalLibraryService universal;

    setUp(() {
      local = LibraryService();
      local.importCloudTracks(_localTracks);
      universal = UniversalLibraryService(local, []);
    });

    test('allTracks includes only local when no cloud providers connected', () {
      expect(universal.allTracks.length, 2);
      expect(universal.allTracks.map((t) => t.id), containsAll(['local1', 'local2']));
    });

    test('trackById finds local tracks', () {
      expect(universal.trackById('local1')?.title, 'Local A');
      expect(universal.trackById('nonexistent'), isNull);
    });

    test('allArtists aggregates across all sources', () {
      expect(universal.allArtists, containsAll(['X', 'Y']));
    });

    test('allAlbums aggregates across all sources', () {
      expect(universal.allAlbums, containsAll(['L1', 'L2']));
    });

    test('setEnabled(false) hides a source from allTracks', () {
      universal.setEnabled('local', false);
      expect(universal.allTracks, isEmpty);
    });

    test('setEnabled(true) re-shows a source', () {
      universal.setEnabled('local', false);
      universal.setEnabled('local', true);
      expect(universal.allTracks.length, 2);
    });

    test('trackCountBySource reports local count', () {
      expect(universal.trackCountBySource['local'], 2);
    });

    test('sourceLabel returns human-readable label for local', () {
      expect(universal.sourceLabel('local'), 'Phone / Local');
    });

    test('sourceLabel returns provider displayName when provider is registered', () {
      final provider = GoogleDriveProvider(const CloudProviderConfig(
        id: 'gdrive1',
        kind: CloudProviderKind.googleDrive,
        displayName: 'My Drive',
      ));
      universal.addCloudProvider(provider);
      expect(universal.sourceLabel('gdrive1'), 'My Drive');
    });

    test('addCloudProvider enables the new source', () {
      final provider = DropboxProvider(const CloudProviderConfig(
        id: 'dropbox1',
        kind: CloudProviderKind.dropbox,
        displayName: 'Dropbox',
      ));
      universal.addCloudProvider(provider);
      expect(universal.isEnabled('dropbox1'), true);
    });
  });
}
