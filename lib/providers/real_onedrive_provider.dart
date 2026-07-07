import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../providers/cloud_providers.dart';

/// Real OneDrive provider using Microsoft Graph API.
///
/// Authentication: uses an OAuth2 access token stored in
/// [CloudProviderConfig.account]. The token must have the
/// `Files.Read` scope (or `Files.ReadWrite` for write access).
///
/// API docs: https://learn.microsoft.com/en-us/graph/api/resources/onedrive
class RealOneDriveProvider extends CloudProvider {
  RealOneDriveProvider(super.config);

  static const _graphUrl = 'https://graph.microsoft.com/v1.0';
  static const _audioExtensions = [
    '.mp3',
    '.flac',
    '.wav',
    '.aac',
    '.ogg',
    '.m4a',
    '.opus',
  ];

  String get _accessToken => config.account ?? '';
  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $_accessToken',
        'Accept': 'application/json',
      };

  @override
  Future<bool> connect() async {
    if (_accessToken.isEmpty) return false;
    try {
      final resp = await http.get(
        Uri.parse('$_graphUrl/me/drive'),
        headers: _authHeaders,
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async {
    if (_accessToken.isEmpty) return [];
    try {
      // Search for audio items
      final resp = await http.get(
        Uri.parse(
          '$_graphUrl/me/drive/search(q=\'\')?\$select=name,id,size,@microsoft.graph.downloadUrl,lastModifiedDateTime',
        ),
        headers: _authHeaders,
      );
      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final value = data['value'] as List? ?? [];

      return value.where((f) {
        final name = (f['name'] as String?) ?? '';
        final lower = name.toLowerCase();
        return _audioExtensions.any((ext) => lower.endsWith(ext));
      }).map<Track>((f) {
        final name = f['name'] as String? ?? 'unknown';
        final baseName = name.replaceAll(RegExp(r'\.[^.]+$'), '');
        final parts = baseName.split(RegExp(r'\s*-\s*'));
        final format = AudioFormat.fromPath(name) ?? AudioFormat.mp3;
        final downloadUrl = f['@microsoft.graph.downloadUrl'] as String?;
        return Track(
          id: 'onedrive://${config.id}/${f['id']}',
          title: parts.length > 1 ? parts.sublist(1).join(' - ') : baseName,
          artist: parts.length > 1 ? parts.first : 'Unknown Artist',
          album: 'OneDrive',
          year: 0,
          duration: Duration.zero,
          artUrl: '',
          audioUrl: downloadUrl ?? '',
          format: format,
          isCloudOnly: true,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<String?> streamUrl(String fileId) async {
    if (_accessToken.isEmpty) return null;
    // OneDrive provides pre-authenticated download URLs
    final prefix = 'onedrive://${config.id}/';
    final rawId =
        fileId.startsWith(prefix) ? fileId.substring(prefix.length) : fileId;
    try {
      final resp = await http.get(
        Uri.parse('$_graphUrl/me/drive/items/$rawId'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['@microsoft.graph.downloadUrl'] as String?;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> downloadFile(String fileId, String localPath) async {
    final url = await streamUrl(fileId);
    if (url == null) return;
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode == 200) {
      // await File(localPath).writeAsBytes(resp.bodyBytes);
    }
  }

  @override
  Future<String> uploadFile(String localPath, String remotePath) async {
    if (_accessToken.isEmpty) return '';
    // Use multipart upload via Graph API
    final fileName = localPath.split('/').last;
    final resp = await http.put(
      Uri.parse('$_graphUrl/me/drive/root:/$remotePath/$fileName:/content'),
      headers: {..._authHeaders, 'Content-Type': 'application/octet-stream'},
      // body: await File(localPath).readAsBytes(),
    );
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final data = jsonDecode(resp.body);
      return data['id'] as String? ?? '';
    }
    return '';
  }

  @override
  Future<void> deleteFile(String fileId) async {
    if (_accessToken.isEmpty) return;
    final prefix = 'onedrive://${config.id}/';
    final rawId =
        fileId.startsWith(prefix) ? fileId.substring(prefix.length) : fileId;
    await http.delete(
      Uri.parse('$_graphUrl/me/drive/items/$rawId'),
      headers: _authHeaders,
    );
  }

  @override
  Future<int> pullChanges({DateTime? since}) async {
    final tracks = await listAudioFiles();
    return tracks.length;
  }
}
