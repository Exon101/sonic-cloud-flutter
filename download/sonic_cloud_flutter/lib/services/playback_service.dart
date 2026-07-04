import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// A thin wrapper around [AudioPlayer] from `just_audio`.
///
/// Why a wrapper:
///   - Exposes a single shared player instance across the app (so the bottom
///     nav and Now Playing screen stay in sync).
///   - Surfaces a simple [ChangeNotifier] API so widgets don't need to combine
///     multiple streams themselves.
///   - Hides `just_audio` from the rest of the code, which makes the widget
///     tree easy to test (the widget tests inject a fake playback service).
///
/// In production this would also wire up `audio_service` for lock-screen
/// controls and media notifications — that's intentionally left out here to
/// keep the demo minimal.
class PlaybackService extends ChangeNotifier {
  PlaybackService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// The currently loaded track URL (audio source).
  String? _currentUrl;
  String? get currentUrl => _currentUrl;

  /// Whether the player is actively playing (not paused / not stopped).
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  /// Current playback position and total duration.
  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  /// 0..1 — convenience getter for progress bars.
  double get progress {
    if (_duration.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  bool _initialized = false;

  /// Loads an audio source and prepares the player. Safe to call repeatedly
  /// with the same URL — won't reload.
  Future<void> load(String url, {Duration initialPosition = Duration.zero}) async {
    if (_currentUrl == url && _initialized) {
      await seek(initialPosition);
      return;
    }
    _currentUrl = url;
    _initialized = false;
    _subscribe();
    try {
      await _player.setUrl(url);
      await _player.seek(initialPosition);
      _duration = _player.duration ?? Duration.zero;
      _initialized = true;
      notifyListeners();
    } catch (e) {
      // Network / codec errors shouldn't crash the UI. In production we'd
      // surface a snackbar; here we just log.
      debugPrint('PlaybackService.load failed: $e');
    }
  }

  void _subscribe() {
    _playerStateSub ??= _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });
    _positionSub ??= _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _durationSub ??= _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });
  }

  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      debugPrint('PlaybackService.play failed: $e');
    }
  }

  Future<void> pause() async => await _player.pause();

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

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
