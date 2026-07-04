import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Widget;

import '../models/models.dart';
import '../services/lyrics_service.dart';
import '../providers/cloud_providers.dart';

/// PluginRegistry — central registry for all plugin extension points.
///
/// Extension points (each is a separate [ExtensionPoint]):
///   - lyricsProviders       — fetch lyrics from external sources (LRCLIB, etc.)
///   - cloudProviders        — register custom cloud providers
///   - audioEffects           — apply audio effects not built into the EQ
///   - visualizers           — render audio visualizations (waveform/spectrum)
///   - metadataSources       — fetch / enrich track metadata
///   - themes                — register custom themes
///   - scripts               — register user-defined automation scripts
///
/// Plugins are registered at app startup via [register*] methods and
/// discovered at runtime via the [by*] getters.
class PluginRegistry extends ChangeNotifier {
  final List<LyricsProvider> _lyricsProviders = [];
  final List<CloudProvider> _cloudProviders = [];
  final List<AudioEffectPlugin> _audioEffects = [];
  final List<VisualizerPlugin> _visualizers = [];
  final List<MetadataSourcePlugin> _metadataSources = [];
  final List<ThemePlugin> _themes = [];
  final List<ScriptPlugin> _scripts = [];

  void registerLyricsProvider(LyricsProvider p) {
    _lyricsProviders.add(p);
    notifyListeners();
  }

  void registerCloudProvider(CloudProvider p) {
    _cloudProviders.add(p);
    notifyListeners();
  }

  void registerAudioEffect(AudioEffectPlugin p) {
    _audioEffects.add(p);
    notifyListeners();
  }

  void registerVisualizer(VisualizerPlugin p) {
    _visualizers.add(p);
    notifyListeners();
  }

  void registerMetadataSource(MetadataSourcePlugin p) {
    _metadataSources.add(p);
    notifyListeners();
  }

  void registerTheme(ThemePlugin p) {
    _themes.add(p);
    notifyListeners();
  }

  void registerScript(ScriptPlugin p) {
    _scripts.add(p);
    notifyListeners();
  }

  List<LyricsProvider> get lyricsProviders =>
      List.unmodifiable(_lyricsProviders);
  List<CloudProvider> get cloudProviders => List.unmodifiable(_cloudProviders);
  List<AudioEffectPlugin> get audioEffects => List.unmodifiable(_audioEffects);
  List<VisualizerPlugin> get visualizers => List.unmodifiable(_visualizers);
  List<MetadataSourcePlugin> get metadataSources =>
      List.unmodifiable(_metadataSources);
  List<ThemePlugin> get themes => List.unmodifiable(_themes);
  List<ScriptPlugin> get scripts => List.unmodifiable(_scripts);
}

/// Pluggable audio effect (e.g. custom DSP, room correction).
abstract class AudioEffectPlugin {
  String get name;
  String get description;

  /// Apply this effect. The implementation is responsible for routing audio
  /// through any native platform APIs it needs.
  Future<void> apply(Track track);
}

/// Pluggable visualizer (e.g. spectrum analyzer, oscilloscope, particles).
abstract class VisualizerPlugin {
  String get name;
  Widget build(/* AudioWaveform data */);
}

/// Pluggable metadata source (e.g. MusicBrainz, Discogs).
abstract class MetadataSourcePlugin {
  String get name;
  Future<Track> enrich(Track track);
}

/// Pluggable theme.
class ThemePlugin {
  final String name;
  final Map<String, dynamic> themeData;
  const ThemePlugin({required this.name, required this.themeData});
}

/// Pluggable automation script (e.g. "auto-playlist at midnight").
abstract class ScriptPlugin {
  String get name;
  Future<void> run(ScriptContext context);
}

/// Context passed to script plugins.
class ScriptContext {
  final PlaybackAdapter playback;
  final LibraryAdapter library;
  final PlaylistAdapter playlists;
  const ScriptContext(this.playback, this.library, this.playlists);
}

// Lightweight adapters that scripts use — these are interfaces so the actual
// services can be swapped out for tests.
abstract class PlaybackAdapter {
  Future<void> playAll(List<String> trackIds);
  Future<void> pause();
}

abstract class LibraryAdapter {
  List<Track> get tracks;
  List<Track> search(String query);
}

abstract class PlaylistAdapter {
  Future<void> createSmart(String name, List<SmartPlaylistRule> rules);
}
