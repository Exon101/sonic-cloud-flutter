# Sonic Cloud — Backend Sync Plan

> **Status:** Draft v1.0 (2026-07-07) — for team review before implementation
> **Owner:** Backend working group
> **Goal:** Make Sonic Cloud sync a user's library, playlists, playback state, and settings across web, mobile (Android/iOS), and desktop (macOS/Windows/Linux) through a durable backend.

---

## 1. Goals

### 1.1 User-visible outcomes

| Capability | What the user sees |
|---|---|
| **One library everywhere** | Tracks I added on my phone show up on my PC and in the web app within seconds. |
| **Playback resume** | I pause a song on my laptop at 2:13, pick up my phone, hit play — it resumes from 2:13. |
| **Playlists follow me** | A playlist I build on the web appears on my phone, ready to play. |
| **Favorites & ratings everywhere** | Hearting a track on mobile updates the heart on every device. |
| **Queue continuity** | The current queue is restored when I open the app on a new device. |
| **Settings sync** | Theme, EQ preset, default speed, sleep timer action — all follow me. |
| **Sign-in once** | Email or OAuth on one device; sign in on another with the same account. |
| **Offline-friendly** | When I lose connection, local state still works; sync resumes on reconnect. |

### 1.2 Non-goals (this phase)

- **Audio byte streaming from our backend.** Audio files stay on the user's device or in their connected cloud providers (Google Drive, WebDAV, etc.). Our backend syncs *metadata* only — file paths, IDs, and per-source identifiers — so each device resolves the audio locally. Streaming our own hosted audio is a separate v2 initiative.
- **Social features** (sharing, following, public profiles).
- **Music catalog / metadata lookup** (we use the user's tags; no third-party metadata API).
- **End-to-end encryption of cloud-stored data** (E2EE is documented as a future option in `FEATURES.md`; this plan covers standard at-rest encryption only).

---

## 2. Current state

| Layer | What exists | What's missing |
|---|---|---|
| **Client (Flutter)** | Full app on web + Android + iOS + macOS + Windows + Linux. Local SQLite (Drift) for library, SharedPreferences for settings, just_audio for playback, audio_service for OS media controls. `VercelSyncService` already implements the abstract `SyncService` contract — auth, queue, favorites, ratings, positions, settings, devices. | Local writes don't auto-push to cloud; pull happens once on sign-in. No real-time updates when another device changes data. |
| **API (`api/`)** | 14 Node.js serverless functions on Vercel. JWT auth (HS256, self-contained). Endpoints: `/auth/signin`, `/auth/me`, `/library` CRUD, `/playlists` CRUD, `/lyrics` GET/PUT, `/sync/push`, `/sync/pull`, `/devices` list/revoke. | In-memory `Map` store — **data does not persist** across serverless invocations. No real-time push (no WebSocket / SSE). No OAuth. No file upload endpoint. |
| **Hosting** | Vercel (dev/small-scale) + Firebase Hosting (production primary). Codemagic CI for both. | No backing data store configured on either. |
| **Auth** | JWT issued by `/auth/signin` (email or anonymous). Token carries `{userId, deviceId}`. | No password, no OAuth, no email verification, no refresh tokens. |
| **Tests** | 39 backend tests (13 unit + 26 e2e) + Flutter widget/unit tests. | No integration tests against a real database. No load tests. |

**The single biggest gap:** the backend has no durable storage. Fixing this is the primary deliverable of this plan.

---

## 3. Architecture options

We evaluated three options. **Option B (Firebase)** is recommended — it's already our production hosting primary, integrates natively with Flutter, and gives us auth + DB + storage + realtime in one platform.

### Option A — Vercel + Vercel KV/Postgres

```
Flutter app ──HTTPS──> Vercel Functions (Node) ──> Vercel KV (Redis)
                                                  └> Vercel Postgres (SQL)
```

**Pros:** Stays on the existing Vercel stack. Minimal code changes — `api/_lib/store.js` is the only swap point. Edge-deployed globally. Generous free tier.

**Cons:** Vercel KV is Redis-compatible (great for queues/sessions, awkward for relational data like playlists-with-rules). Vercel Postgres is just Neon — fine, but adds a second vendor. No native realtime — we'd build SSE manually. No file storage (audio hosting would need S3/R2 separately).

### Option B — Firebase (Firestore + Auth + Storage + Functions)  ⭐ RECOMMENDED

```
Flutter app ──Firestore SDK──> Firestore (NoSQL docs + realtime listeners)
              │
              ├─Firebase Auth──> Email / Google / Apple / Anonymous
              │
              └─Cloud Storage──> Audio file uploads (v2)
              │
              └─Cloud Functions─> Triggered logic (dedupe, fingerprint, etc.)
```

**Pros:**
- **Already our production hosting primary.** One platform for hosting + DB + auth + storage + functions.
- **Native Flutter SDK** — offline cache, realtime listeners, atomic writes built in. We delete ~300 lines of HTTP plumbing.
- **Realtime sync is free** — Firestore `onSnapshot()` listeners push changes to every connected device in <500ms.
- **Auth providers out of the box** — email/password, email link, Google, Apple, anonymous, phone.
- **Security rules** — declarative per-document ACLs in 30 lines.
- **Generous free tier** — 50K reads/day, 20K writes/day, 1GB storage, 1GB transfer/day.

**Cons:**
- NoSQL — we redesign the data model (not hard; our data is naturally document-shaped).
- Vendor lock-in (mitigated by keeping the `SyncService` abstraction — a Supabase backend would be a drop-in).
- Realtime listeners cost reads; we need to be thoughtful about listener granularity.

### Option C — Supabase (Postgres + Realtime + Auth + Storage)

```
Flutter app ──Supabase SDK──> Postgres (SQL + RLS)
                              └> Realtime (Postgres replication)
                              └> Auth (GoTrue)
                              └> Storage (S3-compatible)
```

**Pros:** Open-source, PostgreSQL (relational + JSONB), row-level security, generous free tier, no vendor lock-in.

**Cons:** Smaller Flutter community than Firebase. Realtime is less mature than Firestore. Would need to migrate off Firebase Hosting (or run Supabase alongside Firebase Hosting, adding a vendor).

### Recommendation: **Option B (Firebase)**

- Lowest total cost (single vendor, single console, single billing).
- Smallest code footprint — Firestore SDK replaces `ApiClient` + `VercelSyncService` + `ApiLibrarySync` + `ApiPlaylistSync` + `VercelLyricsProvider` (5 files).
- Realtime is a feature, not an engineering project.
- Existing Vercel dev deployment stays as the small-scale / preview environment.

---

## 4. Recommended stack

| Concern | Choice | Why |
|---|---|---|
| **Database** | Cloud Firestore (Native mode) | Document DB, realtime listeners, offline cache, security rules |
| **Auth** | Firebase Authentication | Email/password, email link, Google, Apple, anonymous; integrates with Firestore security rules |
| **File storage** | Cloud Storage for Firebase (v2) | Audio file uploads (if we ever host audio); cover art cache |
| **Server logic** | Cloud Functions (2nd gen) | Triggered by Firestore writes (dedupe, fingerprint, metadata enrichment); HTTP endpoints for things the SDK can't do |
| **Realtime** | Firestore `onSnapshot()` | Push changes to all connected devices in <500ms; no extra infra |
| **Push notifications** | Firebase Cloud Messaging | "Your sync just completed" / "New device signed in" (optional, v1.1) |
| **Hosting** | Firebase Hosting (production) + Vercel (dev) | Unchanged from current setup |
| **Client SDK** | `cloud_firestore` + `firebase_auth` + `firebase_storage` Flutter packages | Already popular in the Flutter ecosystem; offline persistence built in |
| **Local DB** | Drift (SQLite) — keep as-is | Acts as the offline cache; sync engine reads/writes through it |
| **Secrets** | Google Secret Manager | Service-account keys, third-party API keys |

---

## 5. Data model

Firestore is NoSQL — we model for the queries we'll run, not for normalization. Five top-level collections, all scoped by `userId`:

```
users/{userId}                    ← auth profile + settings
library/{userId}_tracks/{trackId} ← one doc per track in the user's library
playlists/{userId}_playlists/{playlistId}
lyrics/{userId}_lyrics/{trackId}  ← keyed by trackId so fetch is O(1)
devices/{userId}_devices/{deviceId} ← session list, last-seen, push token
syncState/{userId}                ← single doc per user: queue, current track, position
```

### 5.1 Document shapes

**`users/{userId}`**
```json
{
  "email": "alex@example.com",          // null for anonymous
  "isAnonymous": false,
  "displayName": "Alex Mercer",
  "avatarUrl": "https://...",
  "tier": "premium",                    // or "guest"
  "createdAt": 1783415109000,
  "lastSeenAt": 1783415109000,
  "settings": {
    "themeMode": "dark",                // system | dark | light | amoled | dynamic
    "accentColor": "#00F4FE",
    "defaultRepeatMode": "off",
    "defaultShuffle": false,
    "defaultSpeed": 1.0,
    "crossfadeMs": 4000,
    "replayGainEnabled": true,
    "volumeNormalizationEnabled": true,
    "eqPreset": "rock",
    "sleepEndAction": "pause",
    "telemetryEnabled": false,
    "offlineOnlyMode": false
  }
}
```

**`library/{userId}_tracks/{trackId}`** — mirrors the existing `Track` model, with these notes:
- `duration` stored as seconds (float), matching the current `/api/library` shape.
- `audioUrl` and `artUrl` are **per-device** — they're not stored server-side because the URL depends on where the audio bytes live for that device. The server stores `fileSystemPath`, `cloudProvider`, and `sourceId` so each device can resolve the audio locally.
- `embeddedLyrics` not synced (large, rarely changes — synced separately via the `lyrics` collection).
- `lastPlayedAt` and `playCount` synced last-writer-wins (see §6).

```json
{
  "title": "Midnight City",
  "artist": "M83",
  "album": "Hurry Up, We're Dreaming",
  "albumArtist": "M83",
  "genre": "Electronica",
  "composer": "Anthony Gonzalez",
  "year": 2011,
  "duration": 244.0,
  "format": "mp3",
  "fileSize": 5822933,
  "fileSystemPath": "/music/m83/midnight_city.mp3",
  "cloudProvider": "googleDrive",
  "sourceId": "gdrive:file_id_abc123",
  "rating": 5,
  "playCount": 12,
  "lastPlayedAt": 1783415109000,
  "dateAdded": 1783000000000,
  "isFavorite": true,
  "isCloudOnly": false,
  "updatedAt": 1783415109000,
  "updatedByDevice": "dev_abc"
}
```

**`playlists/{userId}_playlists/{playlistId}`**
```json
{
  "name": "Late Night Drive",
  "kind": "manual",                     // manual | smart | auto
  "trackIds": ["tr_a", "tr_b", "tr_c"],
  "rules": [],                          // for smart: [{field, op, value}]
  "autoKind": null,                     // for auto: "favorites" | "mostPlayed" | ...
  "description": null,
  "artUrl": null,
  "createdAt": 1783415109000,
  "updatedAt": 1783415109000,
  "updatedByDevice": "dev_abc"
}
```

**`lyrics/{userId}_lyrics/{trackId}`**
```json
{
  "raw": "[ti:Midnight City]\n[ar:M83]\n[00:12.34] Waiting in the car…",
  "provider": "user",                   // user | lrclib | musixmatch | ...
  "synced": true,
  "updatedAt": 1783415109000
}
```

**`devices/{userId}_devices/{deviceId}`**
```json
{
  "name": "MacBook Pro",
  "platform": "macos",                  // web | android | ios | macos | windows | linux
  "appVersion": "3.1.0",
  "pushToken": null,                    // FCM token (optional, for push notifications)
  "createdAt": 1783415109000,
  "lastSeenAt": 1783415109000,
  "isRevoked": false
}
```

**`syncState/{userId}`** — single document, the source of truth for "what's playing right now"
```json
{
  "queue": ["tr_a", "tr_b", "tr_c"],
  "currentIndex": 1,
  "shuffleEnabled": false,
  "repeatMode": "off",                  // off | all | one
  "speed": 1.0,
  "positionSec": 73.4,                  // last reported position
  "positionUpdatedAt": 1783415109000,   // when position was reported (so other devices can extrapolate)
  "playing": false,
  "updatedAt": 1783415109000,
  "updatedByDevice": "dev_abc"
}
```

### 5.2 Why subcollections keyed by `userId`?

We use `{userId}_tracks` as the collection name (not a subcollection under `users/{userId}/tracks`) because Firestore charges per-read of parent docs. With this layout, a query for "all my tracks" is one collection-group query — no parent-doc reads.

### 5.3 Indexes

- `library/{userId}_tracks`: composite index on `(artist ASC, title ASC)` for sorted browsing.
- `library/{userId}_tracks`: composite index on `(lastPlayedAt DESC)` for "Recently Played".
- `library/{userId}_tracks`: composite index on `(playCount DESC)` for "Most Played".
- `playlists/{userId}_playlists`: single-field index on `updatedAt DESC` (default).

All indexes are auto-declared via `firestore.indexes.json` in the repo.

---

## 6. Sync protocol

### 6.1 Conflict resolution strategy

| Field type | Strategy | Rationale |
|---|---|---|
| **Scalars** (title, artist, rating, etc.) | Last-writer-wins (LWW) using `updatedAt` timestamp | These rarely change; when they do, the latest edit wins. |
| **Counter-like** (playCount) | **Merge** — increment, don't overwrite | If two devices both play a track, we want the sum, not the latest. Use `FieldValue.increment(1)` on each play. |
| **Set-like** (playlist.trackIds, favorites) | **ArrayUnion / ArrayRemove** | Adding a track on one device + removing on another should both take effect. |
| **Timestamps** (lastPlayedAt) | LWW | Latest play wins. |
| **Settings** (themeMode, etc.) | LWW on the whole `settings` map | Settings are rare; user typically sets once. |
| **Queue + position** (`syncState`) | LWW but with smart fallback | See §6.3. |

### 6.2 Write paths

Three write paths, each with different latency guarantees:

1. **Optimistic local write** (immediate) — the Flutter app writes to local Drift + updates the UI instantly. The user sees no latency.
2. **Background push** (~100ms) — a `SyncEngine` debounce-queues the write to Firestore. If offline, the write sits in the local queue and flushes on reconnect.
3. **Realtime broadcast** (<500ms) — Firestore `onSnapshot()` listeners on other devices fire, updating their local Drift + UI.

### 6.3 "Now Playing" continuity

When device A pauses at position 73.4s, it writes `syncState { positionSec: 73.4, positionUpdatedAt: <now>, playing: false }`. Device B opens the app:

1. Reads `syncState` → sees position 73.4s at timestamp T.
2. If `playing: true` on the server, device B extrapolates: `currentPosition = 73.4 + (now - T)`.
3. If `playing: false`, device B uses 73.4s as the resume position.
4. Device B shows a "Resume from 1:13?" prompt (or auto-resumes, configurable in settings).

### 6.4 Throttling

- **Position reports**: throttled to once every 5 seconds (device-local), once every 15 seconds (to server).
- **Play count**: incremented locally, pushed once per session per track.
- **Settings changes**: pushed immediately (low volume).
- **Playlist edits**: pushed immediately (user expects instant feedback).

### 6.5 Conflict example

Device A and device B both rename playlist "Chill" — A renames to "Chill Vibes", B renames to "Late Night":

1. A writes `name: "Chill Vibes", updatedAt: 1000`.
2. B writes `name: "Late Night", updatedAt: 1001` (1ms later).
3. Firestore stores `name: "Late Night"` (LWW).
4. A's `onSnapshot()` listener fires with `name: "Late Night"`, A's UI updates.
5. User on A sees the rename they didn't make — but it's the latest intent. Acceptable for v1.

For v1.1 we could add a conflict-resolution UI ("Both devices renamed this playlist — keep 'Chill Vibes' or 'Late Night'?"), but the LWW approach covers 99% of cases without UI complexity.

---

## 7. Auth

### 7.1 Sign-in methods (priority order)

| Method | When | Notes |
|---|---|---|
| **Anonymous** | Default on first launch | One-tap; upgrades to email/OAuth later without losing data |
| **Email + password** | User chooses to sign in | Min 8 chars; hashed by Firebase Auth (PBKDF2 with salt) |
| **Email link** (passwordless) | User chooses "Sign in with email link" | 6-digit code or magic URL; great for desktop/web |
| **Google** | One-tap on Android/Chrome | Most common OAuth provider for mobile |
| **Apple** | Required for App Store apps that offer other OAuth | Apple mandates "Sign in with Apple" if you offer Google/Facebook |
| **GitHub** | Nice-to-have for developer audience | Quick add via Firebase console |

### 7.2 Token refresh

Firebase Auth handles this automatically — the Flutter SDK refreshes the ID token hourly and on app foreground. We don't need to build refresh logic.

### 7.3 Anonymous → identified upgrade

When an anonymous user signs in with email/Google, Firebase Auth's `linkWithCredential()` migrates their anonymous data to the new account — no data loss, no migration script.

### 7.4 Device management

- On sign-in, the client registers a `devices/{deviceId}` doc with platform, app version, and FCM push token.
- Heartbeat updates `lastSeenAt` every 5 minutes while the app is open.
- "Revoke" sets `isRevoked: true` — Firestore security rules deny reads for revoked devices, forcing a sign-out on next request.
- "Sign out everywhere" → batch-revoke all devices for the user.

---

## 8. Security

### 8.1 Firestore security rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own user doc
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }

    // Library tracks: scoped by userId prefix
    match /library/{userId}_tracks/{trackId} {
      allow read, write: if request.auth.uid == userId;
    }

    // Playlists
    match /playlists/{userId}_playlists/{playlistId} {
      allow read, write: if request.auth.uid == userId;
    }

    // Lyrics
    match /lyrics/{userId}_lyrics/{trackId} {
      allow read, write: if request.auth.uid == userId;
    }

    // Devices
    match /devices/{userId}_devices/{deviceId} {
      allow read: if request.auth.uid == userId;
      allow create, update: if request.auth.uid == userId;
      // Only the device itself can delete; user can revoke (sets isRevoked)
    }

    // Sync state
    match /syncState/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

