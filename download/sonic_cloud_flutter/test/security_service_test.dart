import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/security/security_service.dart';

void main() {
  group('ProviderPermissions', () {
    test(
      'defaults to read/stream/offline-download allowed, write/delete denied',
      () {
        const p = ProviderPermissions();
        expect(p.canRead, true);
        expect(p.canStream, true);
        expect(p.canOfflineDownload, true);
        expect(p.canWrite, false);
        expect(p.canDelete, false);
      },
    );

    test('toJson round-trips through fromJson', () {
      const original = ProviderPermissions(
        canRead: true,
        canWrite: true,
        canDelete: false,
        canOfflineDownload: false,
        canStream: true,
      );
      final json = original.toJson();
      final restored = ProviderPermissions.fromJson(json);
      expect(restored.canRead, original.canRead);
      expect(restored.canWrite, original.canWrite);
      expect(restored.canDelete, original.canDelete);
      expect(restored.canOfflineDownload, original.canOfflineDownload);
      expect(restored.canStream, original.canStream);
    });

    test('fromJson handles missing keys with defaults', () {
      final p = ProviderPermissions.fromJson({});
      expect(p.canRead, true);
      expect(p.canWrite, false);
    });
  });
}
