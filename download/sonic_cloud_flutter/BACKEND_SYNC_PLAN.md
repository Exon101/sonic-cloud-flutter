# Sonic Cloud — Backend Sync Plan

> **Status:** Draft v2.0 (2026-07-07, revised) — for team review before implementation
> **Owner:** Backend working group
> **Goal:** Make Sonic Cloud sync a user's library, playlists, playback state, and settings across web, mobile (Android/iOS), and desktop (macOS/Windows/Linux) through a durable backend.
>
> **v2.0 revision (2026-07-07):** Pivoted from Firebase to a **100% free + open source** stack. Constraint: personal use, source code is public open source. See [§3 Architecture options](#3-architecture-options) for the rationale.

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
| **Sign-in once** | Email or anonymous on one device; sign in on another with the same account. |
| **Offline-friendly** | When I lose connection, local state still works; sync resumes on reconnect. |

### 1.2 Non-goals (this phase)

- **Audio byte streaming from our backend.** Audio files stay on the user's device or in their connected cloud providers (Google Drive, WebDAV, etc.). Our backend syncs *metadata* only.
- **Social features** (sharing, following, public profiles).
- **Music catalog / metadata lookup.**
- **End-to-end encryption** (documented as future option).

### 1.3 Constraints (v2.0)

- **No paid plans.** Personal use only — must fit within free tiers.
- **Open source friendly.** Anyone forking the repo can run their own backend in <10 minutes with free accounts only.
- **No vendor lock-in.** The data layer must be replaceable (SQLite-compatible schema so we can swap Turso → Cloudflare D1 → local SQLite → PocketBase without code changes).

---

## 2. Current state

| Layer | What exists | What's missing |
|---|---|---|
| **Client (Flutter)** | Full app on web + Android + iOS + macOS + Windows + Linux. Local SQLite (Drift) for library, SharedPreferences for settings, just_audio for playback, audio_service for OS media controls. `VercelSyncService` already implements the abstract `SyncService` contract. | Local writes don't auto-push to cloud; pull happens once on sign-in. No real-time updates when another device changes data. |
| **API (`api/`)** | 14 Node.js serverless functions on Vercel. JWT auth (HS256, self-contained). Endpoints: `/auth/signin`, `/auth/me`, `/library` CRUD, `/playlists` CRUD, `/lyrics` GET/PUT, `/sync/push`, `/sync/pull`, `/devices` list/revoke. | In-memory `Map` store — **data does not persist** across serverless invocations. No real-time push (no WebSocket / SSE). |
| **Hosting** | Vercel (dev/small-scale) + Firebase Hosting (production primary, optional). | No backing data store configured. |
| **Auth** | JWT issued by `/auth/signin` (email or anonymous). Token carries `{userId, deviceId}`. | No password, no OAuth, no email verification. |
| **Tests** | 39 backend tests (13 unit + 26 e2e) + Flutter widget/unit tests. | No integration tests against a real database. |

**The single biggest gap:** the backend has no durable storage. Fixing this is the primary deliverable of this plan.

---

## 3. Architecture options

We evaluated five options under the v2.0 constraints (free + open source friendly + no vendor lock-in).

### Option A — Turso (libSQL/SQLite) + existing Vercel API  ⭐ RECOMMENDED

```
Flutter app ──HTTPS──> Vercel Functions (existing 14 endpoints)
                              │
                              └──HTTP──> Turso (libSQL/SQLite, edge-replicated)
```

**Pros:**
- **Reuses everything we built.** The Vercel API, JWT auth, all 14 endpoints — all stay. Only `api/_lib/store.js` (the in-memory Map) is swapped for Turso SQL queries.
- **Free tier is extremely generous:** 500 databases, 9GB total storage, 1 billion row reads/month, 25 million row writes/month. Far more than any personal use case needs.
- **SQLite-compatible.** Schema can run on Turso, Cloudflare D1, or local SQLite without changes. Zero vendor lock-in.
- **Edge-replicated.** Turso replicas live close to users worldwide — low-latency reads from anywhere.
- **Open source (MIT).** libSQL is the open source fork of SQLite that Turso maintains.
- **Anyone forking the project** creates a free Turso account, copies their DB URL + token into Vercel env vars, done.

**Cons:**
- No native realtime (no Firestore-style `onSnapshot()`). We use polling — client polls `/api/sync/pull?since=<timestamp>` every 30s. Fine for personal use.
- No managed OAuth (we'd build Google/Apple OAuth ourselves — but those APIs are free).

### Option B — PocketBase (self-hosted, single binary)

```
Flutter app ──HTTP/SSE──> PocketBase (single Go binary)
                              │
                              └──SQLite file on disk
```

**Pros:**
- **Single binary**, includes API + auth + realtime (SSE) + file storage + admin UI. One process to manage.
- **100% free, open source (MIT).** Self-host on any free VPS (Oracle Cloud Always Free, Fly.io free tier, etc.).
- **Realtime built in** via Server-Sent Events.
- **Has a Flutter SDK** (`pocketbase_schemas` + `http`).
- **SQLite under the hood** — same data portability as Turso.

**Cons:**
- **Requires self-hosting.** Need a VPS (even free) and basic ops knowledge.
- **Replaces the entire Vercel API.** Would delete the 14 serverless functions we built and rewrite against PocketBase's collections API.
- **Less suitable for Vercel hosting** — PocketBase is a long-running process, not serverless. The Flutter web bundle would still deploy to Vercel, but the API would live on a separate VPS.

### Option C — Supabase (managed, free tier)

```
Flutter app ──Supabase SDK──> Postgres (SQL + RLS)
                              └> Realtime (Postgres replication)
                              └> Auth (GoTrue)
                              └> Storage (S3-compatible)
```

**Pros:** Open source, Postgres, realtime, auth, storage all in one. Managed free tier.

**Cons:** Free tier limits (500MB DB, 50K MAU, 1GB storage, paused after 1 week inactivity) could be hit. More setup than Turso. Replaces the Vercel API.

### Option D — Firebase Spark (free tier)

**Pros:** Generous free quotas (50K reads/day, 20K writes/day, 1GB storage). Realtime listeners built in.

**Cons:** Cloud Functions require Blaze (paid) plan — we'd lose server-side validation and batch operations. Vendor lock-in — anyone forking needs their own Firebase project. **Ruled out under v2.0 constraints.**

### Option E — Self-hosted Postgres on a free VPS

**Pros:** Truly free, no quotas, full control.

**Cons:** Significant ops burden (backups, security patches, uptime). Overkill for personal use. **Ruled out — too much overhead.**

### Recommendation: **Option A (Turso + existing Vercel API)**

Why:
- **Lowest effort** — single swap point (`store.js`), keep everything else
- **Reuses 100% of existing code** — API endpoints, JWT auth, Flutter client, tests
- **Free forever** for any conceivable personal use
- **Open source** — anyone forking can run their own Turso + Vercel in minutes
- **SQLite-compatible** — if Turso ever disappears, swap to Cloudflare D1 / local SQLite / PocketBase without schema changes

PocketBase (Option B) is a strong runner-up — best for someone who wants to fully self-host and ditch Vercel. Documented as an alternative in Appendix C.

---

## 4. Recommended stack

| Concern | Choice | Why |
|---|---|---|
| **Database** | Turso (libSQL/SQLite) | Free, open source, edge-replicated, SQLite-compatible (portable) |
| **API runtime** | Vercel Serverless Functions (existing) | Already built, already deployed, no migration needed |
| **Auth** | JWT (existing HS256) + future OAuth (Google/Apple, free APIs) | Already works; OAuth add-on is a few hours of work |
| **Realtime** | Polling every 30s via `/api/sync/pull?since=<timestamp>` | Simple, no extra infra, fine for personal use |
| **Hosting** | Vercel (dev + small-scale + the API) | Unchanged from current setup |
| **Client SDK** | Existing `ApiClient` (Flutter `http` package) | Already built |
| **Local DB** | Drift (SQLite) — keep as-is | Acts as the offline cache; sync engine reads/writes through it |
| **File storage** | (v2) Cloudinary free tier or Cloudflare R2 free tier | For user-uploaded cover art, if needed |

---

## 5. Data model

Turso is SQLite — standard relational schema. We use 6 tables, all scoped by `userId` (foreign key). Schema is intentionally portable to Postgres / Cloudflare D1 / PocketBase.

### 5.1 Schema (SQL)

```sql
-- Users (auth profile + settings)
CREATE TABLE users (
  id           TEXT PRIMARY KEY,           -- 'usr_<24hex>'
  email        TEXT UNIQUE,                -- NULL for anonymous
  is_anonymous INTEGER NOT NULL DEFAULT 0, -- 0 or 1
  display_name TEXT,
  avatar_url   TEXT,
  tier         TEXT DEFAULT 'guest',       -- 'guest' | 'premium'
  settings     TEXT,                       -- JSON blob
  created_at   INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL
);

-- Library tracks (metadata only — audio bytes stay client-side)
CREATE TABLE tracks (
  id            TEXT NOT NULL,
  user_id       TEXT NOT NULL,
  title         TEXT NOT NULL,
  artist        TEXT NOT NULL,
  album         TEXT,
  album_artist  TEXT,
  genre         TEXT,
  composer      TEXT,
  year          INTEGER,
  duration_sec  REAL NOT NULL,             -- seconds (float)
  format        TEXT,                      -- 'mp3' | 'flac' | ...
  file_size     INTEGER,
  file_system_path TEXT,
  cloud_provider TEXT,                     -- 'googleDrive' | 'webdav' | ...
  source_id     TEXT,                      -- provider-specific file ID
  rating        INTEGER DEFAULT 0,         -- 0..5
  play_count    INTEGER DEFAULT 0,
  last_played_at INTEGER,
  date_added    INTEGER,
  is_favorite   INTEGER DEFAULT 0,         -- 0 or 1
  is_cloud_only INTEGER DEFAULT 0,
  updated_at    INTEGER NOT NULL,
  updated_by_device TEXT,
  PRIMARY KEY (user_id, id)
);

-- Playlists (manual / smart / auto)
CREATE TABLE playlists (
  id           TEXT NOT NULL,
  user_id      TEXT NOT NULL,
  name         TEXT NOT NULL,
  kind         TEXT NOT NULL,              -- 'manual' | 'smart' | 'auto'
  track_ids    TEXT NOT NULL,              -- JSON array of track IDs
  rules        TEXT,                       -- JSON for smart playlists
  auto_kind    TEXT,                       -- for auto: 'favorites' | 'mostPlayed' | ...
  description  TEXT,
  art_url      TEXT,
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL,
  updated_by_device TEXT,
  PRIMARY KEY (user_id, id)
);

-- Lyrics (keyed by trackId for O(1) fetch)
CREATE TABLE lyrics (
  user_id      TEXT NOT NULL,
  track_id     TEXT NOT NULL,
  raw          TEXT NOT NULL,              -- LRC text
  provider     TEXT DEFAULT 'user',
  is_synced    INTEGER DEFAULT 0,
  updated_at   INTEGER NOT NULL,
  PRIMARY KEY (user_id, track_id)
);

-- Devices (sessions, last-seen, push tokens)
CREATE TABLE devices (
  id           TEXT NOT NULL,              -- 'dev_<base36>'
  user_id      TEXT NOT NULL,
  name         TEXT,
  platform     TEXT,                       -- 'web' | 'android' | 'ios' | ...
  app_version  TEXT,
  push_token   TEXT,                       -- FCM token (optional)
  is_revoked   INTEGER DEFAULT 0,
  created_at   INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, id)
);

-- Sync state (one row per user — the source of truth for "what's playing now")
CREATE TABLE sync_state (
  user_id            TEXT PRIMARY KEY,
  queue              TEXT,                 -- JSON array of track IDs
  current_index      INTEGER DEFAULT 0,
  shuffle_enabled    INTEGER DEFAULT 0,
  repeat_mode        TEXT DEFAULT 'off',   -- 'off' | 'all' | 'one'
  speed              REAL DEFAULT 1.0,
  position_sec       REAL DEFAULT 0.0,
  position_updated_at INTEGER,
  playing            INTEGER DEFAULT 0,
  updated_at         INTEGER NOT NULL,
  updated_by_device  TEXT
);

-- Indexes for common queries
CREATE INDEX idx_tracks_user_artist ON tracks(user_id, artist, title);
CREATE INDEX idx_tracks_user_last_played ON tracks(user_id, last_played_at DESC);
CREATE INDEX idx_tracks_user_play_count ON tracks(user_id, play_count DESC);
CREATE INDEX idx_tracks_user_favorite ON tracks(user_id, is_favorite) WHERE is_favorite = 1;
CREATE INDEX idx_playlists_user_updated ON playlists(user_id, updated_at DESC);
CREATE INDEX idx_devices_user_active ON devices(user_id, is_revoked, last_seen_at DESC);
```

### 5.2 Why this layout?

- **Composite primary keys `(user_id, id)`** — natural partitioning, fast lookups by user.
- **`track_ids` as JSON array** in playlists — SQLite doesn't have a native array type, and we never query "which playlists contain track X" often enough to justify a join table. If we need that later, add a `playlist_tracks` join table.
- **`settings` as JSON blob** in users — settings are read as a whole, never queried by field.
- **`sync_state` as a single row per user** — there's only one "now playing" per user.

### 5.3 Portability

This schema runs unchanged on:
- **Turso** (libSQL) — our primary
- **Cloudflare D1** (SQLite at the edge)
- **Local SQLite** (Drift, on-device)
- **PocketBase** (SQLite with auto-generated API)
- **Postgres** (with minor type tweaks: `INTEGER` → `BIGINT`, `TEXT` JSON → `JSONB`)

---

## 6. Sync protocol

### 6.1 Conflict resolution strategy

| Field type | Strategy | SQL implementation |
|---|---|---|
| **Scalars** (title, artist, rating, etc.) | Last-writer-wins (LWW) using `updated_at` | `INSERT ... ON CONFLICT DO UPDATE SET ... WHERE excluded.updated_at > tracks.updated_at` |
| **Counter-like** (play_count) | **Increment, don't overwrite** | `UPDATE tracks SET play_count = play_count + 1` |
| **Set-like** (playlist.track_ids, favorites) | **Merge** — read-modify-write inside a transaction | `BEGIN; SELECT track_ids; <merge>; UPDATE; COMMIT;` |
| **Timestamps** (last_played_at) | LWW | Same as scalars |
| **Settings** (the whole JSON blob) | LWW | Same as scalars |
| **Queue + position** (`sync_state`) | LWW but with smart fallback | See §6.3 |

### 6.2 Write paths

Three write paths, each with different latency guarantees:

1. **Optimistic local write** (immediate) — the Flutter app writes to local Drift + updates the UI instantly. The user sees no latency.
2. **Background push** (~200ms) — a `SyncEngine` debounce-queues the write to the Vercel API → Turso. If offline, the write sits in the local queue and flushes on reconnect.
3. **Polling broadcast** (~30s) — other devices poll `/api/sync/pull?since=<last>` and pick up the change.

### 6.3 "Now Playing" continuity

When device A pauses at position 73.4s, it writes `sync_state { position_sec: 73.4, position_updated_at: <now>, playing: 0 }`. Device B opens the app:

1. Reads `sync_state` → sees position 73.4s at timestamp T.
2. If `playing = 1` on the server, device B extrapolates: `current_position = 73.4 + (now - T)`.
3. If `playing = 0`, device B uses 73.4s as the resume position.
4. Device B shows a "Resume from 1:13?" prompt (or auto-resumes, configurable in settings).

### 6.4 Throttling

- **Position reports**: throttled to once every 5 seconds (device-local), once every 15 seconds (to server).
- **Play count**: incremented locally, pushed once per session per track.
- **Settings changes**: pushed immediately (low volume).
- **Playlist edits**: pushed immediately (user expects instant feedback).

### 6.5 Polling design

```typescript
// Flutter client (pseudo-code)
class SyncEngine {
  Timer? _pollTimer;
  int? _lastSyncAt;

  void start() {
    _pollTimer = Timer.periodic(Duration(seconds: 30), (_) => _pull());
  }

  Future<void> _pull() async {
    final res = await api.get('/sync/pull', query: {'since': _lastSyncAt?.toString()});
    if (res['unchanged'] == true) return;  // 304-style short-circuit
    // Apply res['sync'] to local Drift + update UI
    _lastSyncAt = res['serverTime'];
  }
}
```

The `/sync/pull?since=<ms>` endpoint returns `{unchanged: true}` if nothing has changed since the timestamp — so 95% of polls are cheap (single SQL query, no row data transmitted).

### 6.6 Future: upgrade to SSE/WebSocket

If polling proves insufficient (multiple users, high churn), upgrade path:
- Add `/api/sync/stream` SSE endpoint that holds the connection open and pushes changes
- Or add a WebSocket at `/api/ws` using Vercel's Edge Runtime
- Client changes from `Timer.periodic` to `StreamSubscription` — minimal code change

This is a v1.1+ enhancement. For personal use, polling is fine.

---

## 7. Auth

### 7.1 Sign-in methods (priority order)

| Method | When | Notes |
|---|---|---|
| **Anonymous** | Default on first launch | One-tap; upgrades to email/OAuth later without losing data |
| **Email + password** | User chooses to sign in | Hashed with PBKDF2 (Node `crypto.scrypt`) before storage in Turso |
| **Google OAuth** | One-tap on Android/Chrome | Free Google OAuth API; ~2 hours to wire |
| **Apple OAuth** | Required for App Store apps that offer other OAuth | Free; requires Apple Developer account ($99/yr — out of scope for free-only) |
| **GitHub OAuth** | Nice-to-have for developer audience | Free; ~1 hour to wire |

### 7.2 Token refresh

Our JWT tokens are self-contained (carry `userId` + `deviceId`) and expire after 30 days. The Flutter client refreshes the token on app foreground if it's within 7 days of expiry.

### 7.3 Anonymous → identified upgrade

When an anonymous user signs in with email/Google:
1. Server creates a new user record with the email
2. Server copies all data from the anonymous user to the new user (single SQL transaction)
3. Server issues a new JWT with the new `userId`
4. Client discards the anonymous token

No Firebase-style `linkWithCredential()` magic — just a SQL copy.

### 7.4 Device management

- On sign-in, the client registers a `devices/{deviceId}` row with platform, app version, and optional FCM push token.
- Heartbeat updates `last_seen_at` every 5 minutes while the app is open.
- "Revoke" sets `is_revoked = 1` — subsequent requests with that device's JWT return 401.
- "Sign out everywhere" → `UPDATE devices SET is_revoked = 1 WHERE user_id = ?`.

---

## 8. Security

### 8.1 Database access

- **Turso connection** is server-side only (in Vercel Functions). The DB URL + auth token live in Vercel env vars — never exposed to the client.
- **Client → API** uses JWT Bearer tokens (already implemented).
- **API → Turso** uses Turso's HTTP API with the libSQL client (`@libsql/client` npm package).

### 8.2 Row-level isolation

Every SQL query is scoped by `user_id` extracted from the JWT. No user can ever read another user's data — the `WHERE user_id = ?` clause is enforced in the data access layer, not in security rules.

```typescript
// api/_lib/db.js
async function getTracks(userId) {
  return db.execute('SELECT * FROM tracks WHERE user_id = ?', [userId]);
}
```

### 8.3 Input validation

- **Server-side**: every API handler validates input with a small whitelist (already implemented in the current `/api/library` POST handler).
- **SQL parameterization**: all queries use `?` placeholders — no string concatenation. SQL injection is impossible.
- **Rate limiting**: Vercel's platform-level rate limits apply. For tighter limits, add a simple in-memory counter per IP (fine for personal use).

### 8.4 Encryption

- **At rest**: Turso encrypts database files at rest (AES-256).
- **In transit**: all connections use TLS 1.2+ (HTTPS to Vercel, HTTPS to Turso).
- **JWT secret**: stored in Vercel env var `SONIC_JWT_SECRET`. Rotate by updating the env var.

### 8.5 Backups

- **Turso free tier** includes daily snapshots, retained 7 days.
- For extra safety, schedule a weekly `turso db dump` to a GitHub release artifact via GitHub Actions.

---

## 9. Real-time sync architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  Device A   │         │ Vercel API   │         │  Device B   │
│ (phone)     │         │  + Turso DB  │         │ (laptop)    │
│             │         │              │         │             │
│  User taps  │         │              │         │             │
│  "favorite" │         │              │         │             │
│      │      │         │              │         │             │
│      ▼      │         │              │         │             │
│  POST       │ ────►   │ UPDATE       │         │             │
│  /library/  │         │ tracks SET   │         │             │
│  {id}       │         │ is_favorite=1│         │             │
│             │         │ WHERE id=?   │         │             │
│             │         │      │       │         │             │
│             │         │      │ 30s   │         │             │
│             │         │      │ poll  │         │             │
│             │         │      ▼       │         │             │
│             │         │              │ ◄────   │ GET         │
│             │         │              │         │ /sync/pull  │
│             │         │              │         │ ?since=...  │
│             │         │              │ ────►   │ Returns     │
│             │         │              │         │ updated     │
│             │         │              │         │ state, UI   │
│             │         │              │         │ updates     │
└─────────────┘         └──────────────┘         └─────────────┘
```

### 9.1 Polling granularity

| Endpoint | Poll interval | What it updates |
|---|---|---|
| `/sync/pull?since=<ms>` | 30s | Everything in sync_state (queue, position, playing) |
| `/library?since=<ms>` | 60s | Library track changes (favorites, ratings, play_count) |
| `/playlists?since=<ms>` | 60s | Playlist changes |

Total: ~3 polls per minute, ~180 per hour. Each poll is a single SQL query returning ~0 rows when nothing changed. Turso free tier handles this trivially (1B reads/month).

### 9.2 Offline behavior

- Flutter app writes to local Drift (SQLite) immediately — UI updates instantly.
- A `SyncQueue` persists pending writes to a local `pending_writes` table in Drift.
- On reconnect, the queue flushes to the API in order.
- Polling pauses while offline; resumes on reconnect with a full `/sync/pull` (no `since` param).

---

## 10. Migration path

### Phase 0 — Current state (today)
- Vercel serverless API with in-memory store
- JWT auth
- Flutter app calls `/api/*` over HTTP

### Phase 1 — Add Turso (Week 1)
1. Create free Turso account at https://turso.tech
2. `turso db create sonic-cloud`
3. `turso db tokens create sonic-cloud` → get auth token
4. Run schema migration (the SQL from §5.1) via `turso db shell`
5. Add `TURSO_DB_URL` + `TURSO_AUTH_TOKEN` to Vercel env vars
6. Replace `api/_lib/store.js` with `api/_lib/db.js` (Turso client)
7. Update all 11 handlers to use SQL queries instead of `store.getTrack()` etc.
8. All 39 existing tests still pass (rewrite `test_api_helpers.js` to test against a local libSQL instance)

### Phase 2 — Real-time polling (Week 2)
1. Add `SyncEngine` to Flutter app — registers a `Timer.periodic` for polling
2. Add `since=<ms>` short-circuit to `/sync/pull` (returns `{unchanged: true}` if nothing changed)
3. Add `pending_writes` table to local Drift DB for offline queue
4. Wire `SyncEngine` into `main.dart` — starts on app open, stops on app close

### Phase 3 — Email + Google OAuth (Week 3)
1. Add `password_hash` column to `users` table
2. Update `/auth/signin` to accept email + password (hash with `crypto.scrypt` before storage)
3. Add `/auth/signup` endpoint
4. Add Google OAuth button to `SignInScreen` (uses `google_sign_in` Flutter package — free)
5. Verify OAuth token server-side, issue our JWT

### Phase 4 — Polish (Week 4)
1. "Resume from {position}?" UI prompt on app open
2. Conflict resolution UI for rare LWW collisions
3. Telemetry: log API response times to Vercel Analytics (free)
4. Documentation: update `DEPLOYMENT.md` with Turso setup steps
5. Forking guide: "How to run your own Sonic Cloud backend in 10 minutes"

### Phase 5 — Future enhancements (out of scope for v1)
1. WebSocket / SSE for true realtime (replaces polling)
2. Push notifications via Firebase Cloud Messaging (free, optional)
3. Audio file hosting via Cloudinary free tier or Cloudflare R2
4. End-to-end encryption for sensitive fields

---

## 11. Milestones & timeline

| Milestone | Week | Deliverable | Success criteria |
|---|---|---|---|
| **M1: Turso integration** | W1 | DB provisioned, `store.js` replaced with `db.js`, all endpoints work against Turso | Sign in on 2 devices → both can write/read library tracks that persist across cold starts |
| **M2: Realtime polling** | W2 | `SyncEngine` in Flutter, `since=` short-circuit, offline queue | Pause on device A → device B sees paused state within 30s |
| **M3: Email + Google OAuth** | W3 | Email/password signup, Google sign-in button | User signs in with Google on Android, signs in on web with same account, sees same library |
| **M4: Polish + docs** | W4 | Resume prompt, conflict UI, forking guide | A new user can fork the repo, create free Turso + Vercel accounts, and have a working backend in <10 minutes |

---

## 12. Cost analysis

### 12.1 Turso free tier

| Resource | Free tier limit | Our expected usage (personal) |
|---|---|---|
| Databases | 500 | 1 |
| Total storage | 9 GB | <100 MB (metadata only) |
| Row reads | 1,000,000,000 / month | ~500,000 (3 polls/min × 30 days) |
| Row writes | 25,000,000 / month | ~50,000 (active listening) |
| Locations | 3 | 1 (closest to user) |

**Cost: $0/month** — we'd use <0.1% of the free tier.

### 12.2 Vercel free tier (Hobby plan)

| Resource | Free tier limit | Our expected usage |
|---|---|---|
| Bandwidth | 100 GB / month | <1 GB |
| Serverless function executions | 100,000 / month | ~500,000 (3 polls/min × 30 days) ⚠️ could hit |
| Build execution | 6,000 minutes / month | ~60 (1 build per push) |
| concurrent builds | 1 | 1 |

**⚠️ Note:** Vercel Hobby's 100K function executions/month could be hit by 30-second polling (3 polls/min = 130K/month). Mitigations:
- Increase poll interval to 60s (cuts to 65K/month — within limit)
- Or upgrade to Vercel Pro ($20/month) — only if personal use grows
- Or self-host the API on a free VPS (Fly.io free tier) — unlimited executions

For pure personal use with 1-3 devices, 60-second polling is fine.

### 12.3 Total cost

**$0/month** for personal use, fitting comfortably within Turso + Vercel free tiers.

If usage grows beyond personal (open source project gets popular):
- Turso: stays free up to ~25K MAU
- Vercel: upgrade to Pro at $20/month, or self-host API on Fly.io free tier
- Worst case: $20/month for thousands of users

---

## 13. Open questions

1. **Poll interval?** 30s (better UX, more API calls) or 60s (within Vercel free tier)? *Recommendation: 30s for personal use, configurable in settings, default 60s.*

2. **OAuth providers?** Google is free and covers most users. Apple requires $99/yr developer account — skip for now. GitHub is free and nice for developer audience. *Recommendation: Google + GitHub for v1.*

3. **Audio file storage v2?** Should we eventually host audio bytes? Cloudinary free tier (25 GB) or Cloudflare R2 free tier (10 GB) could work. *Recommendation: out of scope for v1; revisit if users request "backup my library" feature.*

4. **End-to-end encryption?** Some users will want E2EE for listening history. *Recommendation: document as planned; implement as opt-in post-v1.*

5. **Multi-region Turso?** Free tier includes 3 locations. Place primary close to user; replicas for read latency. *Recommendation: 1 primary for v1, add replicas if latency matters.*

6. **Backups?** Turso has daily snapshots (7-day retention). For extra safety, weekly `turso db dump` to a GitHub release. *Recommendation: yes, automate via GitHub Actions.*

7. **Self-hosting guide?** Should we provide a Docker Compose setup so users can run the entire stack (Flutter web + API + Turso) on their own server? *Recommendation: yes — `docker-compose.yml` with Turso replaced by local SQLite.*

---

## 14. Next steps

After this plan is approved:

1. **M1 kickoff** — create Turso account + database, run schema migration
2. **Implement `api/_lib/db.js`** — Turso client wrapper with the same method signatures as the current `Store` class (estimate 4 hours)
3. **Update all 11 handlers** — swap `store.getTrack()` calls for `db.getTrack()` SQL queries (estimate 4 hours)
4. **Update tests** — `test_api_helpers.js` and `test_api_e2e.js` against a local libSQL instance (estimate 2 hours)
5. **Deploy + verify** — push to main, Vercel auto-deploys, verify data persists across cold starts (estimate 1 hour)
6. **M2: SyncEngine** — Flutter-side polling + offline queue (estimate 1 day)
7. **M3: OAuth** — Google + email/password (estimate 1 day)
8. **M4: Polish + docs** (estimate 1 day)

**Total engineering estimate: 2 weeks** for one engineer (vs 4-6 weeks for the Firebase plan in v1.0).

---

## Appendix A — File impact summary

| File | Change | Phase |
|---|---|---|
| `api/_lib/db.js` (new) | Turso client wrapper; replaces `store.js` | M1 |
| `api/_lib/store.js` | Deleted (or kept as in-memory fallback for tests) | M1 |
| `api/_lib/schema.sql` (new) | The SQL schema from §5.1 | M1 |
| `api/_lib/http.js` | No changes (JWT auth stays the same) | — |
| `api/auth/signin.js` | Add email+password path (currently email-only) | M3 |
| `api/auth/signup.js` (new) | Email/password signup endpoint | M3 |
| `api/auth/oauth.js` (new) | Google OAuth callback handler | M3 |
| All 11 handlers | Replace `store.X()` calls with `db.X()` SQL queries | M1 |
| `lib/services/sync_engine.dart` (new) | Debounced write queue + polling timer + offline queue | M2 |
| `lib/services/api_client.dart` | Add `since=` query param support | M2 |
| `lib/services/api_auth_service.dart` | Add OAuth flow methods | M3 |
| `lib/screens/auth/sign_in_screen.dart` | Add Google + email/password buttons | M3 |
| `lib/db/app_database.dart` | Add `pending_writes` table for offline queue | M2 |
| `lib/main.dart` | Wire `SyncEngine` into the service graph | M2 |
| `vercel.json` | Add `TURSO_DB_URL` + `TURSO_AUTH_TOKEN` env var comments | M1 |
| `.env.example` | Add Turso env vars | M1 |
| `DEPLOYMENT.md` | Add Turso setup section | M4 |
| `FORKING.md` (new) | "Run your own Sonic Cloud backend in 10 minutes" | M4 |

## Appendix B — Glossary

- **LWW** — Last-Writer-Wins, the simplest conflict resolution strategy
- **libSQL** — Open source fork of SQLite maintained by Turso (MIT licensed)
- **Turso** — Managed libSQL service with edge replication, generous free tier
- **SSE** — Server-Sent Events, a one-way realtime push protocol (alternative to polling)
- **MAU** — Monthly Active Users
- **FCM** — Firebase Cloud Messaging (push notifications, free)
- **Drift** — Flutter's reactive SQLite wrapper, used as the local on-device DB

## Appendix C — Alternative: PocketBase (self-hosted)

If you prefer to fully self-host (no Vercel, no Turso — everything on one free VPS):

**Stack:** PocketBase (single Go binary) on Oracle Cloud Always Free or Fly.io free tier.

**Pros vs Turso:**
- Single binary, includes API + auth + realtime (SSE) + file storage + admin UI
- True realtime via SSE (no polling needed)
- 100% self-hosted, no external dependencies

**Cons vs Turso:**
- Requires a VPS (even free) and basic ops knowledge
- Replaces the entire Vercel API (would delete the 14 serverless functions we built)
- Less suitable for Vercel hosting — PocketBase is a long-running process

**Migration path:** If we ever want to switch from Turso → PocketBase, the SQLite schema in §5.1 ports directly. The API handlers would need to be rewritten against PocketBase's collections API, but the data layer stays the same.

**Recommendation:** Stick with Turso for v1 (reuses existing work). Document PocketBase as the self-hosting alternative in `FORKING.md` for users who want full autonomy.
