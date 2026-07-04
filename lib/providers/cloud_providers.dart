import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// CloudProvider — abstract base for all cloud storage providers.
///
/// Concrete implementations (GoogleDriveProvider, DropboxProvider, etc.) live
/// in lib/providers/. This interface is the contract the rest of the app
/// depends on, so adding a new provider is a one-file change.
abstract class CloudProvider extends ChangeNotifier {
  CloudProvider(this.config);
  final CloudProviderConfig config;

  /// Human-readable name for display.
  String get displayName => config.displayName;

  /// Connect / authenticate. Implementations may prompt the user via OAuth.
  Future<bool> connect();

  /// Disconnect and revoke local credentials.
  Future<void> disconnect();

  /// List audio files at [path]. Returns a list of Tracks (audioUrl set to
  /// a provider-specific streaming URL).
  Future<List<Track>> listAudioFiles({String path = '/'});

  /// Stream a file directly (returns the URL to pass to just_audio).
  /// If the provider doesn't support direct streaming, returns null and
  /// callers should use [downloadFile] instead.
  Future<String?> streamUrl(String fileId);

  /// Download a file to a local path. Used for offline mode.
  Future<void> downloadFile(String fileId, String localPath);

  /// Upload a local file to [remotePath].
  Future<String> uploadFile(String localPath, String remotePath);

  /// Delete a remote file.
  Future<void> deleteFile(String fileId);

  /// Sync: pull changes since [since]. Returns the count of new/modified files.
  Future<int> pullChanges({DateTime? since});

  CloudProviderStatus get status => config.status;
}

// ─────────────────────────────────────────────────────────────────────────────
// Built-in provider implementations
// ─────────────────────────────────────────────────────────────────────────────
//
// All built-in providers are *stubs* — they implement the interface but return
// empty results / throw UnimplementedError on actual operations. This lets the
// UI be built and tested before real OAuth/networking is wired up. Replace the
// body of each method with a real implementation (e.g. googleapis package for
// Google Drive, dropbox_client for Dropbox, webdav_client for WebDAV, etc.).

class GoogleDriveProvider extends CloudProvider {
  GoogleDriveProvider(CloudProviderConfig config) : super(config);
  @override
  Future<bool> connect() async { debugPrint('GoogleDriveProvider.connect: stub'); return false; }
  @override
  Future<void> disconnect() async {}
  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async => [];
  @override
  Future<String?> streamUrl(String fileId) async => null;
  @override
  Future<void> downloadFile(String fileId, String localPath) async {}
  @override
  Future<String> uploadFile(String localPath, String remotePath) async => '';
  @override
  Future<void> deleteFile(String fileId) async {}
  @override
  Future<int> pullChanges({DateTime? since}) async => 0;
}

class DropboxProvider extends CloudProvider {
  DropboxProvider(CloudProviderConfig config) : super(config);
  @override
  Future<bool> connect() async => false;
  @override
  Future<void> disconnect() async {}
  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async => [];
  @override
  Future<String?> streamUrl(String fileId) async => null;
  @override
  Future<void> downloadFile(String fileId, String localPath) async {}
  @override
  Future<String> uploadFile(String localPath, String remotePath) async => '';
  @override
  Future<void> deleteFile(String fileId) async {}
  @override
  Future<int> pullChanges({DateTime? since}) async => 0;
}

class OneDriveProvider extends CloudProvider {
  OneDriveProvider(CloudProviderConfig config) : super(config);
  @override
  Future<bool> connect() async => false;
  @override
  Future<void> disconnect() async {}
  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async => [];
  @override
  Future<String?> streamUrl(String fileId) async => null;
  @override
  Future<void> downloadFile(String fileId, String localPath) async {}
  @override
  Future<String> uploadFile(String localPath, String remotePath) async => '';
  @override
  Future<void> deleteFile(String fileId) async {}
  @override
  Future<int> pullChanges({DateTime? since}) async => 0;
}

class NextcloudProvider extends CloudProvider {
  NextcloudProvider(CloudProviderConfig config) : super(config);
  @override
  Future<bool> connect() async => false;
  @override
  Future<void> disconnect() async {}
  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async => [];
  @override
  Future<String?> streamUrl(String fileId) async => null;
  @override
  Future<void> downloadFile(String fileId, String localPath) async {}
  @override
  Future<String> uploadFile(String localPath, String remotePath) async => '';
  @override
  Future<void> deleteFile(String fileId) async {}
  @override
  Future<int> pullChanges({DateTime? since}) async => 0;
}

