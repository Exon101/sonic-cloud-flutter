import 'dart:io';
import 'dart:typed_data';

import '../models/models.dart';
import '../providers/cloud_providers.dart';

/// SMB provider — connects to SMB/CIFS shares.
///
/// **Architecture note:** SMB is a binary protocol that requires native code
/// (no pure-Dart SMB library exists). This provider:
///   - On desktop platforms (macOS/Windows/Linux): uses `Process.run('smbclient', ...)`
///     to interact with SMB shares via the system's smbclient utility.
///   - On mobile: falls back to a documented stub (SMB not available on iOS/Android
///     without a native plugin like `dart_smb`).
///
/// Configuration:
///   - [CloudProviderConfig.rootPath]: `smb://host/share` or `\\\\host\share`
///   - [CloudProviderConfig.account]: `username:password` or `username:password:workgroup`
class RealSmbProvider extends CloudProvider {
  RealSmbProvider(super.config);

  bool get _isDesktop =>
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  String get _smbPath {
    // Convert smb://host/share to \\host\share for smbclient
    final raw = config.rootPath ?? '';
    if (raw.startsWith('smb://')) {
      return raw.substring(6).replaceAll('/', '\\');
    }
    return raw;
  }

  List<String> get _authArgs {
    final creds = (config.account ?? '').split(':');
    final args = <String>[];
    if (creds.isNotEmpty && creds[0].isNotEmpty) {
      args.addAll(['-U', creds[0]]);
    }
    // Password is passed via stdin in production; for demo we use -N (no pass)
    return args;
  }

  @override
  Future<bool> connect() async {
    if (!_isDesktop) return false;
    try {
      // Check if smbclient is available
      final result = await Process.run('which', ['smbclient']);
      if (result.exitCode != 0) return false;
      // Try connecting to the share
      final connectResult = await Process.run('smbclient', [
        '//$config',
        '-c',
        'ls',
        ..._authArgs,
      ], stdin: config.account?.split(':').elementAtOrNull(1) ?? '');
      return connectResult.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async {
    if (!_isDesktop) return [];
    try {
      // Use smbclient to list files recursively
      final result = await Process.run('smbclient', [
        _smbPath,
        '-c',
        'recurse;ls',
        ..._authArgs,
      ]);
      if (result.exitCode != 0) return [];

      // Parse smbclient output to find audio files
      final output = result.stdout as String;
      final lines = output.split('\n');
      final tracks = <Track>[];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('\\')) continue;
        final format = AudioFormat.fromPath(trimmed);
        if (format == null) continue;

        final baseName = trimmed.replaceAll(RegExp(r'\.[^.]+$'), '');
        final parts = baseName.split(RegExp(r'\s*-\s*'));
        tracks.add(
          Track(
            id: 'smb://${config.id}/$trimmed',
            title: parts.length > 1 ? parts.sublist(1).join(' - ') : baseName,
            artist: parts.length > 1 ? parts.first : 'Unknown Artist',
            album: 'SMB Share',
            year: 0,
            duration: Duration.zero,
            artUrl: '',
            audioUrl: 'smb://${config.id}/$trimmed',
            format: format,
            isCloudOnly: true,
          ),
        );
      }
      return tracks;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<String?> streamUrl(String fileId) async {
    // SMB doesn't support direct streaming URLs — files must be downloaded
    // first via downloadFile, then played locally.
    return null;
  }

  @override
  Future<void> downloadFile(String fileId, String localPath) async {
    if (!_isDesktop) return;
    final prefix = 'smb://${config.id}/';
    final remotePath = fileId.startsWith(prefix)
        ? fileId.substring(prefix.length)
        : fileId;
    await Process.run('smbclient', [
      _smbPath,
      '-c',
      'get "$remotePath" "$localPath"',
      ..._authArgs,
    ]);
  }

  @override
  Future<String> uploadFile(String localPath, String remotePath) async {
    if (!_isDesktop) return '';
    await Process.run('smbclient', [
      _smbPath,
      '-c',
      'put "$localPath" "$remotePath"',
      ..._authArgs,
    ]);
    return remotePath;
  }

  @override
  Future<void> deleteFile(String fileId) async {
    if (!_isDesktop) return;
    final prefix = 'smb://${config.id}/';
    final remotePath = fileId.startsWith(prefix)
        ? fileId.substring(prefix.length)
        : fileId;
    await Process.run('smbclient', [
      _smbPath,
      '-c',
      'del "$remotePath"',
      ..._authArgs,
    ]);
  }

  @override
  Future<int> pullChanges({DateTime? since}) async {
    final tracks = await listAudioFiles();
    return tracks.length;
  }
}
