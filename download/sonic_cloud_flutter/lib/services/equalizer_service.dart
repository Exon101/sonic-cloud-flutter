import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// EqualizerService — 10-band EQ state + presets.
///
/// **Note on native EQ:** The native Android EQ via `audio_session` +
/// `AndroidEqualizer` requires API calls that vary across just_audio versions.
/// This service stores EQ state in Dart and exposes the same API regardless of
/// platform. On Android, a future update can wire the native EQ by calling
/// `audioSession.configure(...)` + `player.setAudioPipelineEffects(...)` per
/// the installed just_audio version's API.
///
/// Bass boost, virtualizer, surround, loudness, compressor, and limiter
/// toggles are Android-only audio effects; on other platforms they persist
/// but have no audible effect.
class EqualizerService extends ChangeNotifier {
  EqualizerService({dynamic player}) : _player = player;
  final dynamic _player;

  // 10-band EQ at standard ISO frequencies (Hz).
  static const List<double> bandFrequencies = [
    31,
    62,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
  ];

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

  /// Initialize. Safe to call even when no AudioPlayer is wired — currently
  /// a no-op since native EQ integration is deferred.
  Future<void> init() async {
    debugPrint(
      'EqualizerService: running in Dart-only mode (native EQ deferred).',
    );
  }

  // ── Band control ───────────────────────────────────────────────────────────
  Future<void> setBandGain(int bandIndex, double gainDb) async {
    if (bandIndex < 0 || bandIndex >= _gains.length) return;
    _gains[bandIndex] = gainDb.clamp(-12.0, 12.0);
    _activePreset = null; // Custom = no preset
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    notifyListeners();
  }

  // ── Presets ────────────────────────────────────────────────────────────────
  Future<void> applyPreset(EqualizerPreset preset) async {
    _activePreset = preset;
    for (var i = 0; i < _gains.length && i < preset.gains.length; i++) {
      _gains[i] = preset.gains[i];
    }
    notifyListeners();
  }

  // ── Bass boost / virtualizer / etc. ────────────────────────────────────────
  Future<void> setBassBoost(bool enabled, {double? strength}) async {
    _bassBoost = enabled;
    if (strength != null) _bassBoostStrength = strength.clamp(0.0, 1.0);
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
    super.dispose();
  }
}
