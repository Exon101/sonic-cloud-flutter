# Contributing to Sonic Cloud

Thanks for your interest in improving Sonic Cloud! This document covers the
basics of getting a local dev environment set up and submitting changes.

## Quick start

```bash
git clone https://github.com/Exon101/sonic-cloud-flutter.git
cd sonic-cloud-flutter
flutter pub get
flutter run
```

You'll need Flutter ≥ 3.10 and Dart ≥ 3.0. Verify with `flutter doctor`.

## Development workflow

1. **Fork & branch.** Create a branch from `main` named after your change:
   - `feat/<short-description>` for new features
   - `fix/<short-description>` for bug fixes
   - `chore/<short-description>` for tooling, deps, refactors
   - `docs/<short-description>` for documentation only

2. **Make your changes.** Keep commits focused — one logical change per commit.
   Use [conventional commit messages](https://www.conventionalcommits.org/):
   ```
   feat(equalizer): add 31-band mode toggle
   fix(webdav): handle relative paths in listAudioFiles
   chore(deps): bump just_audio to 0.10.6
   ```

3. **Run the checks.** Before pushing:
   ```bash
   dart format .
   flutter analyze --no-fatal-infos
   flutter test
   ```
   CI will run all three on every push and PR. Don't push code that fails
   locally.

4. **Open a PR.** Fill in the [PR template](.github/pull_request_template.md).
   Link any issues it closes (e.g. `Closes #123`).

5. **Code review.** A maintainer will review. Address feedback by pushing new
   commits — don't force-push mid-review unless asked.

## Code style

- Run `dart format .` — the formatter is authoritative.
- `flutter analyze` must pass with no warnings (infos are OK at PR time).
- Prefer `const` constructors where possible.
- Public API goes in `lib/`, tests go in `test/` mirroring the lib structure.
- New service classes should extend `ChangeNotifier` and expose immutable
  getters; mutation methods should call `notifyListeners()`.

## Test conventions

- **Unit tests** for services: `test/<service_name>_test.dart`
- **Widget tests** for screens & widgets: `test/<widget_name>_test.dart`
- Use `mocktail` for mocks — it's already in `dev_dependencies`.
- Every new public method should have at least one happy-path test and one
  edge-case test.

Example:
```dart
test('setSpeed clamps to 0.5..3.0', () async {
  await svc.setSpeed(0.1);
  expect(svc.speed, 0.5);
  await svc.setSpeed(5.0);
  expect(svc.speed, 3.0);
});
```

## Architecture overview

```
lib/
├── models/         ← immutable domain classes (Track, Album, Playlist, …)
├── services/       ← ChangeNotifier-based business logic
├── providers/      ← cloud storage provider implementations
├── plugins/        ← plugin extension points
├── db/             ← SQLite persistence (sqflite)
├── security/       ← PIN / biometric / secure storage
├── accessibility/  ← a11y settings
├── api/            ← local REST + WebSocket
├── gestures/       ← gesture overlay widgets
├── fingerprint/    ← audio fingerprinting
├── theme/          ← design tokens (colors, typography, spacing)
├── widgets/        ← reusable UI components
└── screens/        ← full-screen pages
```

Services are injected via constructors (no DI framework) — see
`lib/main.dart`'s `_HomeShellState` for the wiring graph.

## Adding a new cloud provider

1. Create `lib/providers/<your_provider>.dart` extending `CloudProvider`.
2. Implement all 9 abstract methods (`connect`, `disconnect`,
   `listAudioFiles`, `streamUrl`, `downloadFile`, `uploadFile`, `deleteFile`,
   `pullChanges`, plus the `status` getter).
3. Add a case to the `makeProvider` factory in
   `lib/providers/cloud_providers.dart`.
4. Add a value to the `CloudProviderKind` enum in `lib/models/models.dart`.
5. Write tests in `test/<your_provider>_test.dart` (mock the HTTP layer).

## Reporting bugs

Open an issue using the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md).
Include:
- Platform (Android / iOS / macOS / Linux / Windows / Web)
- App version or commit SHA
- Repro steps
- Expected vs. actual behavior
- Screenshots if it's a UI bug

## Security disclosures

See [SECURITY.md](.github/SECURITY.md). **Do not open public issues for
security vulnerabilities** — email the maintainer instead.

## License

By contributing, you agree that your contributions will be licensed under the
project's MIT license.
