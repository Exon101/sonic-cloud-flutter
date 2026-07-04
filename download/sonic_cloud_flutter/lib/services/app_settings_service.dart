import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// AppSettingsService — persists user preferences via SharedPreferences.
///
/// Holds: theme mode, accent color, repeat/shuffle defaults, crossfade
/// duration, EQ preset, sleep timer end action, replay gain enabled, etc.
class AppSettingsService extends ChangeNotifier {
  AppSettingsService(this._prefs);
  final SharedPreferences _prefs;

  // ── Theme ──────────────────────────────────────────────────────────────────
  ThemeModePreference get themeMode =>
      ThemeModePreference.values[(_prefs.getInt('themeMode') ?? 0)];
  Future<void> setThemeMode(ThemeModePreference mode) async {
    await _prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  /// Custom accent color (hex), or null for default.
  int? get accentColorHex => _prefs.getInt('accentColor');
  Color? get accentColor =>
      accentColorHex == null ? null : Color(accentColorHex!);
  Future<void> setAccentColor(Color? color) async {
    if (color == null) {
      await _prefs.remove('accentColor');
    } else {
      await _prefs.setInt('accentColor', color.value);
    }
    notifyListeners();
  }

  // ── Playback defaults ──────────────────────────────────────────────────────
  RepeatMode get defaultRepeatMode =>
      RepeatMode.values[(_prefs.getInt('repeatMode') ?? 0)];
  Future<void> setDefaultRepeatMode(RepeatMode mode) async {
    await _prefs.setInt('repeatMode', mode.index);
    notifyListeners();
  }

  bool get defaultShuffle => _prefs.getBool('shuffle') ?? false;
  Future<void> setDefaultShuffle(bool v) async {
    await _prefs.setBool('shuffle', v);
    notifyListeners();
  }

  double get defaultSpeed => _prefs.getDouble('speed') ?? 1.0;
  Future<void> setDefaultSpeed(double v) async {
    await _prefs.setDouble('speed', v);
    notifyListeners();
  }

  Duration get crossfadeDuration =>
      Duration(milliseconds: _prefs.getInt('crossfadeMs') ?? 0);
  Future<void> setCrossfadeDuration(Duration d) async {
    await _prefs.setInt('crossfadeMs', d.inMilliseconds);
    notifyListeners();
  }

  bool get replayGainEnabled => _prefs.getBool('replayGain') ?? true;
  Future<void> setReplayGainEnabled(bool v) async {
    await _prefs.setBool('replayGain', v);
    notifyListeners();
  }

  bool get volumeNormalizationEnabled => _prefs.getBool('volumeNorm') ?? true;
  Future<void> setVolumeNormalizationEnabled(bool v) async {
    await _prefs.setBool('volumeNorm', v);
    notifyListeners();
  }

  // ── EQ ─────────────────────────────────────────────────────────────────────
  String? get activePresetName => _prefs.getString('eqPreset');
  Future<void> setActivePresetName(String? name) async {
    if (name == null) {
      await _prefs.remove('eqPreset');
    } else {
      await _prefs.setString('eqPreset', name);
    }
    notifyListeners();
  }

  // ── Sleep timer ────────────────────────────────────────────────────────────
  SleepTimerEndAction get sleepEndAction =>
      SleepTimerEndAction.values[(_prefs.getInt('sleepAction') ?? 0)];
  Future<void> setSleepEndAction(SleepTimerEndAction a) async {
    await _prefs.setInt('sleepAction', a.index);
    notifyListeners();
  }

  // ── Privacy ────────────────────────────────────────────────────────────────
  bool get telemetryEnabled => _prefs.getBool('telemetry') ?? false;
  Future<void> setTelemetryEnabled(bool v) async {
    await _prefs.setBool('telemetry', v);
    notifyListeners();
  }

  bool get endToEndEncryptionEnabled => _prefs.getBool('e2ee') ?? false;
  Future<void> setEndToEndEncryptionEnabled(bool v) async {
    await _prefs.setBool('e2ee', v);
    notifyListeners();
  }

  bool get offlineOnlyMode => _prefs.getBool('offlineOnly') ?? false;
  Future<void> setOfflineOnlyMode(bool v) async {
    await _prefs.setBool('offlineOnly', v);
    notifyListeners();
  }
}

enum ThemeModePreference { system, dark, light, amoled, dynamic }
