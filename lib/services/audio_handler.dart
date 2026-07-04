import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/models.dart';

/// AudioHandler that bridges [PlaybackService] to the platform's media-session
/// subsystem via `audio_service`.
///
/// Once wired (`AudioService.init()` → set as the player's audio source
/// handler), this unlocks:
///   - Android notification controls
///   - iOS lock-screen controls
///   - Bluetooth headset play/pause/next buttons
///   - Android Auto / CarPlay (basic media browser)
///   - macOS Now Playing
///   - Web Media Session API
class SonicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  SonicAudioHandler(this._player);

  final AudioPlayer _player;

  /// Wire the underlying player's streams to audio_service state.
  void init() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _handleCompleted();
    });
  }

  void _handleCompleted() {
    // Auto-advance or stop based on repeat mode — just_audio handles most of
    // this when ConcatenatingAudioSource is used; this is a safety net.
    if (_player.loopMode == LoopMode.off && _player.hasNext) {
      _player.seekToNext();
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    await _player.setShuffleModeEnabled(mode != AudioServiceShuffleMode.none);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    await _player.setLoopMode(switch (mode) {
      AudioServiceRepeatMode.none => LoopMode.off,
      AudioServiceRepeatMode.all => LoopMode.all,
      AudioServiceRepeatMode.one => LoopMode.one,
    });
  }

  /// Translate a just_audio PlaybackEvent into a MediaItem broadcast.
  void _broadcastState(PlaybackEvent event) {
    final state = PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queue: queue.value,
      shuffleMode: _player.shuffleModeEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      repeatMode: switch (_player.loopMode) {
        LoopMode.off => AudioServiceRepeatMode.none,
        LoopMode.all => AudioServiceRepeatMode.all,
        LoopMode.one => AudioServiceRepeatMode.one,
      },
      androidBitmapUri: _currentArtUri,
    );
    playbackState.add(state);
  }

  Uri? get _currentArtUri {
    final sequence = _player.sequenceState?.sequence;
    final idx = _player.currentIndex;
    if (sequence == null || idx == null || idx >= sequence.length) return null;
    final tag = sequence[idx].tag;
    if (tag is Track) {
      return tag.artUrl.isNotEmpty ? Uri.tryParse(tag.artUrl) : null;
    }
    return null;
  }

  /// Build the media queue broadcast from a list of [Track]s.
  void broadcastQueue(List<Track> tracks) {
    queue.add(tracks.map(_trackToMediaItem).toList());
  }

  /// Set the active track for notification display.
  void broadcastCurrentTrack(Track track) {
    mediaItem.add(_trackToMediaItem(track));
  }

  MediaItem _trackToMediaItem(Track t) => MediaItem(
        id: t.id,
        album: t.album,
        title: t.title,
        artist: t.artist,
        genre: t.genre,
        duration: t.duration,
        artUri: t.artUrl.isNotEmpty ? Uri.tryParse(t.artUrl) : null,
        playable: true,
        rating: t.rating > 0 ? Rating.newStarRating(null, 5, t.rating) : null,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Convenience: build a [ConcatenatingAudioSource] from tracks, tagging each
// source with its Track id so the handler can look up the active MediaItem.
// ─────────────────────────────────────────────────────────────────────────────
ConcatenatingAudioSource buildAudioSource(List<Track> tracks) {
  return ConcatenatingAudioSource(
    children: tracks
        .map((t) => AudioSource.uri(
              Uri.parse(t.audioUrl),
              tag: MediaItem(
                id: t.id,
                album: t.album,
                title: t.title,
                artist: t.artist,
                artUri: t.artUrl.isNotEmpty ? Uri.tryParse(t.artUrl) : null,
                duration: t.duration,
              ),
            ))
        .toList(),
    useLazyPreparation: true,
  );
}
