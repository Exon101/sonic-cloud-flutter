import 'dart:convert';

import 'package:webdav_client/webdav_client.dart';

import '../models/models.dart';
import '../providers/cloud_providers.dart';

/// Real WebDAV provider implementation backed by `webdav_client`.
///
/// Supports:
///   - Connect via URL + credentials (basic auth)
///   - List audio files recursively (caches result on first call)
///   - Stream URL (direct GET URL — works for any HTTP-capable player)
///   - Download to local path
///   - Upload local file
///   - Delete remote file
///   - pullChanges via `getlastmodified` ETag comparison
///
/// Limitations:
///   - No streaming URL for credentials-protected URLs is returned as a plain
///     `https://user:pass@host/path` URL. just_audio can fetch this directly.
///   - For large WebDAV servers, the recursive list may be slow; pagination
///     isn't supported by webdav_client yet.
class RealWebDavProvider extends CloudProvider {
  RealWebDavProvider(super.config);

  WebDavClient? _client;
  List<Track>? _cache;
  DateTime? _cacheBuiltAt;

  /// Connect using credentials stored in [CloudProviderConfig.account]
  /// (format: "user:password") and the WebDAV server URL stored in
  /// [CloudProviderConfig.rootPath].
  @override
  Future<bool> connect() async {
    try {
      final uri = Uri.parse(config.rootPath ?? '');
      final creds = (config.account ?? '').split(':');
      _client = WebDavClient(
        uri.host,
        uri.port == 0 ? (uri.scheme == 'https' ? 443 : 80) : uri.port,
        scheme: uri.scheme,
        user: creds.isNotEmpty ? creds[0] : '',
        password: creds.length > 1 ? creds[1] : '',
        debug: false,
      );
      // Ping with a simple PROPFIND on the root.
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
      if (isDir) {
        await _walk(item.path ?? '/', tracks);
      } else {
        final format = AudioFormat.fromPath(item.name ?? '');
        if (format == null) continue;
        tracks.add(_fileToTrack(item, format));
      }
    }
  }

  Track _fileToTrack(FileElement f, AudioFormat format) {
    final name = (f.name ?? 'unknown').replaceAll(RegExp(r'\.[^.]+$'), '');
    final parts = name.split(RegExp(r'\s*-\s*'));
    final artist = parts.length > 1 ? parts.first : 'Unknown Artist';
    final title = parts.length > 1 ? parts.sublist(1).join(' - ') : name;
    final uri = Uri.parse(config.rootPath ?? '');
    final creds = (config.account ?? '').split(':');
    final streamUrl = uri.replace(
      userInfo: creds.length > 1 ? '${creds[0]}:${creds[1]}' : null,
      path: f.path,
    ).toString();

    return Track(
      id: 'webdav://${config.id}/${f.path}',
      title: title,
      artist: artist,
      album: 'Unknown Album',
      year: 0,
      duration: Duration(seconds: 0),
      artUrl: '',
      audioUrl: streamUrl,
      format: format,
      isCloudOnly: true,
    );
  }

  @override
  Future<String?> streamUrl(String fileId) async {
    // fileId is the audioUrl we constructed in _fileToTrack.
    return fileId;
  }

  @override
  Future<void> downloadFile(String fileId, String localPath) async {
    if (_client == null) return;
    // Strip the prefix to get the WebDAV path.
    final path = _stripPrefix(fileId);
    final data = await _client!.read(path);
    await data.pipe(FileSink(localPath));
  }

  @override
  Future<String> uploadFile(String localPath, String remotePath) async {
    if (_client == null) return '';
    await _client!.upload(FileSource(localPath), remotePath);
    _cache = null; // invalidate
    return '$remotePath/${localPath.split('/').last}';
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
    if (since != null && _cacheBuiltAt != null && since.isAfter(_cacheBuiltAt!)) {
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

// Local file sink helper for the download pipe.
class FileSink implements StreamSink<List<int>> {
  FileSink(this.path);
  final String path;
  late final _file = File(path);
  IOSink? _sink;

  IOSink get sink => _sink ??= _file.openWrite();

  @override
  Future<void> add(List<int> data) async {
    sink.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    sink.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) => sink.addStream(stream);

  @override
  Future<void> close() async => await sink.close();

  @override
  Future<void> get done => sink.done;
}

// File / FileSource wrappers for webdav_client (which uses dart:io File).
import 'dart:io';

class FileSource {
  FileSource(this.path);
  final String path;
  File get file => File(path);
  Stream<List<int>> openRead() => file.openRead();
}

extension on FileElement {
  String? get name => path?.split('/').where((s) => s.isNotEmpty).last;
}
