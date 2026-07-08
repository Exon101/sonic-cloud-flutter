# Deployment Guide

This document covers every deployment option for Sonic Cloud. Pick the one
that matches your target platform.

## Table of contents

- [Quick start: local build](#quick-start-local-build)
- [Web deployment](#web-deployment)
  - [Firebase Hosting](#firebase-hosting) *(production — large-scale)*
  - [Vercel](#vercel) *(dev / small-scale alternative — also hosts the /api backend)*
  - [Self-hosted (Docker)](#docker) *(own server)*
  - [Netlify](#netlify) *(alt static host)*
- [Serverless API](#serverless-api)
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

## Quick start: fork + deploy in 10 minutes

See **[FORKING.md](FORKING.md)** for the complete step-by-step guide to
running your own Sonic Cloud backend with free Turso + Vercel accounts.

## Quick start: local build

```bash
git clone https://github.com/Exon101/sonic-cloud-flutter.git
cd sonic-cloud-flutter
flutter pub get
./scripts/build.sh web          # or: apk | aab | ios | macos | windows | linux | all
```

---

## Web deployment

Sonic Cloud supports four web-hosting targets. The recommended pattern is:

| Tier | Host | Why |
|---|---|---|
| **Production (large-scale)** | Firebase Hosting | Global CDN, autoscaling, integrates with Firebase Auth/Functions/Analytics, supports multiple sites per project, atomic deploys with rollback |
| **Dev / small-scale alternative** | Vercel | One-click deploys, ships both Flutter web bundle **and** the `/api` serverless backend in the same project, zero config |
| **Self-hosted (own server)** | Docker (nginx) | Full control, on-prem, air-gapped, or behind your own CDN |
| **Alt static host** | Netlify | Flutter web bundle only — no `/api` functions |

### Firebase Hosting

> **Recommended for production.** Firebase Hosting pairs with Firebase Auth,
> Cloud Functions, Cloud Firestore, and Analytics — and the project already
> uses Firebase for mobile App Distribution, so this is the natural primary.

1. Install the Firebase CLI: `npm install -g firebase-tools`
2. Log in: `firebase login`
3. Create a project at https://console.firebase.google.com/ named `sonic-cloud-app`
   (or update `.firebaserc` to point at your project ID).
4. Build the web bundle:

   ```bash
   ./scripts/build.sh web
   ```

5. Deploy:

   ```bash
   ./scripts/deploy_web.sh firebase
   # → https://<project>.web.app and https://<project>.firebaseapp.com
   ```

**Multiple environments (dev / staging / prod)**

Firebase supports multiple Hosting sites per project. Configure them in
`.firebaserc` under `targets.hosting`, then deploy by target name:

```bash
firebase deploy --only hosting:web        # production site
firebase deploy --only hosting:web-staging # staging site
```

**Pairing with the serverless API**

The `api/` serverless backend can be deployed as Firebase Cloud Functions
instead of Vercel Functions. The handlers use the standard
`(req, res)` signature compatible with Firebase Functions v2 (HTTP). Wrap
each handler:

```js
// functions/index.js
const { onRequest } = require('firebase-functions/v2/https');
const status = require('../api/status');

exports.apiStatus = onRequest({ cors: true }, (req, res) => status(req, res));
// …repeat per endpoint…
```

A full Firebase-Functions adapter is on the roadmap (see FEATURES.md). Until
then, the recommended production setup is **Firebase Hosting (Flutter web) +
Vercel Functions (the API)** — they share a public origin via Firebase
Hosting rewrites, or you can deploy the API independently and configure CORS.

### Vercel

> **Recommended for development and small-scale production.** Vercel ships
> both the Flutter web bundle **and** the `api/` serverless functions in a
> single deployment — the simplest end-to-end option.

1. Push the repo to GitHub.
2. Go to https://vercel.com/new and import the repo.
3. Vercel auto-detects `vercel.json` and runs `scripts/vercel_build.sh`. The
   `api/` directory is automatically detected and deployed as Serverless
   Functions alongside the Flutter web bundle.
4. Click Deploy. Your app is live at `https://<project>.vercel.app` and the
   API at `https://<project>.vercel.app/api/*`.

**Live demo (dev deployment):** https://sonic-cloud-kappa.vercel.app/
**API status:** https://sonic-cloud-kappa.vercel.app/api/status

Manual CLI deploy:

```bash
npm install -g vercel
vercel        # link the project (first run only)
vercel --prod # deploy to production
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
nginx on port 8080. Healthcheck hits `/` every 30s. Pair with your own
reverse proxy (Caddy / nginx / Traefik / Cloudflare) for TLS and custom
domains.

### Netlify

> Static-hosting alternative. Netlify does **not** support the `api/`
> serverless functions as written (Vercel-style). Use Firebase or Vercel
> if you need the backend, or pair Netlify-hosted web with a separately
> deployed API.

1. Push the repo to GitHub.
2. Go to https://app.netlify.com/start and import the repo.
3. Netlify auto-detects `netlify.toml` and runs `scripts/netlify_build.sh`.
4. Deploy.

Manual CLI deploy:

```bash
npm install -g netlify-cli
./scripts/deploy_web.sh netlify
```

---

## Serverless API

The `api/` directory contains a Node.js serverless backend that ships with the
repo and is automatically deployed to Vercel Functions alongside the web
bundle. See [`api/README.md`](api/README.md) for the full endpoint reference.

### Endpoints at a glance

| Method | Path                       | Auth | Description |
|--------|----------------------------|------|-------------|
| GET    | `/api/status`              | No   | Health + version + endpoint list |
| POST   | `/api/auth/signin`         | No   | Email or anonymous sign-in → `token` |
| GET    | `/api/auth/me`             | Yes  | Current user + session |
| GET    | `/api/library`             | Yes  | List user's cloud tracks |
| POST   | `/api/library`             | Yes  | Upsert a track |
| GET    | `/api/library/:id`         | Yes  | Fetch one track |
| PUT    | `/api/library/:id`         | Yes  | Replace one track |
| DELETE | `/api/library/:id`         | Yes  | Delete one track |
| GET    | `/api/playlists`           | Yes  | List playlists |
| POST   | `/api/playlists`           | Yes  | Create playlist (manual / smart / auto) |
| GET    | `/api/playlists/:id`       | Yes  | Fetch one playlist |
| PUT    | `/api/playlists/:id`       | Yes  | Replace |
| PATCH  | `/api/playlists/:id`       | Yes  | Partial patch (`addTrackIds`, `removeTrackIds`, …) |
| DELETE | `/api/playlists/:id`       | Yes  | Delete |
| GET    | `/api/lyrics?trackId=`     | Yes  | Fetch parsed lyrics |
| PUT    | `/api/lyrics?trackId=`     | Yes  | Store lyrics |
| POST   | `/api/sync/push`           | Yes  | Merge queue/favorites/ratings/positions/settings |
| GET    | `/api/sync/pull?since=`    | Yes  | Fetch full sync state |
| GET    | `/api/devices`             | Yes  | List active sessions |
| DELETE | `/api/devices?prefix=`     | Yes  | Revoke a session by token prefix |

### Quick smoke test

```bash
# Anonymous sign-in
curl -X POST https://sonic-cloud-kappa.vercel.app/api/auth/signin \
  -H 'Content-Type: application/json' \
  -d '{"anonymous": true}'
# → { "ok": true, "token": "a1b2…", "userId": "usr_…" }

# Use the token to list your library
curl https://sonic-cloud-kappa.vercel.app/api/library \
  -H "Authorization: Bearer a1b2…"
```

### Production storage ⚠️

Out of the box, `api/_lib/store.js` uses an in-memory `Map` so the API runs
with zero infrastructure. In production, serverless functions are
stateless — each invocation may land on a different instance, so writes
will not reliably persist.

To make the API durable, swap the `Store` class for one backed by:
- **Vercel KV** (Redis-compatible, free tier) — easiest, same vendor
- **Vercel Postgres** — for relational queries
- **Upstash Redis** or **Supabase** — managed alternatives

The public surface (`get/set/delete/list` per resource) is intentionally
small so a real backend can be dropped in without touching the route
handlers. See `api/_lib/store.js` for the swap point.

### Local API development

```bash
npm install -g vercel
vercel dev  # serves both Flutter web + /api/* at http://localhost:3000
```

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

`codemagic.yaml` defines four workflows:
- **android-workflow** — triggered by tag push; builds APK+AAB; publishes to Firebase App Distribution + Play Store
- **ios-workflow** — triggered by tag push; builds IPA; publishes to Firebase App Distribution + TestFlight
- **web-workflow-firebase** — triggered by tag push (release); builds web bundle; deploys to **Firebase Hosting (production)**
- **web-workflow-vercel** — triggered by push to `main`; builds web bundle; deploys to **Vercel (dev / small-scale)** — also serves the `/api` serverless functions

Connect your GitHub repo at https://codemagic.io and set the required
environment variables in the Codemagic UI. The split lets you ship to dev
on every commit (`web-workflow-vercel`) and cut a production release by
tagging (`web-workflow-firebase`).

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
| `FIREBASE_PROJECT_ID` | Firebase (Hosting + App Distribution) | Firebase console → Project settings |
| `VERCEL_TOKEN` | Vercel (dev web + /api) | https://vercel.com/account/tokens |
| `VERCEL_SCOPE` | Vercel | Vercel team/user slug (in your dashboard URL) |
| `VERCEL_PROJECT_ID` | Vercel (optional) | Auto-linked on first deploy if omitted |
| `CODECOV_TOKEN` | CI | https://codecov.io |

---

## Helper scripts

All scripts live in `scripts/` and are executable (`chmod +x` already applied).

| Script | What it does |
|---|---|
| `build.sh <target>` | Build any platform target (`web`, `apk`, `aab`, `ios`, `macos`, `windows`, `linux`, `all`) |
| `deploy_web.sh <target>` | Deploy web bundle: `firebase` (prod), `vercel` (dev + /api), `docker`, `netlify`, or `preview` (local http.server) |
| `deploy_android.sh <target>` | Deploy Android: `install`, `firebase`, `playstore` |
| `deploy_ios.sh <target>` | Deploy iOS: `install`, `firebase`, `testflight`, `appstore` |
| `vercel_build.sh` | Internal: Vercel build entrypoint |
| `netlify_build.sh` | Internal: Netlify build entrypoint |

Run any script with no args to see its help.
