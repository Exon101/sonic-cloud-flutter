import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sonic_cloud/models/models.dart';
import 'package:sonic_cloud/services/playback_service.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  late _MockAudioPlayer mockPlayer;
  late PlaybackService svc;

  setUp(() {
    mockPlayer = _MockAudioPlayer();
    when(
      () => mockPlayer.playerStateStream,
    ).thenAnswer((_) => const Stream<PlayerState>.empty());
    when(
      () => mockPlayer.positionStream,
    ).thenAnswer((_) => const Stream<Duration>.empty());
    when(
      () => mockPlayer.durationStream,
    ).thenAnswer((_) => const Stream<Duration?>.empty());
    when(
      () => mockPlayer.currentIndexStream,
    ).thenAnswer((_) => const Stream<int?>.empty());
    when(
      () => mockPlayer.sequenceStateStream,
    ).thenAnswer((_) => const Stream<SequenceState?>.empty());
    when(() => mockPlayer.duration).thenReturn(const Duration(seconds: 30));
    when(
      () => mockPlayer.setAudioSource(
        any(),
        initialIndex: any(named: 'initialIndex'),
      ),
    ).thenAnswer((_) async => const Duration(seconds: 30));
    when(() => mockPlayer.play()).thenAnswer((_) async {});
    when(() => mockPlayer.pause()).thenAnswer((_) async {});
    when(() => mockPlayer.stop()).thenAnswer((_) async {});
    when(
      () => mockPlayer.seek(any(), index: any(named: 'index')),
    ).thenAnswer((_) async {});
    when(() => mockPlayer.setSpeed(any())).thenAnswer((_) async {});
    when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});
    when(() => mockPlayer.setLoopMode(any())).thenAnswer((_) async {});
    when(
      () => mockPlayer.setShuffleModeEnabled(any()),
    ).thenAnswer((_) async {});
    when(() => mockPlayer.dispose()).thenAnswer((_) async {});

    svc = PlaybackService(player: mockPlayer);
  });

  tearDown(() => svc.dispose());

  group('PlaybackService smart shuffle', () {
    test('effectiveQueue returns original queue when shuffle is off', () {
      expect(svc.shuffleEnabled, isFalse);
      expect(svc.effectiveQueue, isEmpty);
    });

    test(
      'setShuffle(true) enables shuffle and populates effectiveQueue',
      () async {
        await svc.playAll([
          const Track(
            id: 't1',
            title: 'A',
            artist: 'X',
            album: 'L',
            year: 2024,
            duration: Duration.zero,
            artUrl: '',
            audioUrl: 'asset:///a.wav',
          ),
          const Track(
            id: 't2',
            title: 'B',
            artist: 'Y',
            album: 'L',
            year: 2024,
            duration: Duration.zero,
            artUrl: '',
            audioUrl: 'asset:///b.wav',
          ),
        ]);
        await svc.setShuffle(true);
        expect(svc.shuffleEnabled, isTrue);
        expect(svc.effectiveQueue.length, 2);
        // Both tracks should be present (order may vary)
        expect(svc.effectiveQueue.map((t) => t.id).toSet(), {'t1', 't2'});
      },
    );

    test('setShuffle(false) restores original order', () async {
      await svc.playAll([
        const Track(
          id: 't1',
          title: 'A',
          artist: 'X',
          album: 'L',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: 'asset:///a.wav',
        ),
        const Track(
          id: 't2',
          title: 'B',
          artist: 'Y',
          album: 'L',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: 'asset:///b.wav',
        ),
      ]);
      await svc.setShuffle(true);
      await svc.setShuffle(false);
      expect(svc.shuffleEnabled, isFalse);
      expect(svc.effectiveQueue.first.id, 't1');
      expect(svc.effectiveQueue.last.id, 't2');
    });

    test('toggleShuffle flips state', () async {
      expect(svc.shuffleEnabled, isFalse);
      await svc.toggleShuffle();
      expect(svc.shuffleEnabled, isTrue);
      await svc.toggleShuffle();
      expect(svc.shuffleEnabled, isFalse);
    });
  });

  group('PlaybackService queue management', () {
    test('clearQueue empties the queue and resets index', () async {
      await svc.clearQueue();
      expect(svc.queue, isEmpty);
      expect(svc.currentIndex, -1);
    });

    test('addToQueue with empty list is a no-op', () async {
      await svc.addToQueue([]);
      expect(svc.queue, isEmpty);
    });

    test('playNext inserts after current track', () async {
      await svc.playAll([
        const Track(
          id: 't1',
          title: 'A',
          artist: 'X',
          album: 'L',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: 'asset:///a.wav',
        ),
        const Track(
          id: 't2',
          title: 'B',
          artist: 'Y',
          album: 'L',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: 'asset:///b.wav',
        ),
      ]);
      await svc.playNext([
        const Track(
          id: 't3',
          title: 'C',
          artist: 'Z',
          album: 'L',
          year: 2024,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: 'asset:///c.wav',
        ),
      ]);
      expect(svc.queue.length, 3);
      expect(svc.queue[1].id, 't3'); // inserted after current (index 0)
    });
  });

  group('PlaybackService playback params', () {
    test('setSpeed clamps to 0.5..3.0', () async {
      await svc.setSpeed(0.1);
      expect(svc.speed, 0.5);
      await svc.setSpeed(5.0);
      expect(svc.speed, 3.0);
      await svc.setSpeed(1.5);
      expect(svc.speed, 1.5);
    });

    test('setVolume clamps to 0..1', () async {
      await svc.setVolume(-0.5);
      expect(svc.volume, 0.0);
      await svc.setVolume(2.0);
      expect(svc.volume, 1.0);
      await svc.setVolume(0.7);
      expect(svc.volume, 0.7);
    });
  });
}
