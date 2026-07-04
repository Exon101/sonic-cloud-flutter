import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/models/models.dart';
import 'package:sonic_cloud/providers/real_webdav_provider.dart';

void main() {
  group('RealWebDavProvider', () {
    late RealWebDavProvider provider;

    setUp(() {
      provider = RealWebDavProvider(
        const CloudProviderConfig(
          id: 'wd1',
          kind: CloudProviderKind.webdav,
          displayName: 'My WebDAV',
          rootPath: 'https://dav.example.com',
          account: 'user:pass',
        ),
      );
    });

    test('connect returns false when server is unreachable', () async {
      final result = await provider.connect();
      expect(result, isFalse);
    });

    test('disconnect clears state', () async {
      await provider.disconnect();
      expect(provider.status, CloudProviderStatus.disconnected);
    });

    test('listAudioFiles returns empty list when not connected', () async {
      final tracks = await provider.listAudioFiles();
      expect(tracks, isEmpty);
    });

    test('streamUrl returns null when not connected', () async {
      final url = await provider.streamUrl('some-file-id');
      expect(url, isNull);
    });

    test('pullChanges returns 0 when not connected', () async {
      final count = await provider.pullChanges();
      expect(count, 0);
    });

    test('uploadFile returns empty string when not connected', () async {
      final result = await provider.uploadFile('/local/path', '/remote/path');
      expect(result, isEmpty);
    });
  });
}
