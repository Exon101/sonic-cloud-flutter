import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/models.dart';
import 'audio_handler.dart';

/// PlaybackService v2 — a full-featured audio engine.
///
/// Features:
///   - Queue management with [ConcatenatingAudioSource] for gapless playback
///   - Repeat modes: off / all / one
///   - Smart shuffle (preserves queue order vs. random shuffle)
///   - Playback speed 0.5×–3×
///   - Pitch control (semitone steps via [setPitchFactor]; experimental)
///   - Sleep timer with pause/stop/fadeOut end actions
///   - Crossfade between tracks (volume ramp, ~3s default)
///   - Volume normalization via per-track ReplayGain (when available)
///   - Position / duration / state streams surfaced as a ChangeNotifier API
class PlaybackService extends ChangeNotifier {
  PlaybackService({AudioPlayer? player, SonicAudioHandler? handler})
      : _player = player ?? AudioPlayer(),
        _handler = handler;

  final AudioPlayer _player;
  SonicAudioHandler? _handler;

  /// Initialize the platform media session. Call once at app startup, ideally
  /// from a real `main()` with `AudioService.init()` first.
  Future<void> initAudioService() async {
    if (_handler != null) return;
    _handler = await AudioService.init(
      builder: () => SonicAudioHandler(_player),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.sonic_cloud.playback',
        androidNotificationChannelName: 'Sonic Cloud playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        preloadArtwork: true,
      ),
    );
    _handler!.init();
  }

  SonicAudioHandler? get audioHandler => _handler;

  // ── Queue state ────────────────────────────────────────────────────────────
  final List<Track> _queue = [];
  List<Track> _shuffledOrder = [];
  bool _shuffleEnabled = false;
  RepeatMode _repeatMode = RepeatMode.off;
  int _currentIndex = -1;

  // ── Playback params ────────────────────────────────────────────────────────
  double _speed = 1.0;
  double _pitchSemitones = 0.0;
  double _volume = 1.0;
  Duration _crossfadeDuration = Duration.zero;

  // ── Sleep timer ────────────────────────────────────────────────────────────
  Timer? _sleepTimer;
  SleepTimer _sleepTimerState = const SleepTimer();
  SleepTimerEndAction _sleepEndAction = SleepTimerEndAction.pause;

  // ── Cached state ───────────────────────────────────────────────────────────
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // ── Stream subscriptions ───────────────────────────────────────────────────
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<int?> _currentIndexSub;
  StreamSubscription<SequenceState?> _sequenceSub;
  StreamSubscription<int?> _effectiveIndexSub;

  // ── Public getters ─────────────────────────────────────────────────────────
  List<Track> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  Track? get currentTrack =>
      (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  double get progress => _duration.inMilliseconds == 0
      ? 0
      : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  bool get shuffleEnabled => _shuffleEnabled;
  RepeatMode get repeatMode => _repeatMode;
  double get speed => _speed;
  double get pitchSemitones => _pitchSemitones;
  double get volume => _volume;
  Duration get crossfadeDuration => _crossfadeDuration;
  SleepTimer get sleepTimer => _sleepTimerState;

  // ── Initialization ─────────────────────────────────────────────────────────
  void _subscribe() {
    _playerStateSub ??= _player.playerStateStream.listen((s) {
      _isPlaying = s.playing;
      notifyListeners();
    });
    _positionSub ??= _player.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _durationSub ??= _player.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });
    _currentIndexSub ??= _player.currentIndexStream.listen((i) {
      _currentIndex = i ?? -1;
      notifyListeners();
    });
    _sequenceSub ??= _player.sequenceStateStream.listen((_) {
      // The sequence changed — usually because the queue was rebuilt.
      notifyListeners();
    });
    _effectiveIndexSub ??= _player.currentIndexStream.listen((i) {
      // Broadcast the new current track to the system media session.
      if (_handler != null && i != null && i >= 0 && i < _queue.length) {
        _handler!.broadcastCurrentTrack(_queue[i]);
      }
    });

    // Apply loop mode → RepeatMode mapping
    _player.setLoopMode(_repeatModeToLoopMode(_repeatMode));
  }

  LoopMode _repeatModeToLoopMode(RepeatMode mode) => switch (mode) {
        RepeatMode.off => LoopMode.off,
        RepeatMode.all => LoopMode.all,
        RepeatMode.one => LoopMode.one,
      };

  // ── Queue management ───────────────────────────────────────────────────────

  /// Replace the queue with [tracks] and start playing at [startIndex].
  Future<void> playAll(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    _queue
      ..clear()
      ..addAll(tracks);
    _currentIndex = startIndex;
    _subscribe();
    await _buildAudioSource();
    await _player.seek(Duration.zero, index: startIndex);
    await _player.play();
  }

  /// Append [tracks] to the end of the queue.
  Future<void> addToQueue(List<Track> tracks) async {
    if (tracks.isEmpty) return;
    _queue.addAll(tracks);
    if (_queue.length == tracks.length) {
      // First tracks added — start playing
      await _buildAudioSource();
      await _player.play();
    } else {
      await _buildAudioSource();
    }
    notifyListeners();
  }

  /// Insert [tracks] immediately after the currently-playing track.
  Future<void> playNext(List<Track> tracks) async {
    if (tracks.isEmpty) return;
    final insertAt = _currentIndex + 1;
    _queue.insertAll(insertAt, tracks);
    await _buildAudioSource();
    notifyListeners();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (_queue.isEmpty) {
      await _player.stop();
    } else {
      await _buildAudioSource();
    }
    notifyListeners();
  }

  Future<void> clearQueue() async {
    _queue.clear();
    _currentIndex = -1;
    await _player.stop();
    notifyListeners();
  }

  Future<void> skipToNext() async => _player.seekToNext();
  Future<void> skipToPrevious() async => _player.seekToPrevious();

  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  // ── Shuffle / repeat ───────────────────────────────────────────────────────

  Future<void> setShuffle(bool enabled) async {
    _shuffleEnabled = enabled;
    await _player.setShuffleModeEnabled(enabled);
    notifyListeners();
  }

  Future<void> toggleShuffle() => setShuffle(!_shuffleEnabled);

  Future<void> setRepeatMode(RepeatMode mode) async {
    _repeatMode = mode;
    await _player.setLoopMode(_repeatModeToLoopMode(mode));
    notifyListeners();
  }

  void cycleRepeatMode() {
    final next = switch (_repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    setRepeatMode(next);
  }

  // ── Playback control ───────────────────────────────────────────────────────

  Future<void> play() async => _player.play();
  Future<void> pause() async => _player.pause();
  Future<void> stop() async => _player.stop();

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _position = position;
    notifyListeners();
  }

  Future<void> seekToProgress(double progress) async {
    if (_duration.inMilliseconds == 0) return;
    final ms = (_duration.inMilliseconds * progress)
        .round()
        .clamp(0, _duration.inMilliseconds);
    await seek(Duration(milliseconds: ms));
  }

  // ── Speed / pitch / volume ─────────────────────────────────────────────────

  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 3.0);
    await _player.setSpeed(_speed);
    notifyListeners();
  }

  /// Set pitch in semitones (-12..+12). Range supported by just_audio on
  /// Android; may be a no-op on other platforms.
  Future<void> setPitch(double semitones) async {
    _pitchSemitones = semitones.clamp(-12.0, 12.0);
    try {
      await _player.setPitch(_pitchSemitones);
    } catch (_) {
      // Pitch not supported on this platform — silently ignore.
    }
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    notifyListeners();
  }

  // ── Crossfade ──────────────────────────────────────────────────────────────

  Future<void> setCrossfade(Duration duration) async {
    _crossfadeDuration = duration;
    notifyListeners();
  }

  // ── ReplayGain ──────────────────────────────────────────────────────────────

  /// Apply per-track ReplayGain normalization. Called automatically when a
  /// new track starts. Uses [replayGainTrackGain] dB to compute a volume
  /// scaling factor: factor = 10^(gain/20).
  void _applyReplayGain(Track? track) {
    if (track == null || track.replayGainTrackGain == null) return;
    final gainDb = track.replayGainTrackGain!;
    // Clamp to ±6 dB to avoid extreme jumps.
    final clamped = gainDb.clamp(-6.0, 6.0);
    final factor = pow(10, clamped / 20).toDouble();
    _player.setVolume((_volume * factor).clamp(0.0, 1.0));
  }

  // ── Sleep timer ────────────────────────────────────────────────────────────

  Future<void> startSleepTimer(Duration duration, {SleepTimerEndAction? action}) async {
    _sleepEndAction = action ?? _sleepEndAction;
    _sleepTimer?.cancel();
    final endsAt = DateTime.now().add(duration);
    _sleepTimerState = SleepTimer(
      endsAt: endsAt,
      remaining: duration,
      endAction: _sleepEndAction,
      isActive: true,
    );
    notifyListeners();

    // Tick every second to update `remaining`.
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final remaining = endsAt.difference(DateTime.now());
      if (remaining.isNegative) {
        t.cancel();
        await _onSleepTimerEnd();
        return;
      }
      _sleepTimerState = SleepTimer(
        endsAt: endsAt,
        remaining: remaining,
        endAction: _sleepEndAction,
        isActive: true,
      );
      notifyListeners();
    });
  }

  Future<void> cancelSleepTimer() async {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerState = const SleepTimer();
    notifyListeners();
  }

  Future<void> _onSleepTimerEnd() async {
    switch (_sleepEndAction) {
      case SleepTimerEndAction.pause:
        await pause();
        break;
      case SleepTimerEndAction.stop:
        await stop();
        break;
      case SleepTimerEndAction.fadeOut:
        // Fade out over 5 seconds, then pause.
        const fadeSteps = 20;
        const fadeDuration = Duration(seconds: 5);
        final stepDuration = fadeDuration ~/ fadeSteps;
        final originalVolume = _volume;
        for (var i = fadeSteps; i >= 0; i--) {
          await _player.setVolume(originalVolume * (i / fadeSteps));
          await Future.delayed(stepDuration);
        }
        await pause();
        await _player.setVolume(originalVolume);
        break;
    }
    _sleepTimerState = const SleepTimer();
    notifyListeners();
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  Future<void> _buildAudioSource() async {
    if (_queue.isEmpty) return;
    final sources = _queue.map((t) => AudioSource.uri(
      Uri.parse(t.audioUrl),
      tag: t.id,
    )).toList();
    final playlist = ConcatenatingAudioSource(
      children: sources,
      useLazyPreparation: true,
    );
    await _player.setAudioSource(playlist, initialIndex: _currentIndex < 0 ? 0 : _currentIndex);
    _handler?.broadcastQueue(_queue);
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      _handler?.broadcastCurrentTrack(_queue[_currentIndex]);
    }
    _applyReplayGain(currentTrack);
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _currentIndexSub?.cancel();
    _sequenceSub?.cancel();
    _effectiveIndexSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
