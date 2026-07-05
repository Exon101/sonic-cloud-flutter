import 'package:webdav_client/webdav_client.dart' as wd;

import '../models/models.dart';
import '../providers/cloud_providers.dart';

/// Real Nextcloud provider using WebDAV (Nextcloud's WebDAV endpoint).
///
/// Nextcloud is WebDAV-compatible, so this provider reuses `webdav_client`
/// with the Nextcloud-specific URL pattern:
///   https://<nextcloud-server>/remote.php/dav/files/<username>/
///
/// Authentication: basic auth (username:password) stored in
/// [CloudProviderConfig.account] (format: "username:password").
/// The server URL is stored in [CloudProviderConfig.rootPath].
class RealNextcloudProvider extends CloudProvider {
  RealNextcloudProvider(super.config);

  wd.Client? _client;
  List<Track>? _cache;

  @override
  Future<bool> connect() async {
    try {
      final serverUrl = config.rootPath ?? '';
      final creds = (config.account ?? '').split(':');
      if (serverUrl.isEmpty || creds.length < 2) return false;

      // Construct the WebDAV base URL for Nextcloud
      final username = creds[0];
      final webdavUrl = '$serverUrl/remote.php/dav/files/$username';

      _client = wd.newClient(
        webdavUrl,
        user: username,
        password: creds[1],
        debug: false,
      );

      // Ping with a PROPFIND on the root
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
  }

  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async {
    if (_client == null) return [];
    if (_cache != null) return _cache!;
    final tracks = <Track>[];
    await _walk(path, tracks);
    _cache = tracks;
    return tracks;
  }

  Future<void> _walk(String path, List<Track> tracks) async {
    final items = await _client!.readDir(path);
    for (final item in items) {
      final isDir = item.isDir ?? false;
      final name = item.name ?? '';
      if (isDir) {
        await _walk(item.path ?? '/', tracks);
      } else {
        final format = AudioFormat.fromPath(name);
        if (format == null) continue;

        final baseName = name.replaceAll(RegExp(r'\.[^.]+$'), '');
        final parts = baseName.split(RegExp(r'\s*-\s*'));
        final serverUrl = config.rootPath ?? '';
        final creds = (config.account ?? '').split(':');
        final username = creds.isNotEmpty ? creds[0] : '';
        final streamUrl =
            '$serverUrl/remote.php/dav/files/$username${item.path}';

        tracks.add(
          Track(
            id: 'nextcloud://${config.id}/${item.path}',
            title: parts.length > 1 ? parts.sublist(1).join(' - ') : baseName,
            artist: parts.length > 1 ? parts.first : 'Unknown Artist',
            album: 'Nextcloud',
            year: 0,
            duration: Duration.zero,
            artUrl: '',
            audioUrl: streamUrl,
            format: format,
            isCloudOnly: true,
          ),
        );
      }
    }
  }

  @override
  Future<String?> streamUrl(String fileId) async {
    if (_client == null) return null;
    // The fileId contains the full WebDAV path
    final prefix = 'nextcloud://${config.id}/';
    final path = fileId.startsWith(prefix)
        ? fileId.substring(prefix.length)
        : fileId;
    final serverUrl = config.rootPath ?? '';
    final creds = (config.account ?? '').split(':');
    final username = creds.isNotEmpty ? creds[0] : '';
    return '$serverUrl/remote.php/dav/files/$username$path';
  }

  @override
  Future<void> downloadFile(String fileId, String localPath) async {
    if (_client == null) return;
    final prefix = 'nextcloud://${config.id}/';
    final path = fileId.startsWith(prefix)
        ? fileId.substring(prefix.length)
        : fileId;
    await _client!.read2File(path, localPath);
  }

  @override
  Future<String> uploadFile(String localPath, String remotePath) async {
    if (_client == null) return '';
    await _client!.writeFromFile(localPath, remotePath);
    _cache = null;
    return remotePath;
  }

  @override
  Future<void> deleteFile(String fileId) async {
    if (_client == null) return;
    final prefix = 'nextcloud://${config.id}/';
    final path = fileId.startsWith(prefix)
        ? fileId.substring(prefix.length)
        : fileId;
    await _client!.remove(path);
    _cache = null;
  }

  @override
  Future<int> pullChanges({DateTime? since}) async {
    if (_cache == null) {
      await listAudioFiles();
      return _cache?.length ?? 0;
    }
    _cache = null;
    await listAudioFiles();
    return _cache?.length ?? 0;
  }
}
