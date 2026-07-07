import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/models/models.dart';
import 'package:sonic_cloud/services/playlist_service.dart';

const _tracks = <Track>[
  Track(
    id: 't1',
    title: 'A',
    artist: 'X',
    album: 'L1',
    year: 2024,
    duration: Duration(seconds: 100),
    artUrl: '',
    audioUrl: '',
    genre: 'Rock',
    playCount: 10,
    isFavorite: true,
  ),
  Track(
    id: 't2',
    title: 'B',
    artist: 'Y',
    album: 'L2',
    year: 2023,
    duration: Duration(seconds: 100),
    artUrl: '',
    audioUrl: '',
    genre: 'Jazz',
    playCount: 0,
  ),
  Track(
    id: 't3',
    title: 'C',
    artist: 'X',
    album: 'L1',
    year: 2024,
    duration: Duration(seconds: 100),
    artUrl: '',
    audioUrl: '',
    genre: 'Rock',
    playCount: 5,
  ),
];

void main() {
  group('SmartPlaylistRule', () {
    test('equals operator matches exact value', () {
      const rule = SmartPlaylistRule(
        field: SmartPlaylistField.artist,
        op: SmartPlaylistOperator.equals,
        value: 'X',
      );
      expect(rule.matches(_tracks[0]), true); // artist X
      expect(rule.matches(_tracks[1]), false); // artist Y
    });

    test('contains operator matches substring', () {
      const rule = SmartPlaylistRule(
        field: SmartPlaylistField.genre,
        op: SmartPlaylistOperator.contains,
        value: 'jaz',
      );
      expect(rule.matches(_tracks[1]), true);
      expect(rule.matches(_tracks[0]), false);
    });

    test('greaterThan on playCount', () {
      const rule = SmartPlaylistRule(
        field: SmartPlaylistField.playCount,
        op: SmartPlaylistOperator.greaterThan,
        value: '5',
      );
      expect(rule.matches(_tracks[0]), true); // 10
      expect(rule.matches(_tracks[2]), false); // 5 (not > 5)
      expect(rule.matches(_tracks[1]), false); // 0
    });

    test('lessThan on playCount', () {
      const rule = SmartPlaylistRule(
        field: SmartPlaylistField.playCount,
        op: SmartPlaylistOperator.lessThan,
        value: '5',
      );
      expect(rule.matches(_tracks[1]), true); // 0
      expect(rule.matches(_tracks[2]), false); // 5
    });

    test('notPlayed matches playCount==0', () {
      const rule = SmartPlaylistRule(
        field: SmartPlaylistField.playCount,
        op: SmartPlaylistOperator.notPlayed,
        value: '',
      );
      expect(rule.matches(_tracks[1]), true);
      expect(rule.matches(_tracks[0]), false);
    });

    test('mostPlayed matches playCount>0', () {
      const rule = SmartPlaylistRule(
        field: SmartPlaylistField.playCount,
        op: SmartPlaylistOperator.mostPlayed,
        value: '',
      );
      expect(rule.matches(_tracks[0]), true);
      expect(rule.matches(_tracks[1]), false);
    });
  });

  group('PlaylistService', () {
    late PlaylistService svc;
    setUp(() => svc = PlaylistService());

    test('createPlaylist returns a manual playlist with a UUID id', () {
      final pl = svc.createPlaylist('My Playlist');
      expect(pl.kind, PlaylistKind.manual);
      expect(pl.name, 'My Playlist');
      expect(pl.id.length, greaterThan(0));
      expect(svc.playlists, contains(pl));
    });

    test('addToPlaylist appends track ids', () async {
      final pl = svc.createPlaylist('P');
      await svc.addToPlaylist(pl.id, ['t1', 't2']);
      final updated = svc.byId(pl.id)!;
      expect(updated.trackIds, ['t1', 't2']);
    });

    test('removeFromPlaylist removes given ids', () async {
      final pl = svc.createPlaylist('P');
      await svc.addToPlaylist(pl.id, ['t1', 't2', 't3']);
      await svc.removeFromPlaylist(pl.id, ['t2']);
      expect(svc.byId(pl.id)!.trackIds, ['t1', 't3']);
    });

    test('deletePlaylist removes the playlist', () async {
      final pl = svc.createPlaylist('P');
      await svc.deletePlaylist(pl.id);
      expect(svc.byId(pl.id), isNull);
    });

    test('createSmartPlaylist stores rules', () {
      const rules = [
        SmartPlaylistRule(
          field: SmartPlaylistField.genre,
          op: SmartPlaylistOperator.equals,
          value: 'Rock',
        ),
      ];
      final pl = svc.createSmartPlaylist('Rock tracks', rules: rules);
      expect(pl.kind, PlaylistKind.smart);
      expect(pl.rules.length, 1);
    });

    test('evaluateSmartPlaylist returns ids of tracks matching all rules', () {
      const rules = [
        SmartPlaylistRule(
          field: SmartPlaylistField.genre,
          op: SmartPlaylistOperator.equals,
          value: 'Rock',
        ),
        SmartPlaylistRule(
          field: SmartPlaylistField.artist,
          op: SmartPlaylistOperator.equals,
          value: 'X',
        ),
      ];
      final pl = svc.createSmartPlaylist('X rock tracks', rules: rules);
      final ids = svc.evaluateSmartPlaylist(pl, _tracks);
      expect(ids, containsAll(['t1', 't3']));
      expect(ids, isNot(contains('t2')));
    });

    test('autoPlaylist.favorites returns only favorited tracks', () {
      final pl = svc.autoPlaylist(AutoPlaylistKind.favorites, _tracks);
      expect(pl.trackIds, ['t1']);
    });

    test('autoPlaylist.mostPlayed orders by playCount desc', () {
      final pl = svc.autoPlaylist(AutoPlaylistKind.mostPlayed, _tracks);
      // t1 (10) > t3 (5) > t2 (0)
      expect(pl.trackIds.first, 't1');
    });

    test('autoPlaylist.neverPlayed returns playCount==0 tracks', () {
      final pl = svc.autoPlaylist(AutoPlaylistKind.neverPlayed, _tracks);
      expect(pl.trackIds, ['t2']);
    });
  });
}
