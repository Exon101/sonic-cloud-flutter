import 'dart:io';

import 'package:webdav_client/webdav_client.dart' as wd;

import '../models/models.dart';
import '../providers/cloud_providers.dart';

/// Real WebDAV provider implementation backed by `webdav_client` 1.2.x.
///
/// Supports:
///   - Connect via URL + credentials (basic auth) using `newClient(...)`
///   - List audio files recursively (caches result on first call)
///   - Stream URL (direct HTTPS URL with embedded credentials)
///   - Download to local path via `read2File(...)`
///   - Upload local file via `writeFromFile(...)`
///   - Delete remote file via `remove(...)`
///   - pullChanges via cache invalidation
class RealWebDavProvider extends CloudProvider {
  RealWebDavProvider(super.config);

  wd.Client? _client;
  List<Track>? _cache;
  DateTime? _cacheBuiltAt;

  @override
  Future<bool> connect() async {
    try {
      final uri = config.rootPath ?? '';
      if (uri.isEmpty) return false;
      final creds = (config.account ?? '').split(':');
      _client = wd.newClient(
        uri,
        user: creds.isNotEmpty ? creds[0] : '',
        password: creds.length > 1 ? creds[1] : '',
        debug: false,
      );
      // Ping with a PROPFIND on the root.
      await _client!.readDir('/');
      return true;
    } catch (_) {
      _client = null;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _client = null;
    _cache = null;
    _cacheBuiltAt = null;
  }

  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async {
    if (_client == null) return [];
    if (_cache != null) return _cache!;
    final tracks = <Track>[];
    await _walk(path, tracks);
    _cache = tracks;
    _cacheBuiltAt = DateTime.now();
    return tracks;
  }

  Future<void> _walk(String path, List<Track> tracks) async {
    final items = await _client!.readDir(path);
    for (final item in items) {
      final isDir = item.isDir ?? false;
      final name = item.name ?? _extractName(item.path);
      if (isDir) {
        await _walk(item.path ?? '/', tracks);
      } else {
        final format = AudioFormat.fromPath(name);
        if (format == null) continue;
        tracks.add(_fileToTrack(item, format, name));
      }
    }
  }

  /// Extract the last path segment (file or folder name) from a WebDAV path.
  String _extractName(String? path) {
    if (path == null || path.isEmpty) return '';
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final segments = trimmed.split('/').where((s) => s.isNotEmpty);
    final last = segments.isEmpty ? '' : segments.last;
    try {
      return Uri.decodeComponent(last);
    } catch (_) {
      return last;
    }
  }

  Track _fileToTrack(wd.File f, AudioFormat format, String name) {
    final baseName = name.replaceAll(RegExp(r'\.[^.]+$'), '');
    final parts = baseName.split(RegExp(r'\s*-\s*'));
    final artist = parts.length > 1 ? parts.first : 'Unknown Artist';
    final title = parts.length > 1 ? parts.sublist(1).join(' - ') : baseName;
    final uri = Uri.parse(config.rootPath ?? '');
    final creds = (config.account ?? '').split(':');
    final streamUrl = uri
        .replace(
          userInfo: creds.length > 1 ? '${creds[0]}:${creds[1]}' : null,
          path: f.path,
        )
        .toString();

    return Track(
      id: 'webdav://${config.id}/${f.path}',
      title: title,
      artist: artist,
      album: 'Unknown Album',
      year: 0,
      duration: Duration.zero,
      artUrl: '',
      audioUrl: streamUrl,
      format: format,
      isCloudOnly: true,
    );
  }

  @override
  Future<String?> streamUrl(String fileId) async {
    if (_client == null) return null;
    // fileId is the audioUrl we constructed in _fileToTrack.
    return fileId;
  }

  @override
  Future<void> downloadFile(String fileId, String localPath) async {
    if (_client == null) return;
    final path = _stripPrefix(fileId);
    await _client!.read2File(path, localPath);
  }

  @override
  Future<String> uploadFile(String localPath, String remotePath) async {
    if (_client == null) return '';
    await _client!.writeFromFile(localPath, remotePath);
    _cache = null; // invalidate
    return remotePath;
  }

  @override
  Future<void> deleteFile(String fileId) async {
    if (_client == null) return;
    await _client!.remove(_stripPrefix(fileId));
    _cache = null;
  }

  @override
  Future<int> pullChanges({DateTime? since}) async {
    if (_cache == null) {
      await listAudioFiles();
      return _cache?.length ?? 0;
    }
    if (since != null &&
        _cacheBuiltAt != null &&
        since.isAfter(_cacheBuiltAt!)) {
      return 0; // cache is fresh
    }
    _cache = null;
    await listAudioFiles();
    return _cache?.length ?? 0;
  }

  String _stripPrefix(String fileId) {
    final prefix = 'webdav://${config.id}/';
    if (fileId.startsWith(prefix)) return fileId.substring(prefix.length);
    return fileId;
  }
}
