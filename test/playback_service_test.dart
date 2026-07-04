import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sonic_cloud/services/playback_service.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  late _MockAudioPlayer mockPlayer;
  late PlaybackService service;

  setUp(() {
    mockPlayer = _MockAudioPlayer();
    // Stream stubs — return empty streams so listeners don't fire in tests.
    when(
      () => mockPlayer.playerStateStream,
    ).thenAnswer((_) => const Stream<PlayerState>.empty());
    when(
      () => mockPlayer.positionStream,
    ).thenAnswer((_) => const Stream<Duration>.empty());
    when(
      () => mockPlayer.durationStream,
    ).thenAnswer((_) => const Stream<Duration>.empty());
    when(() => mockPlayer.duration).thenReturn(const Duration(seconds: 30));
    when(() => mockPlayer.setUrl(any())).thenAnswer((_) async => null);
    when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
    when(() => mockPlayer.play()).thenAnswer((_) async {});
    when(() => mockPlayer.pause()).thenAnswer((_) async {});
    when(() => mockPlayer.dispose()).thenAnswer((_) async {});

    service = PlaybackService(player: mockPlayer);
  });

  tearDown(() => service.dispose());

  group('PlaybackService', () {
    test('initial state: not playing, zero position, zero duration', () {
      expect(service.isPlaying, false);
      expect(service.position, Duration.zero);
      expect(service.duration, Duration.zero);
      expect(service.progress, 0);
      expect(service.currentUrl, isNull);
    });

    test('load() sets currentUrl and calls setUrl on the player', () async {
      await service.load('asset:///assets/audio/sample_track.wav');
      verify(
        () => mockPlayer.setUrl('asset:///assets/audio/sample_track.wav'),
      ).called(1);
      expect(service.currentUrl, 'asset:///assets/audio/sample_track.wav');
    });

    test(
      'load() is idempotent for the same URL — does not call setUrl twice',
      () async {
        const url = 'asset:///assets/audio/sample_track.wav';
        await service.load(url);
        await service.load(url);
        verify(() => mockPlayer.setUrl(url)).called(1);
      },
    );

    test('togglePlayPause calls play() when not playing', () async {
      await service.togglePlayPause();
      verify(() => mockPlayer.play()).called(1);
      verifyNever(() => mockPlayer.pause());
    });

    test(
      'seekToProgress computes the right Duration from a fraction',
      () async {
        // Stub duration so progress math works.
        when(
          () => mockPlayer.duration,
        ).thenReturn(const Duration(seconds: 100));
        await service.load('asset:///assets/audio/sample_track.wav');
        // Force duration to be set in the service.
        // (The duration stream is empty, so we trigger via the getter.)
        // We instead test seekToProgress directly with a known duration.

        // Re-stub duration after load to simulate the player reporting it.
        when(
          () => mockPlayer.duration,
        ).thenReturn(const Duration(seconds: 100));
        // Trigger duration stream by reloading.
        await service.load('asset:///assets/audio/sample_track.wav');

        await service.seekToProgress(0.5);
        final captured = verify(() => mockPlayer.seek(captureAny())).captured;
        expect(captured.last, const Duration(seconds: 50));
      },
    );

    test('seekToProgress is a no-op when duration is zero', () async {
      when(() => mockPlayer.duration).thenReturn(Duration.zero);
      await service.load('asset:///assets/audio/sample_track.wav');
      // Clear any prior seeks from load() itself.
      reset(mockPlayer.seek);
      when(() => mockPlayer.seek(any())).thenAnswer((_) async {});

      await service.seekToProgress(0.5);
      verifyNever(() => mockPlayer.seek(any()));
    });
  });
}
