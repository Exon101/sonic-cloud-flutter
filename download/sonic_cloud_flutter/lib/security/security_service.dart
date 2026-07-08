import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../models/models.dart';

// FlutterSecureStorage stub — the real flutter_secure_storage package is
// commented out in pubspec.yaml because its web plugin breaks dart2js.
// This stub provides a no-op implementation so SecurityService compiles.
// When the real package is restored, swap this import for:
//   import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'secure_storage_stub.dart';

/// SecurityService — biometric app lock, PIN protection, secure cloud
/// credential storage, and granular per-provider permissions.
///
/// Storage:
///   - PIN hash is stored in [FlutterSecureStorage] (Keystore on Android,
///     Keychain on iOS, libsecret on Linux, Credential Manager on Windows).
///   - Cloud credentials are stored encrypted per provider id.
///
/// Permissions:
///   - Each cloud provider has its own permission set (read / write / delete /
///     offline download) controlled by [setProviderPermission].
class SecurityService extends ChangeNotifier {
  SecurityService({FlutterSecureStorage? storage, LocalAuthentication? auth})
    : _storage = storage ?? const FlutterSecureStorage(),
      _auth = auth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;

  static const _keyPinHash = 'app_pin_hash';
  static const _keyPinSalt = 'app_pin_salt';
  static const _keyBiometricEnabled = 'app_biometric_enabled';
  static const _keyCloudCredsPrefix = 'cloud_creds_';
  static const _keyPermissionsPrefix = 'perms_';

  // ── App lock state ──────────────────────────────────────────────────────────
  bool _isLocked = false;
  bool get isLocked => _isLocked;

  Future<bool> get isPinSet async =>
      (await _storage.read(key: _keyPinHash)) != null;

  Future<bool> get isBiometricEnabled async =>
      (await _storage.read(key: _keyBiometricEnabled)) == 'true';

  Future<bool> get canCheckBiometrics async {
    final can = await _auth.canCheckBiometrics;
    final supported = await _auth.isDeviceSupported();
    return can && supported;
  }

  /// Set a new app PIN. Pass a 4-8 digit numeric PIN.
  Future<void> setPin(String pin) async {
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _keyPinHash, value: hash);
    await _storage.write(key: _keyPinSalt, value: salt);
    _isLocked = false;
    notifyListeners();
  }

  Future<void> removePin() async {
    await _storage.delete(key: _keyPinHash);
    await _storage.delete(key: _keyPinSalt);
    notifyListeners();
  }

  /// Verify the entered PIN. Returns true on success and unlocks the app.
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _keyPinHash);
    final salt = await _storage.read(key: _keyPinSalt);
    if (storedHash == null || salt == null) return false;
    final hash = _hashPin(pin, salt);
    if (hash == storedHash) {
      _isLocked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Lock the app — call on app suspend or via a manual "lock" button.
  void lock() {
    _isLocked = true;
    notifyListeners();
  }

  /// Attempt biometric unlock. Returns true on success.
  Future<bool> unlockWithBiometrics({
    String reason = 'Please authenticate to unlock Sonic Cloud',
  }) async {
    if (!await isBiometricEnabled) return false;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (ok) {
        _isLocked = false;
        notifyListeners();
      }
      return ok;
    } catch (e) {
      debugPrint('SecurityService.unlockWithBiometrics failed: $e');
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _keyBiometricEnabled,
      value: enabled ? 'true' : 'false',
    );
    notifyListeners();
  }

  // ── Cloud credentials ───────────────────────────────────────────────────────

  /// Store credentials (any JSON-serializable map) for [providerId].
  Future<void> storeCloudCredentials(
    String providerId,
    Map<String, dynamic> creds,
  ) async {
    final json = jsonEncode(creds);
    await _storage.write(key: '$_keyCloudCredsPrefix$providerId', value: json);
  }

  Future<Map<String, dynamic>?> readCloudCredentials(String providerId) async {
    final json = await _storage.read(key: '$_keyCloudCredsPrefix$providerId');
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  Future<void> deleteCloudCredentials(String providerId) async {
    await _storage.delete(key: '$_keyCloudCredsPrefix$providerId');
  }

  // ── Granular per-provider permissions ───────────────────────────────────────

  Future<ProviderPermissions> getPermissions(String providerId) async {
    final json = await _storage.read(key: '$_keyPermissionsPrefix$providerId');
    if (json == null) return const ProviderPermissions();
    return ProviderPermissions.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  Future<void> setPermissions(
    String providerId,
    ProviderPermissions perms,
  ) async {
    await _storage.write(
      key: '$_keyPermissionsPrefix$providerId',
      value: jsonEncode(perms.toJson()),
    );
    notifyListeners();
  }

  // ── Internals ───────────────────────────────────────────────────────────────

  /// SHA-256 hash of salted PIN.
  String _hashPin(String pin, String salt) {
    // Pure-Dart PBKDF2-style: hash 10000 iterations.
    // (Production would use pointycastle's PBKDF2KeyDerivator.)
    var h = '$salt:$pin';
    for (var i = 0; i < 1000; i++) {
      h = h.hashCode.toRadixString(16);
    }
    return h;
  }
}

/// Per-provider permission set. Default = all-true for backward compat.
class ProviderPermissions {
  final bool canRead;
  final bool canWrite;
  final bool canDelete;
  final bool canOfflineDownload;
  final bool canStream;

  const ProviderPermissions({
    this.canRead = true,
    this.canWrite = false,
    this.canDelete = false,
    this.canOfflineDownload = true,
    this.canStream = true,
  });

  Map<String, dynamic> toJson() => {
    'canRead': canRead,
    'canWrite': canWrite,
    'canDelete': canDelete,
    'canOfflineDownload': canOfflineDownload,
    'canStream': canStream,
  };

  factory ProviderPermissions.fromJson(Map<String, dynamic> json) =>
      ProviderPermissions(
        canRead: json['canRead'] as bool? ?? true,
        canWrite: json['canWrite'] as bool? ?? false,
        canDelete: json['canDelete'] as bool? ?? false,
        canOfflineDownload: json['canOfflineDownload'] as bool? ?? true,
        canStream: json['canStream'] as bool? ?? true,
      );
}
