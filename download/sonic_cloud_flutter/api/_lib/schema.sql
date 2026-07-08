-- Sonic Cloud — Turso (libSQL/SQLite) schema
--
-- 6 tables, all scoped by user_id. See BACKEND_SYNC_PLAN.md §5.1 for the
-- design rationale. Schema is intentionally portable to Cloudflare D1 /
-- local SQLite / PocketBase / Postgres (with minor type tweaks).
--
-- Apply with:
--   turso db shell <db-url> < api/_lib/schema.sql
-- Or locally:
--   sqlite3 sonic-cloud.db < api/_lib/schema.sql

-- ─── users ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id           TEXT PRIMARY KEY,
  email        TEXT UNIQUE,
  is_anonymous INTEGER NOT NULL DEFAULT 0,
  display_name TEXT,
  avatar_url   TEXT,
  tier         TEXT NOT NULL DEFAULT 'guest',
  password_hash TEXT,                         -- scrypt hash (M3) — null for anonymous/OAuth-only
  oauth_provider TEXT,                        -- 'google' | 'apple' | 'github' | null
  oauth_subject TEXT,                         -- provider-specific user id
  settings     TEXT,                          -- JSON blob
  created_at   INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL
);

-- ─── tracks (library — metadata only, audio bytes stay client-side) ────────
CREATE TABLE IF NOT EXISTS tracks (
  id               TEXT NOT NULL,
  user_id          TEXT NOT NULL,
  title            TEXT NOT NULL,
  artist           TEXT NOT NULL,
  album            TEXT,
  album_artist     TEXT,
  genre            TEXT,
  composer         TEXT,
  year             INTEGER,
  duration_sec     REAL NOT NULL,
  format           TEXT,
  file_size        INTEGER,
  file_system_path TEXT,
  cloud_provider   TEXT,
  source_id        TEXT,
  rating           INTEGER NOT NULL DEFAULT 0,
  play_count       INTEGER NOT NULL DEFAULT 0,
  last_played_at   INTEGER,
  date_added       INTEGER,
  is_favorite      INTEGER NOT NULL DEFAULT 0,
  is_cloud_only    INTEGER NOT NULL DEFAULT 0,
  updated_at       INTEGER NOT NULL,
  updated_by_device TEXT,
  PRIMARY KEY (user_id, id)
);

CREATE INDEX IF NOT EXISTS idx_tracks_user_artist       ON tracks(user_id, artist, title);
CREATE INDEX IF NOT EXISTS idx_tracks_user_last_played  ON tracks(user_id, last_played_at DESC);
CREATE INDEX IF NOT EXISTS idx_tracks_user_play_count   ON tracks(user_id, play_count DESC);
CREATE INDEX IF NOT EXISTS idx_tracks_user_favorite     ON tracks(user_id, is_favorite) WHERE is_favorite = 1;
CREATE INDEX IF NOT EXISTS idx_tracks_user_updated      ON tracks(user_id, updated_at);

-- ─── playlists ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS playlists (
  id            TEXT NOT NULL,
  user_id       TEXT NOT NULL,
  name          TEXT NOT NULL,
  kind          TEXT NOT NULL,                 -- 'manual' | 'smart' | 'auto'
  track_ids     TEXT NOT NULL,                 -- JSON array
  rules         TEXT,                          -- JSON for smart playlists
  auto_kind     TEXT,
  description   TEXT,
  art_url       TEXT,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL,
  updated_by_device TEXT,
  PRIMARY KEY (user_id, id)
);

CREATE INDEX IF NOT EXISTS idx_playlists_user_updated ON playlists(user_id, updated_at);

-- ─── lyrics (keyed by trackId for O(1) fetch) ──────────────────────────────
CREATE TABLE IF NOT EXISTS lyrics (
  user_id    TEXT NOT NULL,
  track_id   TEXT NOT NULL,
  raw        TEXT NOT NULL,
  provider   TEXT NOT NULL DEFAULT 'user',
  is_synced  INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, track_id)
);

-- ─── devices (sessions, last-seen, push tokens) ────────────────────────────
CREATE TABLE IF NOT EXISTS devices (
  id           TEXT NOT NULL,
  user_id      TEXT NOT NULL,
  name         TEXT,
  platform     TEXT,
  app_version  TEXT,
  push_token   TEXT,
  is_revoked   INTEGER NOT NULL DEFAULT 0,
  created_at   INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, id)
);

CREATE INDEX IF NOT EXISTS idx_devices_user_active ON devices(user_id, is_revoked, last_seen_at DESC);

-- ─── sync_state (one row per user — "what's playing right now" + cross-device state) ───
CREATE TABLE IF NOT EXISTS sync_state (
  user_id            TEXT PRIMARY KEY,
  queue              TEXT,                     -- JSON array of track IDs
  favorites          TEXT,                     -- JSON array of track IDs
  ratings            TEXT,                     -- JSON map { trackId: 0..5 }
  positions          TEXT,                     -- JSON map { trackId: seconds }
  settings           TEXT,                     -- JSON map of arbitrary settings
  current_index      INTEGER NOT NULL DEFAULT 0,
  shuffle_enabled    INTEGER NOT NULL DEFAULT 0,
  repeat_mode        TEXT NOT NULL DEFAULT 'off',
  speed              REAL NOT NULL DEFAULT 1.0,
  position_sec       REAL NOT NULL DEFAULT 0.0,
  position_updated_at INTEGER,
  playing            INTEGER NOT NULL DEFAULT 0,
  updated_at         INTEGER NOT NULL,
  updated_by_device  TEXT
);
