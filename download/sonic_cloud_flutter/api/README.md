# Sonic Cloud API — Vercel Serverless Functions

This directory contains the backend API for Sonic Cloud, deployed as Vercel
Serverless Functions. Each `.js` file (or `index.js` inside a folder) is
automatically exposed at the matching URL path.

## Endpoints

| Method | Path                     | Auth | Description |
|--------|--------------------------|------|-------------|
| GET    | `/api/status`            | No   | Health check, version, list of endpoints |
| POST   | `/api/auth/signin`       | No   | Sign in by email (idempotent) or anonymously. Returns `token` + `userId` |
| GET    | `/api/auth/me`           | Yes  | Return the current user + session info |
| GET    | `/api/library`           | Yes  | List tracks (supports `?limit=`, `?cursor=`) |
| POST   | `/api/library`           | Yes  | Upsert a track into the cloud library |
| GET    | `/api/library/:id`       | Yes  | Fetch one track |
| PUT    | `/api/library/:id`       | Yes  | Replace one track |
| DELETE | `/api/library/:id`       | Yes  | Remove a track from the cloud library |
| GET    | `/api/playlists`         | Yes  | List playlists |
| POST   | `/api/playlists`         | Yes  | Create a playlist (manual / smart / auto) |
| GET    | `/api/playlists/:id`     | Yes  | Fetch one playlist |
| PUT    | `/api/playlists/:id`     | Yes  | Full replace |
| PATCH  | `/api/playlists/:id`     | Yes  | Partial patch (e.g. `addTrackIds`, `removeTrackIds`) |
| DELETE | `/api/playlists/:id`     | Yes  | Delete |
| GET    | `/api/lyrics?trackId=`   | Yes  | Fetch parsed lyrics (synced + LRC metadata) |
| PUT    | `/api/lyrics?trackId=`   | Yes  | Store lyrics (`{ raw, provider? }`) |
| POST   | `/api/sync/push`         | Yes  | Merge `queue / favorites / ratings / positions / settings` |
| GET    | `/api/sync/pull?since=`  | Yes  | Fetch full sync state, or `{unchanged:true}` if `since=` is newer |
| GET    | `/api/devices`           | Yes  | List active sessions for the current user |
| DELETE | `/api/devices?prefix=`   | Yes  | Revoke a session by token prefix |

## Authentication

All "Yes" endpoints require an `Authorization: Bearer <token>` header. Tokens
are returned by `POST /api/auth/signin` and never expire in the dev store.

```bash
# Anonymous sign-in
curl -X POST https://sonic-cloud-kappa.vercel.app/api/auth/signin \
  -H 'Content-Type: application/json' \
  -d '{"anonymous": true, "deviceId": "macbook-pro-2026"}'

# → { "ok": true, "token": "a1b2…", "userId": "usr_…", "createdAt": 1783415109000 }
```

```bash
# Authenticated request
curl https://sonic-cloud-kappa.vercel.app/api/library \
  -H "Authorization: Bearer a1b2…"
```

## Wire formats

### Track (cloud library)

```json
{
  "id": "tr_abc",
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
  "source": "local",
  "cloudProvider": null,
  "rating": 5,
  "lastPlayedAt": 1783415109000,
  "playCount": 12,
  "updatedAt": 1783415109000
}
```

### Playlist

```json
{
  "id": "pl_xyz",
  "name": "Late Night Drive",
  "kind": "manual",
  "trackIds": ["tr_abc", "tr_def"],
  "createdAt": 1783415109000,
  "updatedAt": 1783415109000
}
```

For `kind: "smart"`:

```json
{
  "id": "pl_smart1",
  "name": "Recent Electronica",
  "kind": "smart",
  "rules": [
    { "field": "genre", "op": "equals", "value": "Electronica" },
    { "field": "lastPlayedAt", "op": "greaterThan", "value": 1783000000000 }
  ],
  "trackIds": []
}
```

For `kind: "auto"`:

```json
{
  "id": "pl_favs",
  "name": "Favorites",
  "kind": "auto",
  "autoKind": "favorites",
  "trackIds": []
}
```

### Lyrics

Stored as raw LRC text, returned parsed:

```json
{
  "trackId": "tr_abc",
  "raw": "[ti:Midnight City]\n[ar:M83]\n[00:12.34] Waiting in the car…",
  "provider": "user",
  "synced": true,
  "lines": [
    { "time": 12.34, "text": "Waiting in the car…" }
  ],
  "metadata": { "ti": "Midnight City", "ar": "M83" }
}
```

### Sync state

```json
{
  "queue": ["tr_abc", "tr_def"],
  "favorites": ["tr_abc"],
  "ratings": { "tr_abc": 5 },
  "positions": { "tr_abc": 73.4 },
  "settings": { "themeMode": "dark", "crossfadeMs": 4000 },
  "updatedAt": 1783415109000
}
```

## Local development

```bash
npm install -g vercel
vercel        # first-time link to your Vercel project
vercel dev    # serves both the Flutter web bundle and /api/* at http://localhost:3000
```

## Production storage ⚠️

`api/_lib/store.js` uses an **in-memory `Map`** so the API works out of the
box with zero infrastructure. In production, each serverless function
invocation may run on a different instance, so writes will not reliably
persist.

To make the API durable, swap the `Store` class in `api/_lib/store.js` for
one backed by:

- **Vercel KV** (Redis-compatible, free tier): https://vercel.com/docs/storage/vercel-kv
- **Vercel Postgres**: https://vercel.com/docs/storage/vercel-postgres
- **Upstash Redis**: https://upstash.com
- **Supabase**: https://supabase.com

The public surface (`get/set/delete/list` per resource) is intentionally
small so a real backend can be dropped in without touching the route
handlers. A reference Vercel KV implementation is left as a TODO in
`store.js`.

## CORS

All responses include `Access-Control-Allow-Origin: *` and the standard
preflight headers, so the Flutter web build can call the API directly from
any origin. For production, consider tightening this to your deployed
Vercel URL.

## Rate limiting

Not implemented in the in-memory store. Vercel's platform-level rate
limits apply; for tighter limits use Vercel's Edge Middleware or a
Redis-backed token bucket.
