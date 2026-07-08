# Sonic Cloud — Future Development Reference

> **Status:** Living document — ideas borrowed from other open-source music apps
> **Last updated:** 2026-07-08
> **Purpose:** Catalog features worth considering for Sonic Cloud v2+, with implementation notes from apps we've analyzed.

---

## Source: Monochrome (monochrome-music/monochrome)

**Analyzed:** 2026-07-08 · **Version:** 2.5.1 · **License:** Apache-2.0
**What it is:** Open-source TIDAL web UI (streams from TIDAL's catalog, not personal files)
**Stack:** Vanilla TypeScript + Vite + Cloudflare Pages Functions + PocketBase + Better-Auth + Capacitor

### Borrowable features (priority order)

#### 1. Listening Parties (real-time synced playback) ⭐ high priority

**What Monochrome does:**
- `js/listening-party.js` + `js/party-socket.js` use the `party-socket` library (PartyKit-style WebSocket rooms)
- Host controls playback; guests' players follow in real-time
- A modal UI lets you create/join a party with a shareable link
- Party state (current track, position, queue) syncs via WebSocket

**How to adapt for Sonic Cloud:**
- We already have `sync_state/{userId}` in Turso — extend it to `sync_state/{partyId}` for group sessions
- Add a WebSocket endpoint at `/api/ws/party/{partyId}` (Vercel Edge Runtime supports WebSockets)
- Host writes to `sync_state/{partyId}`; guests subscribe via WebSocket
- The Flutter `SyncEngine` already polls `sync_state` — for parties, upgrade to WebSocket subscription (no polling)
- Add a "Start Listening Party" button in NowPlayingScreen that creates a party ID + shareable URL

**Estimated effort:** 3-5 days
**Dependencies:** Vercel Edge Runtime (free), Flutter `web_socket_channel` package

---

#### 2. Community Theme Store ⭐ medium priority

**What Monochrome does:**
- `themes` PocketBase collection: `{author, name, description, css, installs, created, updated}`
- Users submit CSS snippets that override CSS custom properties (`--background`, `--primary`, etc.)
- `installs` counter tracks popularity
- `THEME_GUIDE.md` documents the CSS variable contract

**How to adapt for Sonic Cloud:**
- Add a `themes` table to Turso: `{id, author_id, name, description, theme_json, installs, created, updated}`
- `theme_json` stores a `ThemeData` seed (accent color, surface colors, font family) instead of raw CSS — Flutter doesn't have CSS
- Add `/api/themes` (GET list, POST submit, POST install/{id}) endpoints
- Add a "Theme Store" screen in Settings that browses/installs community themes
- `ThemeService` already supports custom accent colors — extend it to load full themes from JSON

**Estimated effort:** 2-3 days
**Dependencies:** None new

---

#### 3. Bot Detection for Public Routes ⭐ low priority (until we add public sharing)

**What Monochrome does:**
- Every Cloudflare Pages Function checks User-Agent against a regex of 25+ bot patterns
- Bots get SSR'd meta-tag HTML (for Discord/Twitter/Telegram link previews)
- Real users get the SPA

**How to adapt for Sonic Cloud:**
- Only relevant if we add public playlist sharing (`/playlist/{id}` URLs)
- Add a Vercel Edge Function that checks User-Agent and returns OG meta tags for bots
- Currently out of scope — Sonic Cloud doesn't have public routes yet

**Estimated effort:** 1 day (when needed)

---

#### 4. ffmpeg.wasm Downloads ⭐ medium priority

**What Monochrome does:**
- `js/ffmpeg.js` + `js/ffmpeg.worker.js` use ffmpeg compiled to WebAssembly
- Transcodes TIDAL's HLS/DASH streams to MP3/FLAC for downloads
- Embeds metadata (ID3 tags) via `@dantheman827/taglib-ts`
- Progress UI with `js/downloadProgressUtils.js`

**How to adapt for Sonic Cloud:**
- For tracks streamed from cloud providers (Google Drive, WebDAV), add a "Download" button
- Use ffmpeg.wasm to transcode to a chosen format (MP3/FLAC/OPUS) if the source is a different format
- Embed metadata (title, artist, album, art) from the `Track` model
- Bundle ffmpeg-core in the web build (~30MB, lazy-loaded)

**Estimated effort:** 4-5 days
**Dependencies:** `@ffmpeg/ffmpeg`, `@ffmpeg/core`, `@ffmpeg/util` Flutter web packages

---

#### 5. Butterchurn Visualizer ⭐ low priority (nice-to-have)

**What Monochrome does:**
- `js/visualizer.js` uses Butterchurn (JavaScript port of Winamp's Milkdrop)
- 200+ presets via `butterchurn-presets`
- Web Audio API analyser node for frequency data
- Auto-cycle mode + manual preset switching (keyboard `[` / `]`)

**How to adapt for Sonic Cloud:**
- Butterchurn is web-only (Canvas + Web Audio) — wouldn't work on Flutter mobile/desktop
- For Flutter, consider `audio_visualizer` package or custom shader-based visualizer
- Lower priority since Sonic Cloud's design is minimalist (vinyl art + waveform seek bar)

**Estimated effort:** 3 days (web only) / 2 weeks (cross-platform custom)

---

#### 6. Multi-instance Failover ⭐ low priority

**What Monochrome does:**
- `public/instances.json` lists 4 official instances
- Client can failover between them if one is down

**How to adapt for Sonic Cloud:**
- Sonic Cloud already has a configurable "Server URL" in Settings (M1)
- Could add an `instances.json` to the repo with known public instances
- Client tries the primary, falls back to alternates on network error
- Mostly relevant if Sonic Cloud gets community-hosted instances

**Estimated effort:** 1 day

---

### What Monochrome does worse (validate our choices)

| Aspect | Monochrome | Sonic Cloud (our approach) |
|---|---|---|
| **Self-hosting** | Broken — auth backend is closed ("Accounts will not work on self-hosted instances") | Fully self-hostable — Turso + Vercel free tier, 10-min setup |
| **Desktop** | Web + mobile only | macOS + Windows + Linux via Flutter |
| **Legal risk** | Hardcoded TIDAL credentials + proxy (TOS violation) | Syncs user's own files, no legal risk |
| **Vendor lock-in** | PocketBase + Better-Auth hosted by maintainers | SQLite-compatible schema, portable to any DB |
| **Data ownership** | User data on maintainer's PocketBase | User data on user's own Turso |

---

## Source: (add future analyzed repos here)

<!-- Template:
### Source: [Repo name]([URL])
**Analyzed:** [date] · **Version:** [x] · **License:** [license]
**What it is:** [one-line description]
**Stack:** [tech]

#### Borrowable features
[features with implementation notes]

#### What it does worse
[comparison points]
-->
