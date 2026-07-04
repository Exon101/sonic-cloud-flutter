# Deployment Guide

This document covers every deployment option for Sonic Cloud. Pick the one
that matches your target platform.

## Table of contents

- [Quick start: local build](#quick-start-local-build)
- [Web deployment](#web-deployment)
  - [Vercel](#vercel)
  - [Netlify](#netlify)
  - [Firebase Hosting](#firebase-hosting)
  - [Docker](#docker)
- [Android deployment](#android-deployment)
  - [Local install (debug)](#local-install-debug)
  - [Firebase App Distribution](#firebase-app-distribution)
  - [Google Play Store](#google-play-store)
- [iOS deployment](#ios-deployment)
  - [Local install](#local-install)
  - [Firebase App Distribution](#firebase-app-distribution-1)
  - [TestFlight](#testflight)
  - [App Store](#app-store)
- [Desktop deployment](#desktop-deployment)
  - [macOS](#macos)
  - [Windows](#windows)
  - [Linux](#linux)
- [CI/CD](#cicd)
  - [GitHub Actions](#github-actions)
  - [Codemagic](#codemagic)
- [Required environment variables](#required-environment-variables)
- [Helper scripts](#helper-scripts)

---

## Quick start: local build

```bash
git clone https://github.com/Exon101/sonic-cloud-flutter.git
cd sonic-cloud-flutter
flutter pub get
./scripts/build.sh web          # or: apk | aab | ios | macos | windows | linux | all
```

---

## Web deployment

### Vercel

1. Push the repo to GitHub.
2. Go to https://vercel.com/new and import the repo.
3. Vercel auto-detects `vercel.json` and runs `scripts/vercel_build.sh`.
4. Click Deploy. Your app is live at `https://<project>.vercel.app`.

Manual CLI deploy:

```bash
npm install -g vercel
./scripts/deploy_web.sh vercel
```

### Netlify

1. Push the repo to GitHub.
2. Go to https://app.netlify.com/start and import the repo.
3. Netlify auto-detects `netlify.toml` and runs `scripts/netlify_build.sh`.
4. Deploy.

Manual CLI deploy:

```bash
npm install -g netlify-cli
./scripts/deploy_web.sh netlify
```

### Firebase Hosting

1. Install the Firebase CLI: `npm install -g firebase-tools`
2. Log in: `firebase login`
3. Create a project at https://console.firebase.google.com/ named `sonic-cloud-app`
4. Update `.firebaserc` to point to your project ID.
5. Deploy:

```bash
./scripts/deploy_web.sh firebase
```

### Docker

Build and run locally:

```bash
./scripts/deploy_web.sh docker
# → http://localhost:8080
```

Or use docker-compose (with optional Caddy TLS proxy):

```bash
docker compose up --build -d
docker compose logs -f
docker compose down
```

The Docker image (`sonic-cloud:latest`) is ~25 MB and serves the web bundle via
nginx on port 8080. Healthcheck hits `/` every 30s.

---

## Android deployment

### Local install (debug)

Connect a device with USB debugging enabled, then:

```bash
./scripts/deploy_android.sh install
```

### Firebase App Distribution

For internal tester builds:

```bash
# Set in .env:
#   FIREBASE_APP_ID_ANDROID=1:0000:android:abcd
#   FIREBASE_TOKEN=your_firebase_cli_token
./scripts/deploy_android.sh firebase
```

Testers receive an email invite and install via the Firebase App Distribution
Android app.

### Google Play Store

For production release:

```bash
# Set in .env:
#   ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
#   PLAY_STORE_JSON_KEY=/path/to/service-account.json
./scripts/deploy_android.sh playstore
```

This uses Fastlane (`bundle exec fastlane android playstore`) to:
1. Build a signed release AAB.
2. Upload to the `production` track as a draft.

---

## iOS deployment

> **Requires macOS.** iOS builds cannot run on Linux or Windows.

### Local install

Connect an iPhone and run:

```bash
./scripts/deploy_ios.sh install
```

### Firebase App Distribution

```bash
# Set in .env:
#   FIREBASE_APP_ID_IOS, FIREBASE_TOKEN
./scripts/deploy_ios.sh firebase
```

### TestFlight

```bash
# Set in .env:
#   APPLE_ID, TEAM_ID, MATCH_GIT_URL, MATCH_PASSWORD
./scripts/deploy_ios.sh testflight
```

Uses Fastlane match to fetch signing certs, builds an IPA, and uploads to
App Store Connect → TestFlight.

### App Store

```bash
./scripts/deploy_ios.sh appstore
```

Same as TestFlight but submits to the App Store review queue.

---

## Desktop deployment

### macOS

```bash
./scripts/build.sh macos
# Output: build/macos/Build/Products/Release/Sonic Cloud.app
```

Open the `.app` bundle directly. For distribution, you'll need to notarize it:
`xcrun notarytool submit ... --keychain-profile "AC_PASSWORD"`.

### Windows

```bash
./scripts/build.sh windows
# Output: build/windows/x64/runner/Release/sonic_cloud.exe
```

Zip the `Release/` folder for distribution. For an installer, use MSIX
(`flutter pub add msix` and `flutter pub run msix:create`).

### Linux

```bash
./scripts/build.sh linux
# Output: build/linux/x64/release/bundle/sonic_cloud
```

Tar the `bundle/` directory. For a Snap or Flatpak build, see
`flutter_to_debian`, `snapcraft`, or `flatpak-builder`.

---

## CI/CD

### GitHub Actions

Two workflows live in `.github/workflows/`:

| Workflow | File | Trigger | What it does |
|---|---|---|---|
| **CI** | `ci.yml` | push to `main`/`develop`, any PR | Format check · `flutter analyze` · `flutter test` · build web · build debug APK |
| **Release** | `release.yml` | tag push `v*.*.*` or manual | Build all 6 platforms + create GitHub Release with artifacts |

To create a release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The release workflow builds Android APK+AAB, web tarball, iOS .app, macOS .app, Windows .zip, Linux .tar.gz, and creates a GitHub Release with all artifacts attached.

### Codemagic

`codemagic.yaml` defines three workflows:
- **android-workflow** — triggered by tag push; builds APK+AAB; publishes to Firebase + Play Store
- **ios-workflow** — triggered by tag push; builds IPA; publishes to Firebase + TestFlight
- **web-workflow** — triggered by push to `main`; builds web bundle; deploys to Firebase Hosting

Connect your GitHub repo at https://codemagic.io and set the required
environment variables in the Codemagic UI.

---

## Required environment variables

Copy `.env.example` to `.env` and fill in real values. For CI, set these as
repository secrets.

| Variable | Used by | Where to get |
|---|---|---|
| `ANDROID_KEYSTORE_PATH` | Fastlane, scripts | Path to your release `.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Fastlane | Set when you created the keystore |
| `ANDROID_KEY_ALIAS` | Fastlane | `keytool -list -v -keystore x.jks` |
| `ANDROID_KEY_PASSWORD` | Fastlane | Set when you created the key |
| `ANDROID_KEYSTORE_BASE64` | GitHub Actions | `base64 keystore.jks \| pbcopy` |
| `PLAY_STORE_JSON_KEY` | Fastlane | Google Play Console → Setup → API access → service account |
| `APPLE_ID` | Fastlane | Your Apple Developer email |
| `TEAM_ID` | Fastlane | Apple Developer → Membership → Team ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | Fastlane | appleid.apple.com → sign-in & security |
| `MATCH_GIT_URL` | Fastlane | Private git repo for match certs |
| `MATCH_PASSWORD` | Fastlane | You set this when running `fastlane match init` |
| `FIREBASE_APP_ID_ANDROID` | Firebase | Firebase console → Project settings → Your apps |
| `FIREBASE_APP_ID_IOS` | Firebase | Same as above |
| `FIREBASE_TOKEN` | Firebase | `firebase login:ci` |
| `FIREBASE_PROJECT_ID` | Firebase | Firebase console → Project settings |
| `CODECOV_TOKEN` | CI | https://codecov.io |

---

## Helper scripts

All scripts live in `scripts/` and are executable (`chmod +x` already applied).

| Script | What it does |
|---|---|
| `build.sh <target>` | Build any platform target (`web`, `apk`, `aab`, `ios`, `macos`, `windows`, `linux`, `all`) |
| `deploy_web.sh <target>` | Deploy web bundle to `docker`, `vercel`, `netlify`, `firebase`, or `preview` (local http.server) |
| `deploy_android.sh <target>` | Deploy Android: `install`, `firebase`, `playstore` |
| `deploy_ios.sh <target>` | Deploy iOS: `install`, `firebase`, `testflight`, `appstore` |
| `vercel_build.sh` | Internal: Vercel build entrypoint |
| `netlify_build.sh` | Internal: Netlify build entrypoint |

Run any script with no args to see its help.
