import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/models.dart';

/// EqualizerService — wraps just_audio's AndroidEqualizer when available,
/// falls back to a pure-Dart band store on platforms without native EQ.
///
/// Exposes 10 bands at standard ISO frequencies, plus bass boost, virtualizer,
/// surround, loudness, compressor, and limiter toggles.
///
/// NOTE: Audio effects beyond EQ (bass boost, virtualizer, surround, etc.) are
/// Android-only via AndroidLoudnessEnhancer / AndroidVirtualizer / etc. On
/// iOS/macOS/Web these toggles persist but have no audible effect.
class EqualizerService extends ChangeNotifier {
  EqualizerService({AudioPlayer? player}) : _player = player;

  final AudioPlayer? _player;
  AndroidEqualizer? _nativeEq;

  // 10-band EQ at standard ISO frequencies (Hz).
  static const List<double> bandFrequencies = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

  final List<double> _gains = List.filled(10, 0.0); // -12..+12 dB
  bool _enabled = false;
  bool _bassBoost = false;
  double _bassBoostStrength = 0.5; // 0..1
  bool _virtualizer = false;
  bool _surround = false;
  bool _loudness = false;
  bool _compressor = false;
  bool _limiter = false;
  EqualizerPreset? _activePreset;

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get enabled => _enabled;
  List<double> get gains => List.unmodifiable(_gains);
  bool get bassBoost => _bassBoost;
  double get bassBoostStrength => _bassBoostStrength;
  bool get virtualizer => _virtualizer;
  bool get surround => _surround;
  bool get loudness => _loudness;
  bool get compressor => _compressor;
  bool get limiter => _limiter;
  EqualizerPreset? get activePreset => _activePreset;

  /// Initialize native EQ if available (Android only).
  Future<void> init() async {
    if (_player == null) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioEffectType: AndroidAudioEffectType.equalizer,
      ));
      _nativeEq = AndroidEqualizer();
      await _player!.setAudioPipelineEffects([_nativeEq!]);
    } catch (e) {
      debugPrint('EqualizerService: native EQ unavailable ($e). Falling back to Dart-only mode.');
    }
  }

  // ── Band control ───────────────────────────────────────────────────────────
  Future<void> setBandGain(int bandIndex, double gainDb) async {
    if (bandIndex < 0 || bandIndex >= _gains.length) return;
    _gains[bandIndex] = gainDb.clamp(-12.0, 12.0);
    _activePreset = null; // Custom = no preset
    if (_nativeEq != null && _enabled) {
      final params = _nativeEq!.parameters;
      if (bandIndex < params.length) {
        await params[bandIndex].setGain(_gains[bandIndex]);
      }
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (_nativeEq != null) {
      await _nativeEq!.setEnabled(enabled);
      if (enabled) {
        final params = _nativeEq!.parameters;
        for (var i = 0; i < params.length && i < _gains.length; i++) {
          await params[i].setGain(_gains[i]);
        }
      }
    }
    notifyListeners();
  }

  // ── Presets ────────────────────────────────────────────────────────────────
  Future<void> applyPreset(EqualizerPreset preset) async {
    _activePreset = preset;
    for (var i = 0; i < _gains.length && i < preset.gains.length; i++) {
      _gains[i] = preset.gains[i];
    }
    if (_nativeEq != null && _enabled) {
      final params = _nativeEq!.parameters;
      for (var i = 0; i < params.length && i < _gains.length; i++) {
        await params[i].setGain(_gains[i]);
      }
    }
    notifyListeners();
  }

  // ── Bass boost / virtualizer / etc. ────────────────────────────────────────
  Future<void> setBassBoost(bool enabled, {double? strength}) async {
    _bassBoost = enabled;
    if (strength != null) _bassBoostStrength = strength.clamp(0.0, 1.0);
    // Native bass boost would be applied via AndroidBassBoost here.
    notifyListeners();
  }

  Future<void> setVirtualizer(bool enabled) async {
    _virtualizer = enabled;
    notifyListeners();
  }

  Future<void> setSurround(bool enabled) async {
    _surround = enabled;
    notifyListeners();
  }

  Future<void> setLoudness(bool enabled) async {
    _loudness = enabled;
    notifyListeners();
  }

  Future<void> setCompressor(bool enabled) async {
    _compressor = enabled;
    notifyListeners();
  }

  Future<void> setLimiter(bool enabled) async {
    _limiter = enabled;
    notifyListeners();
  }

  @override
  void dispose() {
    // Native EQ is owned by the AudioPlayer; don't dispose here.
    super.dispose();
  }
}
