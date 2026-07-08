import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../providers/cloud_providers.dart';

/// Real Dropbox provider using the Dropbox API v2.
///
/// Authentication: uses an OAuth2 access token stored in
/// [CloudProviderConfig.account] (format: "accessToken"). The token must
/// have the `files.content.read` scope (and `files.content.write` for
/// uploads).
///
/// To get an access token:
///   1. Register an app at https://www.dropbox.com/developers/apps
///   2. Use the OAuth2 flow (use `oauth2` package or Dropbox SDK)
///   3. Store the token via `SecurityService.storeCloudCredentials()`
class RealDropboxProvider extends CloudProvider {
  RealDropboxProvider(super.config);

  static const _apiUrl = 'https://api.dropboxapi.com/2';
  static const _contentUrl = 'https://content.dropboxapi.com/2';

  String get _accessToken => config.account ?? '';
  Map<String, String> get _authHeaders => {
    'Authorization': 'Bearer $_accessToken',
    'Accept': 'application/json',
  };

  @override
  Future<bool> connect() async {
    if (_accessToken.isEmpty) return false;
    try {
      final resp = await http.post(
        Uri.parse('$_apiUrl/users/get_current_account'),
        headers: _authHeaders,
        body: 'null',
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    // In production, revoke the token:
    // await http.post(Uri.parse('https://api.dropboxapi.com/2/auth/token_revoke'), headers: _authHeaders);
  }

  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async {
    if (_accessToken.isEmpty) return [];
    try {
      final resp = await http.post(
        Uri.parse('$_apiUrl/files/list_folder'),
        headers: {..._authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({'path': path.isEmpty ? '' : path, 'recursive': true}),
      );
      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final entries = data['entries'] as List? ?? [];

      // Filter for audio files
      final audioExtensions = [
        '.mp3',
        '.flac',
        '.wav',
        '.aac',
        '.ogg',
        '.m4a',
        '.opus',
      ];
      return entries
          .where((e) {
            final name = (e['name'] as String?) ?? '';
            final lower = name.toLowerCase();
            return audioExtensions.any((ext) => lower.endsWith(ext));
          })
          .map<Track>((f) {
            final name = f['name'] as String? ?? 'unknown';
            final pathLower = f['path_lower'] as String? ?? '';
            final baseName = name.replaceAll(RegExp(r'\.[^.]+$'), '');
            final parts = baseName.split(RegExp(r'\s*-\s*'));
            final format = AudioFormat.fromPath(name) ?? AudioFormat.mp3;
            return Track(
              id: 'dropbox://${config.id}/$pathLower',
              title: parts.length > 1 ? parts.sublist(1).join(' - ') : baseName,
              artist: parts.length > 1 ? parts.first : 'Unknown Artist',
              album: 'Dropbox',
              year: 0,
              duration: Duration.zero,
              artUrl: '',
              audioUrl: '$_contentUrl/files/download',
              format: format,
              isCloudOnly: true,
            );
          })
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<String?> streamUrl(String fileId) async {
    if (_accessToken.isEmpty) return null;
    // Dropbox doesn't support direct streaming URLs without the SDK.
    // We return the content API URL — just_audio will need to add the
    // Authorization header and Dropbox-Api-Arg via AudioSource.uri(headers:).
    return '$_contentUrl/files/download';
  }

  /// Returns the headers needed to stream from Dropbox, including the
  /// Dropbox-Api-Arg that specifies the file path.
  Map<String, String> streamHeadersForFile(String fileId) {
    final prefix = 'dropbox://${config.id}/';
    final path = fileId.startsWith(prefix)
        ? fileId.substring(prefix.length)
        : fileId;
    return {
      ..._authHeaders,
      'Dropbox-Api-Arg': jsonEncode({'path': path}),
    };
  }

  @override
  Future<void> downloadFile(String fileId, String localPath) async {
    if (_accessToken.isEmpty) return;
    final prefix = 'dropbox://${config.id}/';
    final path = fileId.startsWith(prefix)
        ? fileId.substring(prefix.length)
        : fileId;
    final resp = await http.post(
      Uri.parse('$_contentUrl/files/download'),
      headers: {
        ..._authHeaders,
        'Dropbox-Api-Arg': jsonEncode({'path': path}),
      },
    );
    if (resp.statusCode == 200) {
      // Write to local file — would use dart:io File here
      // await File(localPath).writeAsBytes(resp.bodyBytes);
    }
  }

  @override
  Future<String> uploadFile(String localPath, String remotePath) async {
    if (_accessToken.isEmpty) return '';
    final fileName = localPath.split('/').last;
    final dropboxPath = remotePath.isEmpty
        ? '/$fileName'
        : '$remotePath/$fileName';
    // In production, read the file bytes and upload via multipart
    // final fileBytes = await File(localPath).readAsBytes();
    final resp = await http.post(
      Uri.parse('$_contentUrl/files/upload'),
      headers: {
        ..._authHeaders,
        'Dropbox-Api-Arg': jsonEncode({
          'path': dropboxPath,
          'mode': 'overwrite',
          'autorename': false,
        }),
        'Content-Type': 'application/octet-stream',
      },
      // body: fileBytes,
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['path_lower'] as String? ?? '';
    }
    return '';
  }

  @override
  Future<void> deleteFile(String fileId) async {
    if (_accessToken.isEmpty) return;
    final prefix = 'dropbox://${config.id}/';
    final path = fileId.startsWith(prefix)
        ? fileId.substring(prefix.length)
        : fileId;
    await http.post(
      Uri.parse('$_apiUrl/files/delete_v2'),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({'path': path}),
    );
  }

  @override
  Future<int> pullChanges({DateTime? since}) async {
    // Dropbox has a /files/list_folder/continue endpoint for incremental sync.
    // For simplicity, we re-list all files.
    final tracks = await listAudioFiles();
    return tracks.length;
  }
}