### 8.2 Data validation

- **Cloud Functions** trigger on write to validate field types, enforce max sizes (e.g., playlist names ≤ 200 chars), and reject malformed payloads.
- **Client-side validation** in Dart catches most issues before the write hits Firestore.

### 8.3 Encryption

- **At rest**: Firestore encrypts all data at rest with AES-256 by default (no config needed).
- **In transit**: all Firestore connections use TLS 1.2+.
- **Client-side encryption (future)**: for users who want E2EE, we could encrypt sensitive fields (lyrics, ratings) client-side before write. Tracked in `FEATURES.md`.

### 8.4 Rate limiting

- Firestore security rules support `request.time` checks — we can cap writes per minute per user.
- For unauthenticated endpoints (signup, password reset), use Cloud Functions + reCAPTCHA Enterprise.

### 8.5 Audit log

- Every auth event (sign-in, sign-out, device add, device revoke) logged to a separate `auditLog/{userId}` collection with timestamp, IP (via Cloud Function), device info.
- Retained 90 days, then auto-deleted via TTL policy.

---

## 9. Real-time sync architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  Device A   │         │   Firestore  │         │  Device B   │
│ (phone)     │         │              │         │ (laptop)    │
│             │         │              │         │             │
│  User taps  │         │              │         │             │
│  "favorite" │         │              │         │             │
│      │      │         │              │         │             │
│      ▼      │         │              │         │             │
│  Write to   │ ────►   │ library/{uid}│         │             │
│  Firestore  │         │ _tracks/{id} │         │             │
│             │         │      │       │         │             │
│             │         │      │ onSnap│         │             │
│             │         │      ▼       │         │             │
│             │         │              │ ────►   │ Listener    │
│             │         │              │         │ fires, UI   │
│             │         │              │         │ updates     │
└─────────────┘         └──────────────┘         └─────────────┘
```

### 9.1 Listener granularity

Don't put a global listener on `library/{uid}_tracks` — that fires for every track change. Instead:

| Listener | Trigger | What it updates |
|---|---|---|
| `syncState/{uid}` | Queue, position, playing state | Mini-player + now-playing bar |
| `library/{uid}_tracks` (filtered) | Only tracks where `isFavorite == true` changes | Favorites list |
| `playlists/{uid}_playlists` | Playlist metadata + trackIds | Playlists list |
| `devices/{uid}_devices` | Device add/revoke | Settings → Devices list |
| `users/{uid}` (settings only) | Theme, EQ, etc. | App-wide theme |

Each listener is registered on app open and torn down on app close. Total: ~5 active listeners, ~50 reads/hour per device.

### 9.2 Offline behavior

- Firestore SDK has a built-in offline cache (10MB default, configurable up to 100MB on web, unlimited on mobile).
- All writes while offline are queued locally and flushed on reconnect — no app code needed.
- Listeners fire with local data immediately, then re-fire when server data arrives.

---

## 10. Migration path

### Phase 0 — Current state (today)
- Vercel serverless API with in-memory store
- JWT auth
- Flutter app calls `/api/*` over HTTP

### Phase 1 — Add Firebase (Week 1-2)
1. Create Firebase project (or use existing `sonic-cloud-app`)
2. Enable Email/Password, Anonymous, Google, Apple auth providers
3. Create Firestore database (Native mode, `nam5` multi-region)
4. Add `firebase_auth`, `cloud_firestore` to `pubspec.yaml`
5. Configure `firebase_options.dart` for web + mobile + desktop
6. Implement `FirebaseSyncService extends SyncService` (replaces `VercelSyncService`)
7. Update `main.dart` to instantiate `FirebaseSyncService` when signed in, `LocalSyncService` when not

### Phase 2 — Data migration (Week 2-3)
1. Keep `VercelSyncService` as a fallback during the transition
2. Add a one-time "migrate my data" button in Settings that:
   - Pulls all data from Vercel API
   - Writes it to Firestore
   - Marks migration complete in `users/{uid}.migrated = true`
3. After 30 days of no Vercel API traffic, archive the `api/` directory

### Phase 3 — Realtime (Week 3-4)
1. Replace `pullAll()` polling with `onSnapshot()` listeners
2. Implement `SyncEngine` that batches local writes and pushes them with debounce
3. Add the "Resume from {position}?" UI prompt on app open

### Phase 4 — OAuth + push (Week 4-5)
1. Add Google + Apple sign-in buttons to `SignInScreen`
2. Wire Firebase Cloud Messaging for "New device signed in" notifications
3. Add the device-revoke UI (already partially built in Settings)

### Phase 5 — Polish (Week 5-6)
1. Conflict resolution UI for the rare LWW collisions
2. Bandwidth optimization (only sync fields that changed using `SetOptions(merge: true)`)
3. Telemetry dashboard in Firebase console (read/write/delete counts per user)
4. Decommission the Vercel API backend (keep Vercel for hosting the web bundle only)

---

## 11. Milestones & timeline

| Milestone | Week | Deliverable | Success criteria |
|---|---|---|---|
| **M1: Firebase project live** | W1 | Firestore DB + Auth + security rules deployed | Anonymous sign-in works; can write/read a test doc |
| **M2: Flutter integration** | W2 | `FirebaseSyncService` replaces `VercelSyncService` in `main.dart` | User signs in on 2 devices → library + playlists visible on both within 5s |
| **M3: Realtime sync** | W3 | `onSnapshot()` listeners; "Resume from" prompt | Pause on device A → device B shows paused state in <1s |
| **M4: OAuth + push** | W4 | Google + Apple sign-in; FCM notifications | User signs in with Google on Android; gets push on iOS when new device signs in |
| **M5: Vercel API decommission** | W5-6 | `api/` archived; migration script complete | Zero traffic to Vercel API for 7 days; all data in Firestore |

---

## 12. Cost analysis

### 12.1 Firebase pricing (Blaze plan — pay-as-you-go)

| Resource | Free tier | After free tier |
|---|---|---|
| Firestore reads | 50K/day | $0.036 / 100K |
| Firestore writes | 20K/day | $0.108 / 100K |
| Firestore deletes | 20K/day | $0.012 / 100K |
| Firestore storage | 1 GB | $0.108 / GB/month |
| Cloud Storage | 5 GB | $0.026 / GB/month |
| Authentication | 50K/day (SMS verifications billed separately) | $0.01 / SMS (we don't use SMS) |
| Cloud Functions invocations | 2M/month | $0.40 / M |
| Cloud Messaging | Free | Free |

### 12.2 Estimated monthly cost per user

Assumptions: average user has 500 tracks, 20 playlists, opens app 30 times/month, 5-minute sessions, 3 devices.

| Operation | Reads | Writes |
|---|---|---|
| Initial sync on app open (full library + playlists) | 525 | 0 |
| Realtime listeners (5 listeners × 30 opens × 10 fires each) | 1,500 | 0 |
| Playback state reports (every 15s × 5 min × 30 sessions) | 0 | 600 |
| Favorites / ratings / playlist edits | 0 | 50 |
| Total per user per month | ~2,025 reads | ~650 writes |

**Cost per user per month**: ~$0.02 (well within free tier up to ~25,000 monthly active users).

### 12.3 Comparison to alternatives

| Option | 1K MAU | 10K MAU | 100K MAU |
|---|---|---|---|
| **Firebase (recommended)** | $0 (free tier) | $0-$20 | $200-$400 |
| Vercel + Vercel KV + Vercel Postgres | $0 (free tier) | $20-$60 | $200-$800 |
| Supabase | $0 (free tier) | $25 (Pro) | $250-$500 |
| Self-hosted (Docker + Postgres on Fly.io) | $5 (smallest VM) | $20-$50 | $200-$500 |

All three managed options are within 2× of each other at scale. Firebase wins on developer experience and feature set, not raw cost.

---

## 13. Open questions

These need a decision before M1:

1. **Audio file storage v2?** Should we eventually host audio bytes in Cloud Storage, or always rely on the user's cloud providers (Google Drive, WebDAV, etc.) for streaming? *Recommendation: stay with user cloud providers for v1; revisit if users request "backup my library" feature.*

2. **Cross-user sharing?** Should playlists be shareable via URL (read-only)? *Recommendation: v2 feature; not in scope for v1 sync.*

3. **Music catalog lookup?** Should we integrate with MusicBrainz / Discogs for metadata enrichment? *Recommendation: optional Cloud Function triggered on track write; out of scope for v1.*

4. **End-to-end encryption?** Some users will want E2EE for their listening history. *Recommendation: document as planned (already in FEATURES.md); implement as opt-in post-v1.*

5. **Multi-region?** Default to `nam5` (US multi-region) for now, or use `eur3` for EU users? *Recommendation: start with `nam5`; add region selection if EU adoption is significant.*

6. **Backups?** Firestore has point-in-time recovery (PITR) — should we enable it? *Recommendation: yes, for $0.20/GB/month it's worth it for accidental-deletion recovery.*

7. **Service-account key storage?** Cloud Functions need a service account to do admin operations (like batch device revoke). Store the key in Google Secret Manager, or use Workload Identity (no key file)? *Recommendation: Workload Identity — no key to leak.*

---

## 14. Next steps

After this plan is approved:

1. **M1 kickoff** — create the Firebase project, enable Auth + Firestore, write the security rules
2. **Pair on `FirebaseSyncService`** — implement the abstract `SyncService` against Firestore (estimate 2 days)
3. **Migration script** — one-time `migrateFromVercel()` method on `FirebaseSyncService` (estimate 1 day)
4. **Realtime listeners** — wire `onSnapshot()` into the existing `LibraryService` / `PlaylistService` / `SettingsService` (estimate 2 days)
5. **OAuth** — add Google + Apple sign-in buttons (estimate 1 day)
6. **Internal dogfood** — 1 week of internal use across 3 devices, fix sync bugs
7. **Public beta** — flag-gated rollout to 10% of users, monitor read/write costs
8. **General availability** — flip the flag, archive the Vercel API

**Total engineering estimate: 4-6 weeks for one engineer, or 2-3 weeks for two engineers pair-programming.**

---

## Appendix A — File impact summary

| File | Change | Phase |
|---|---|---|
| `pubspec.yaml` | Add `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_storage` | M1 |
| `lib/firebase_options.dart` (new) | Generated by `flutterfire configure` | M1 |
| `lib/services/firebase_sync_service.dart` (new) | Implements `SyncService` against Firestore | M2 |
| `lib/services/sync_engine.dart` (new) | Debounced write queue + `onSnapshot()` listener registration | M3 |
| `lib/services/api_client.dart` | Marked deprecated (kept for migration script) | M2, archived M5 |
| `lib/services/api_auth_service.dart` | Replaced by `FirebaseAuthService` | M2 |
| `lib/services/vercel_sync_service.dart` | Replaced by `FirebaseSyncService` | M2 |
| `lib/services/api_library_sync.dart` | Replaced by Firestore `library/{uid}_tracks` listeners | M3 |
| `lib/services/api_playlist_sync.dart` | Replaced by Firestore `playlists/{uid}_playlists` listeners | M3 |
| `lib/services/vercel_lyrics_provider.dart` | Replaced by Firestore `lyrics/{uid}_lyrics/{trackId}` reads | M2 |
| `lib/screens/auth/sign_in_screen.dart` | Add Google + Apple buttons; remove "Server URL" field | M4 |
| `lib/screens/settings_screen.dart` | Update device list to read from Firestore `devices/` | M2 |
| `lib/main.dart` | Swap `VercelSyncService` for `FirebaseSyncService` | M2 |
| `firestore.rules` (new) | Security rules from §8.1 | M1 |
| `firestore.indexes.json` (new) | Index declarations from §5.3 | M1 |
| `api/` directory | Kept through M4, archived in M5 | M5 |

## Appendix B — Glossary

- **LWW** — Last-Writer-Wins, the simplest conflict resolution strategy
- **PITR** — Point-In-Time Recovery, Firestore's backup feature
- **RLS** — Row-Level Security (Postgres / Supabase equivalent of Firestore security rules)
- **MAU** — Monthly Active Users
- **FCM** — Firebase Cloud Messaging (push notifications)
- **OAuth** — Open standard for delegated authorization (Google, Apple, GitHub sign-in)
- **E2EE** — End-to-End Encryption
- **Workload Identity** — GCP's recommended way for Cloud Functions to authenticate without storing keys