class WebDavProvider extends CloudProvider {
  WebDavProvider(CloudProviderConfig config) : super(config);
  @override
  Future<bool> connect() async => false;
  @override
  Future<void> disconnect() async {}
  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async => [];
  @override
  Future<String?> streamUrl(String fileId) async => null;
  @override
  Future<void> downloadFile(String fileId, String localPath) async {}
  @override
  Future<String> uploadFile(String localPath, String remotePath) async => '';
  @override
  Future<void> deleteFile(String fileId) async {}
  @override
  Future<int> pullChanges({DateTime? since}) async => 0;
}

class SmbProvider extends CloudProvider {
  SmbProvider(CloudProviderConfig config) : super(config);
  @override
  Future<bool> connect() async => false;
  @override
  Future<void> disconnect() async {}
  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async => [];
  @override
  Future<String?> streamUrl(String fileId) async => null;
  @override
  Future<void> downloadFile(String fileId, String localPath) async {}
  @override
  Future<String> uploadFile(String localPath, String remotePath) async => '';
  @override
  Future<void> deleteFile(String fileId) async {}
  @override
  Future<int> pullChanges({DateTime? since}) async => 0;
}

class FtpProvider extends CloudProvider {
  FtpProvider(CloudProviderConfig config) : super(config);
  @override
  Future<bool> connect() async => false;
  @override
  Future<void> disconnect() async {}
  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async => [];
  @override
  Future<String?> streamUrl(String fileId) async => null;
  @override
  Future<void> downloadFile(String fileId, String localPath) async {}
  @override
  Future<String> uploadFile(String localPath, String remotePath) async => '';
  @override
  Future<void> deleteFile(String fileId) async {}
  @override
  Future<int> pullChanges({DateTime? since}) async => 0;
}

class SftpProvider extends CloudProvider {
  SftpProvider(CloudProviderConfig config) : super(config);
  @override
  Future<bool> connect() async => false;
  @override
  Future<void> disconnect() async {}
  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async => [];
  @override
  Future<String?> streamUrl(String fileId) async => null;
  @override
  Future<void> downloadFile(String fileId, String localPath) async {}
  @override
  Future<String> uploadFile(String localPath, String remotePath) async => '';
  @override
  Future<void> deleteFile(String fileId) async {}
  @override
  Future<int> pullChanges({DateTime? since}) async => 0;
}

class NasProvider extends CloudProvider {
  NasProvider(CloudProviderConfig config) : super(config);
  @override
  Future<bool> connect() async => false;
  @override
  Future<void> disconnect() async {}
  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async => [];
  @override
  Future<String?> streamUrl(String fileId) async => null;
  @override
  Future<void> downloadFile(String fileId, String localPath) async {}
  @override
  Future<String> uploadFile(String localPath, String remotePath) async => '';
  @override
  Future<void> deleteFile(String fileId) async {}
  @override
  Future<int> pullChanges({DateTime? since}) async => 0;
}

class LocalNetworkProvider extends CloudProvider {
  LocalNetworkProvider(CloudProviderConfig config) : super(config);
  @override
  Future<bool> connect() async => false;
  @override
  Future<void> disconnect() async {}
  @override
  Future<List<Track>> listAudioFiles({String path = '/'}) async => [];
  @override
  Future<String?> streamUrl(String fileId) async => null;
  @override
  Future<void> downloadFile(String fileId, String localPath) async {}
  @override
  Future<String> uploadFile(String localPath, String remotePath) async => '';
  @override
  Future<void> deleteFile(String fileId) async {}
  @override
  Future<int> pullChanges({DateTime? since}) async => 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Factory
// ─────────────────────────────────────────────────────────────────────────────

CloudProvider makeProvider(CloudProviderConfig config) {
  return switch (config.kind) {
    CloudProviderKind.googleDrive => GoogleDriveProvider(config),
    CloudProviderKind.dropbox => DropboxProvider(config),
    CloudProviderKind.oneDrive => OneDriveProvider(config),
    CloudProviderKind.nextcloud => NextcloudProvider(config),
    CloudProviderKind.webdav => WebDavProvider(config),
    CloudProviderKind.smb => SmbProvider(config),
    CloudProviderKind.ftp => FtpProvider(config),
    CloudProviderKind.sftp => SftpProvider(config),
    CloudProviderKind.nas => NasProvider(config),
    CloudProviderKind.localNetwork => LocalNetworkProvider(config),
  };
}
