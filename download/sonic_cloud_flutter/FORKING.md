# Forking Sonic Cloud — Run Your Own Backend in 10 Minutes

> **Goal:** Set up a fully functional Sonic Cloud instance with your own free
> Turso database + Vercel deployment. No paid plans required.

This guide assumes you've forked [Exon101/sonic-cloud-flutter](https://github.com/Exon101/sonic-cloud-flutter)
and want to run your own instance with cross-device sync, auth, and the full
API backend.

---

## Prerequisites

You need three free accounts:

| Service | Purpose | Free tier | Sign up |
|---|---|---|---|
| **GitHub** | Host your fork | Unlimited public repos | [github.com](https://github.com) |
| **Vercel** | Host the Flutter web app + serverless API | 100K function invocations/day | [vercel.com](https://vercel.com) |
| **Turso** | Durable database (libSQL/SQLite) | 500 DBs, 9GB storage, 1B reads/month | [turso.tech](https://turso.tech) |

**Total cost: $0/month** for personal use (1–3 devices, <25K MAU).

---

## Step 1: Fork the repo (30 seconds)

1. Go to https://github.com/Exon101/sonic-cloud-flutter
2. Click **Fork** in the top right
3. You now have `https://github.com/<your-username>/sonic-cloud-flutter`

---

## Step 2: Create a Turso database (2 minutes)

1. Sign up at [turso.tech](https://turso.tech) (use GitHub OAuth — fastest)
2. Install the Turso CLI:
   ```bash
   # macOS
   brew install tursodatabase/tap/turso
   # Linux
   curl -sSfL https://get.tur.so/install.sh | bash
   ```
3. Log in:
   ```bash
   turso auth login
   ```
4. Create your database:
   ```bash
   turso db create sonic-cloud
   ```
5. Get your database URL:
   ```bash
   turso db show sonic-cloud --url
   # → libsql://sonic-cloud-<your-name>-<region>.turso.io
   ```
6. Create an auth token:
   ```bash
   turso db tokens create sonic-cloud
   # → eyJhbGciOiJFZERTQSIs...
   ```
7. Apply the database schema:
   ```bash
   # Clone your fork locally first (if you haven't)
   git clone https://github.com/<your-username>/sonic-cloud-flutter.git
   cd sonic-cloud-flutter

   # Install the Turso client
   npm install @libsql/client

   # Run the migration
   TURSO_DB_URL="libsql://sonic-cloud-<your-name>-<region>.turso.io" \
   TURSO_AUTH_TOKEN="eyJhbGciOiJFZERTQSIs..." \
   node scripts/migrate.js
   ```

   You should see:
   ```
   ▶ Connecting to libsql://sonic-cloud-...
   ▶ Running 13 schema statements…
     ✓ CREATE TABLE IF NOT EXISTS users (
     ✓ CREATE TABLE IF NOT EXISTS tracks (
     ...
   ▶ Done: 13 applied, 0 skipped, 0 failed
   ▶ Verifying tables:
     users: 0 rows
     tracks: 0 rows
     ...
   ```

**Save your Turso URL and token** — you'll need them in Step 3.

---

## Step 3: Deploy to Vercel (3 minutes)

1. Sign up at [vercel.com](https://vercel.com) (use GitHub OAuth)
2. Go to https://vercel.com/new
3. Import your fork: `sonic-cloud-flutter`
4. Vercel auto-detects `vercel.json` and the `rootDirectory` setting
5. **Before clicking Deploy**, set the environment variables:

   | Variable | Value | Where to get it |
   |---|---|---|
   | `TURSO_DB_URL` | `libsql://sonic-cloud-<your-name>-<region>.turso.io` | Step 2.5 |
   | `TURSO_AUTH_TOKEN` | `eyJhbGciOiJFZERTQSIs...` | Step 2.6 |
   | `SONIC_JWT_SECRET` | Any random string (e.g. `openssl rand -hex 32`) | Generate one |

   To set env vars:
   - Click **Settings** → **Environment Variables**
   - Add each variable for **Production**, **Preview**, and **Development**
   - Or use the Vercel CLI:
     ```bash
     vercel link  # link to your project
     vercel env add TURSO_DB_URL production preview development
     vercel env add TURSO_AUTH_TOKEN production preview development
     vercel env add SONIC_JWT_SECRET production preview development
     ```

6. Click **Deploy**
7. Wait ~2 minutes for the Flutter web build to complete
8. Your app is live at `https://<your-project>.vercel.app`

---

## Step 4: Verify it works (1 minute)

```bash
# Check the API is connected to Turso
curl https://<your-project>.vercel.app/api/status
# → {"ok":true,"database":"turso","stats":{"users":0,"tracks":0,...}}

# Sign up a test account
curl -X POST https://<your-project>.vercel.app/api/auth?action=signup \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com","password":"TestPass123!"}'
# → {"ok":true,"token":"eyJ...","userId":"usr_..."}

# Sign in (verify password works)
curl -X POST https://<your-project>.vercel.app/api/auth?action=signin \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com","password":"TestPass123!"}'
# → {"ok":true,"token":"eyJ...","userId":"usr_..."}

# Add a track (replace TOKEN with the token from above)
curl -X POST https://<your-project>.vercel.app/api/library \
  -H "Authorization: Bearer TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"id":"tr_1","title":"Test Track","artist":"Test Artist","duration":180}'
# → {"ok":true,"track":{"id":"tr_1",...}}
```

---

## Step 5: Point the Flutter app at your backend (optional)

If you want to run the Flutter app locally (mobile/desktop) against your own
backend instead of the default Vercel dev instance:

1. `flutter pub get`
2. `flutter run`
3. On the sign-in screen, click **Advanced** → enter your Vercel URL
4. The app saves the URL in SharedPreferences and uses it for all API calls

To change the default URL baked into the app, edit
`lib/services/api_client.dart`:

```dart
ApiClient({
  String baseUrl = 'https://<your-project>.vercel.app',  // ← change this
  ...
})
```

---

## (Optional) Enable Google Sign-In

Google OAuth is free but requires a Google Cloud project:

1. Go to https://console.cloud.google.com → **APIs & Services** → **Credentials**
2. **Create Credentials** → **OAuth client ID** → **Web application**
3. Add your Vercel URL to **Authorized JavaScript origins**:
   `https://<your-project>.vercel.app`
4. Copy the **Client ID** (ends in `.apps.googleusercontent.com`)
5. Set it as a Vercel env var:
   ```bash
   vercel env add GOOGLE_OAUTH_CLIENT_ID production
   # paste your client ID
   ```
6. Add it to the Flutter app via `--dart-define`:
   ```bash
   flutter build web --release \
     --dart-define=GOOGLE_SIGN_IN_CLIENT_ID=<your-client-id>.apps.googleusercontent.com
   ```
7. Redeploy — the "Continue with Google" button on the sign-in screen now works

---

## (Optional) Custom domain

1. In Vercel: **Settings** → **Domains** → add your domain
2. Add the DNS records Vercel shows you (CNAME or A record)
3. Wait for DNS to propagate (5–30 minutes)
4. Update `GOOGLE_OAUTH_CLIENT_ID` authorized origins if you use Google Sign-In

---

## Troubleshooting

### `/api/*` returns 404

**Cause:** Vercel's `rootDirectory` isn't set correctly.

**Fix:** Go to Vercel → Settings → General → Root Directory should be
`download/sonic_cloud_flutter`. If it's empty, set it manually via the Vercel
API:
```bash
curl -X PATCH \
  -H "Authorization: Bearer $(vercel token)" \
  -H "Content-Type: application/json" \
  "https://api.vercel.com/v9/projects/<project-name>?teamId=<team-id>" \
  -d '{"rootDirectory":"download/sonic_cloud_flutter"}'
```

### `/api/*` returns `FUNCTION_INVOCATION_TIMEOUT`

**Cause:** Handler signature mismatch (shouldn't happen after M1 fix, but
documented for reference).

**Fix:** All handlers must use the `(req, res) => void` signature via the
`toVercel()` adapter. See `api/_lib/http.js`.

### Data doesn't persist across cold starts

**Cause:** `TURSO_DB_URL` or `TURSO_AUTH_TOKEN` env vars not set on Vercel.
The API falls back to in-memory storage when they're missing.

**Fix:** Check `curl https://<your-project>.vercel.app/api/status` — the
`database` field should say `"turso"`, not `"memory"`.

### Build fails with "12 serverless functions" error

**Cause:** Vercel Hobby plan limits each deployment to 12 serverless functions.

**Fix:** The repo is already consolidated to 9 functions. If you add more,
consolidate them using the `?action=` query param pattern (see
`api/auth.js` and `api/sync.js` for examples).

### Flutter web shows white screen

**Cause:** Usually a compile error in the Flutter build.

**Fix:** Check the Vercel deployment logs. Common causes:
- A package uses `dart:html` or `dart:js_util` (unsupported in dart2js release mode)
- A dynamic `import()` call (Dart doesn't support this — use static imports)

### `flutter_secure_storage` breaks the web build

**Cause:** The `flutter_secure_storage_web` plugin uses `dart:html`.

**Fix:** Already handled — the package is commented out in `pubspec.yaml`
and `SecurityService` uses a no-op stub on web. If you need secure storage on
mobile/desktop, uncomment it and use conditional imports:
```dart
import 'secure_storage_stub.dart'
    if (dart.library.io) 'package:flutter_secure_storage/flutter_secure_storage.dart';
```

---

## Architecture summary

```
┌─────────────────────────────────────────────────────────────────┐
│  Your Vercel deployment                                         │
│                                                                 │
│  ┌─────────────────┐     ┌──────────────────────────────────┐  │
│  │  Flutter web    │     │  Vercel Serverless Functions     │  │
│  │  (build/web/)   │     │  (9 endpoints)                   │  │
│  │                 │────▶│                                  │  │
│  │  - Sign-in UI   │     │  /api/auth?action=signin|signup| │  │
│  │  - Library      │     │         oauth|me                  │  │
│  │  - Now Playing  │     │  /api/library (CRUD + ?since=)    │  │
│  │  - Settings     │     │  /api/playlists (CRUD + ?since=)  │  │
│  │  - SyncEngine   │     │  /api/lyrics (GET + PUT)          │  │
│  │    (polls 45s)  │     │  /api/sync?action=push|pull       │  │
│  └─────────────────┘     │  /api/devices (list + revoke)     │  │
│                          │  /api/status (health)             │  │
│                          └──────────┬───────────────────────┘  │
│                                     │                           │
└─────────────────────────────────────┼───────────────────────────┘
                                      │ HTTPS (libSQL protocol)
                                      ▼
                          ┌────────────────────────┐
                          │  Your Turso database   │
                          │  (libSQL/SQLite)       │
                          │                        │
                          │  Tables:               │
                          │  - users (auth)        │
                          │  - tracks (library)    │
                          │  - playlists           │
                          │  - lyrics              │
                          │  - devices             │
                          │  - sync_state          │
                          └────────────────────────┘
```

---

## Cost breakdown

| Resource | Free tier limit | Your expected usage |
|---|---|---|
| Turso reads | 1,000,000,000/month | ~500,000 (45s polling × 30 days) |
| Turso writes | 25,000,000/month | ~50,000 |
| Turso storage | 9 GB | <100 MB (metadata only) |
| Vercel bandwidth | 100 GB/month | <1 GB |
| Vercel function invocations | 100,000/day | ~3,000/day (45s polling) |
| Vercel build minutes | 6,000/month | ~60 (1 per push) |

**You'll use <0.1% of every free tier.** No paid plan needed for personal use.

---

## What's next?

- **M4 (this guide)** — Forking guide ✅
- **Future** — Listening parties, community theme store, ffmpeg downloads (see `FUTURE_DEVELOPMENT.md`)
- **Self-hosting alternative** — If you prefer to fully self-host (no Vercel, no Turso), see the PocketBase alternative in `BACKEND_SYNC_PLAN.md` Appendix C

---

## Questions?

Open an issue at https://github.com/Exon101/sonic-cloud-flutter/issues
