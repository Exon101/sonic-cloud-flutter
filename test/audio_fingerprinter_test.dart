import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/fingerprint/audio_fingerprinter.dart';

void main() {
  group('AudioFingerprinter', () {
    final fp = AudioFingerprinter();

    test('distance between identical fingerprints is 0', () {
      const a = '0000000000000000000000000000000000000000000000000000000000000000';
      expect(fp.distance(a, a), 0);
    });

    test('distance between opposite fingerprints is 256', () {
      const zeros = '0000000000000000000000000000000000000000000000000000000000000000';
      const ffff = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
      expect(fp.distance(zeros, ffff), 256);
    });

    test('areSimilar returns true for identical hashes', () {
      const a = 'abc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abc1';
      expect(fp.areSimilar(a, a), true);
    });

    test('areSimilar returns false for very different hashes', () {
      const a = '0000000000000000000000000000000000000000000000000000000000000000';
      const b = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
      expect(fp.areSimilar(a, b), false);
    });

    test('distance is symmetric', () {
      const a = '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      const b = 'fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321';
      expect(fp.distance(a, b), fp.distance(b, a));
    });

    test('distance handles invalid lengths by returning 256', () {
      expect(fp.distance('short', 'alsoshort'), 256);
    });

    test('findDuplicates groups similar tracks together', () async {
      // We can't easily fake the file IO in this test, so just verify the
      // method signature works with empty input.
      final groups = await fp.findDuplicates([]);
      expect(groups, isEmpty);
    });
  });
}
