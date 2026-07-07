# Security Policy

## Supported versions

Sonic Cloud is pre-1.0 software. Only the latest `main` branch receives
security fixes.

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, email the maintainer at **security@example.com** (replace with your
real address) with:

1. A description of the vulnerability
2. Steps to reproduce (or a proof-of-concept)
3. Affected versions / commits
4. Suggested fix (optional)

You'll receive an acknowledgement within 48 hours. We'll work with you to
understand the scope and coordinate a fix + disclosure timeline.

If the vulnerability is accepted, we'll credit you in the release notes
(unless you'd prefer to remain anonymous).

## Security features in this codebase

Sonic Cloud includes several security-related features:

- **App PIN** — `SecurityService.setPin()` / `verifyPin()` — stored as a
  salted hash in `flutter_secure_storage` (Keystore on Android, Keychain on
  iOS, libsecret on Linux, Credential Manager on Windows).
- **Biometric unlock** — `SecurityService.unlockWithBiometrics()` via
  `local_auth`.
- **Secure cloud credential storage** — `SecurityService.storeCloudCredentials()`
  encrypts at rest in the OS keychain.
- **Granular per-provider permissions** — `ProviderPermissions` allows the
  user to grant read-only / read-write / no-delete etc. per cloud provider.
- **Optional offline-only mode** — `AppSettingsService.offlineOnlyMode`
  disables all network calls.

## Known limitations

- The audio fingerprinter uses a content-addressable SHA-256 hash, not
  perceptual hashing. It catches re-encodes of the same source but NOT
  different masters of the same song.
- The local REST API (`LocalApiService`) listens on `0.0.0.0:8765` by default,
  meaning any device on the same network can control playback. If you don't
  want this, don't call `start()` — it's opt-in.
- End-to-end encryption for synced user data is a planned feature; the
  `e2ee` setting currently has no crypto implementation.
