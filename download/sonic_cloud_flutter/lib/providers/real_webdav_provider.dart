import '../models/models.dart';
import '../providers/cloud_providers.dart';

/// WebDAV provider — stub implementation.
///
/// This was originally a full implementation using `webdav_client`, but the
/// package's API (constructor signature, `FileElement` class, `read`/`write`
/// method signatures) didn't match what was coded. Rather than ship broken
/// code, this is a documented stub that matches the other 9 cloud providers.
///
/// **To implement for real:** replace each method body with calls to
/// `webdav_client` per its API at https://pub.dev/packages/webdav_client.
/// The `connect()` method should construct a client with the server URL +
/// credentials from `config.rootPath` and `config.account`.
class RealWebDavProvider extends CloudProvider {
  RealWebDavProvider(super.config);

  @override
  Future<bool> connect() async {
    // TODO: construct webdav_client with config.rootPath + config.account
    // and ping with a PROPFIND on '/'.
    return false;
  }

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
