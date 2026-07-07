// Turso (libSQL) client wrapper for the Sonic Cloud API.
//
// This is the durable replacement for the in-memory `Store` class in
// store.js. It exposes the SAME method names so handler code changes are
// minimal — most handlers just swap `store.X()` for `db.X()`.
//
// Connection: reads TURSO_DB_URL + TURSO_AUTH_TOKEN from env vars. In test
// environments without those vars, falls back to an in-memory local SQLite
// (via @libsql/client's `:memory:` URL) so tests still pass without a real
// Turso account.
//
// Schema lives in schema.sql — applied via `npm run migrate` or
// `turso db shell <url> < api/_lib/schema.sql`.

const { createClient } = require('@libsql/client');

const TURSO_URL = process.env.TURSO_DB_URL;
const TURSO_TOKEN = process.env.TURSO_AUTH_TOKEN;

let _client = null;
let _initialized = false;

function getClient() {
  if (_client) return _client;
  if (TURSO_URL && TURSO_TOKEN) {
    _client = createClient({
      url: TURSO_URL,
      authToken: TURSO_TOKEN,
    });
  } else {
    // Fallback for tests / local dev without a real Turso account.
    // Uses an in-memory libSQL database that resets on every process
    // restart — same behavior as the old store.js, so tests still pass.
    _client = createClient({ url: ':memory:' });
  }
  return _client;
}

async function ensureSchema() {
  if (_initialized) return;
  const client = getClient();
  const fs = require('fs');
  const path = require('path');
  const schemaPath = path.join(__dirname, 'schema.sql');
  const schema = fs.readFileSync(schemaPath, 'utf-8');
  // libSQL client doesn't support multi-statement execute in one call
  // reliably. Split on semicolons at end-of-line, then strip comment-only
  // lines from each statement. Statements that become empty after stripping
  // comments are skipped.
  const stmts = schema
    .split(/;\s*\n/)
    .map(s => {
      // Strip lines that start with -- (SQL comments)
      return s
        .split('\n')
        .filter(line => !line.trim().startsWith('--'))
        .join('\n')
        .trim();
    })
    .filter(s => s.length > 0);
  for (const stmt of stmts) {
    try {
      await client.execute(stmt);
    } catch (e) {
      // "table already exists" / "index already exists" — fine for idempotent runs
      if (!/already exists/i.test(e.message)) throw e;
    }
  }
  _initialized = true;
}

// Helper: convert a libSQL row (which is an array of typed values keyed by
// column name) to a plain JS object.
function row(r) {
  return r ? { ...r } : null;
}

// ─── Database wrapper ──────────────────────────────────────────────────────

const db = {
  // ── Users ────────────────────────────────────────────────────────────────
  async upsertUser(id, email = null, opts = {}) {
    await ensureSchema();
    const now = Date.now();
    const client = getClient();
    // Try insert; on conflict (email already exists for email signups) do nothing.
    await client.execute({
      sql: `INSERT INTO users (id, email, is_anonymous, display_name, tier, settings, created_at, last_seen_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET last_seen_at = excluded.last_seen_at`,
      args: [
        id,
        email,
        opts.isAnonymous ? 1 : 0,
        opts.displayName || null,
        opts.tier || 'guest',
        opts.settings ? JSON.stringify(opts.settings) : null,
        now,
        now,
      ],
    });
    return await this.getUser(id);
  },

  async getUser(id) {
    await ensureSchema();
    const client = getClient();
    const r = await client.execute({ sql: 'SELECT * FROM users WHERE id = ?', args: [id] });
    if (r.rows.length === 0) return null;
    const u = row(r.rows[0]);
    u.isAnonymous = !!u.is_anonymous;
    u.createdAt = u.created_at;
    u.lastSeenAt = u.last_seen_at;
    u.settings = u.settings ? JSON.parse(u.settings) : {};
    delete u.is_anonymous; delete u.created_at; delete u.last_seen_at;
    return u;
  },

  async updateUserSettings(id, settings) {
    await ensureSchema();
    const client = getClient();
    await client.execute({
      sql: 'UPDATE users SET settings = ?, last_seen_at = ? WHERE id = ?',
      args: [JSON.stringify(settings), Date.now(), id],
    });
    return await this.getUser(id);
  },

  // ── Tracks ───────────────────────────────────────────────────────────────
  async listTracks(userId, opts = {}) {
    await ensureSchema();
    const client = getClient();
    const limit = Math.min(opts.limit || 100, 500);
    const offset = opts.cursor || 0;
    const r = await client.execute({
      sql: 'SELECT * FROM tracks WHERE user_id = ? ORDER BY updated_at DESC LIMIT ? OFFSET ?',
      args: [userId, limit, offset],
    });
    const tracks = r.rows.map(rowFromTrackRow);
    const totalR = await client.execute({
      sql: 'SELECT COUNT(*) as n FROM tracks WHERE user_id = ?',
      args: [userId],
    });
    const total = totalR.rows[0].n;
    const nextCursor = offset + tracks.length < total ? String(offset + tracks.length) : null;
    return { tracks, count: tracks.length, total, nextCursor };
  },

  /// Incremental polling: return only tracks with updated_at > since.
  async listTracksChangedSince(userId, since) {
    await ensureSchema();
    const client = getClient();
    const r = await client.execute({
      sql: 'SELECT * FROM tracks WHERE user_id = ? AND updated_at > ? ORDER BY updated_at ASC LIMIT 500',
      args: [userId, since],
    });
    return { tracks: r.rows.map(rowFromTrackRow) };
  },

  async getTrack(userId, trackId) {
    await ensureSchema();
    const client = getClient();
    const r = await client.execute({
      sql: 'SELECT * FROM tracks WHERE user_id = ? AND id = ?',
      args: [userId, trackId],
    });
    return r.rows.length > 0 ? rowFromTrackRow(r.rows[0]) : null;
  },

  async putTrack(userId, trackId, track) {
    await ensureSchema();
    const client = getClient();
    const now = Date.now();
    await client.execute({
      sql: `INSERT INTO tracks (
              id, user_id, title, artist, album, album_artist, genre, composer,
              year, duration_sec, format, file_size, file_system_path,
              cloud_provider, source_id, rating, play_count, last_played_at,
              date_added, is_favorite, is_cloud_only, updated_at, updated_by_device
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(user_id, id) DO UPDATE SET
              title=excluded.title, artist=excluded.artist, album=excluded.album,
              album_artist=excluded.album_artist, genre=excluded.genre,
              composer=excluded.composer, year=excluded.year,
              duration_sec=excluded.duration_sec, format=excluded.format,
              file_size=excluded.file_size, file_system_path=excluded.file_system_path,
              cloud_provider=excluded.cloud_provider, source_id=excluded.source_id,
              rating=excluded.rating, is_favorite=excluded.is_favorite,
              is_cloud_only=excluded.is_cloud_only,
              updated_at=excluded.updated_at,
              updated_by_device=excluded.updated_by_device`,
      args: [
        trackId, userId,
        track.title || 'Unknown',
        track.artist || 'Unknown Artist',
        track.album || null,
        track.albumArtist || null,
        track.genre || null,
        track.composer || null,
        track.year || null,
        track.duration || 0,
        track.format || null,
        track.fileSize || null,
        track.fileSystemPath || null,
        track.cloudProvider || null,
        track.sourceId || null,
        track.rating || 0,
        track.playCount || 0,
        track.lastPlayedAt || null,
        track.dateAdded || now,
        track.isFavorite ? 1 : 0,
        track.isCloudOnly ? 1 : 0,
        now,
        track.updatedByDevice || null,
      ],
    });
    return await this.getTrack(userId, trackId);
  },

  async deleteTrack(userId, trackId) {
    await ensureSchema();
    const client = getClient();
    const r = await client.execute({
      sql: 'DELETE FROM tracks WHERE user_id = ? AND id = ?',
      args: [userId, trackId],
    });
    return r.rowsAffected > 0;
  },

  async incrementPlayCount(userId, trackId) {
    await ensureSchema();
    const client = getClient();
    const now = Date.now();
    await client.execute({
      sql: `UPDATE tracks SET play_count = play_count + 1, last_played_at = ?, updated_at = ?
            WHERE user_id = ? AND id = ?`,
      args: [now, now, userId, trackId],
    });
    return await this.getTrack(userId, trackId);
  },

  // ── Playlists ────────────────────────────────────────────────────────────
  async listPlaylists(userId) {
    await ensureSchema();
    const client = getClient();
    const r = await client.execute({
      sql: 'SELECT * FROM playlists WHERE user_id = ? ORDER BY name COLLATE NOCASE ASC',
      args: [userId],
    });
    return r.rows.map(rowFromPlaylistRow);
  },

  async getPlaylist(userId, playlistId) {
    await ensureSchema();
    const client = getClient();
    const r = await client.execute({
      sql: 'SELECT * FROM playlists WHERE user_id = ? AND id = ?',
      args: [userId, playlistId],
    });
    return r.rows.length > 0 ? rowFromPlaylistRow(r.rows[0]) : null;
  },

  async putPlaylist(userId, playlistId, pl) {
    await ensureSchema();
    const client = getClient();
    const now = Date.now();
    const existing = await this.getPlaylist(userId, playlistId);
    const createdAt = existing ? existing.createdAt : now;
    await client.execute({
      sql: `INSERT INTO playlists (
              id, user_id, name, kind, track_ids, rules, auto_kind,
              description, art_url, created_at, updated_at, updated_by_device
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(user_id, id) DO UPDATE SET
              name=excluded.name, kind=excluded.kind, track_ids=excluded.track_ids,
              rules=excluded.rules, auto_kind=excluded.auto_kind,
              description=excluded.description, art_url=excluded.art_url,
              updated_at=excluded.updated_at, updated_by_device=excluded.updated_by_device`,
      args: [
        playlistId, userId,
        pl.name || 'Untitled',
        pl.kind || 'manual',
        JSON.stringify(pl.trackIds || []),
        pl.rules ? JSON.stringify(pl.rules) : null,
        pl.autoKind || null,
        pl.description || null,
        pl.artUrl || null,
        createdAt, now,
        pl.updatedByDevice || null,
      ],
    });
    return await this.getPlaylist(userId, playlistId);
  },

  async deletePlaylist(userId, playlistId) {
    await ensureSchema();
    const client = getClient();
    const r = await client.execute({
      sql: 'DELETE FROM playlists WHERE user_id = ? AND id = ?',
      args: [userId, playlistId],
    });
    return r.rowsAffected > 0;
  },

  // ── Lyrics ───────────────────────────────────────────────────────────────
  async getLyrics(userId, trackId) {
    await ensureSchema();
    const client = getClient();
    const r = await client.execute({
      sql: 'SELECT * FROM lyrics WHERE user_id = ? AND track_id = ?',
      args: [userId, trackId],
    });
    if (r.rows.length === 0) return null;
    const l = row(r.rows[0]);
    return {
      trackId,
      raw: l.raw,
      provider: l.provider,
      synced: !!l.is_synced,
      updatedAt: l.updated_at,
    };
  },

  async putLyrics(userId, trackId, lyrics) {
    await ensureSchema();
    const client = getClient();
    const now = Date.now();
    await client.execute({
      sql: `INSERT INTO lyrics (user_id, track_id, raw, provider, is_synced, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(user_id, track_id) DO UPDATE SET
              raw=excluded.raw, provider=excluded.provider,
              is_synced=excluded.is_synced, updated_at=excluded.updated_at`,
      args: [
        userId, trackId,
        lyrics.raw,
        lyrics.provider || 'user',
        lyrics.synced ? 1 : 0,
        now,
      ],
    });
    return await this.getLyrics(userId, trackId);
  },

  // ── Sync state ───────────────────────────────────────────────────────────
  async getSync(userId) {
    await ensureSchema();
    const client = getClient();
    const r = await client.execute({
      sql: 'SELECT * FROM sync_state WHERE user_id = ?',
      args: [userId],
    });
    if (r.rows.length === 0) {
      // Return a default empty state — DON'T auto-create the row here (would
      // cause infinite recursion with putSync, which calls getSync).
      return {
        queue: [],
        favorites: [],
        ratings: {},
        positions: {},
        settings: {},
        currentIndex: 0,
        shuffleEnabled: false,
        repeatMode: 'off',
        speed: 1.0,
        positionSec: 0,
        positionUpdatedAt: null,
        playing: false,
        updatedAt: 0,
        updatedByDevice: null,
      };
    }
    const s = row(r.rows[0]);
    return {
      queue: s.queue ? JSON.parse(s.queue) : [],
      favorites: s.favorites ? JSON.parse(s.favorites) : [],
      ratings: s.ratings ? JSON.parse(s.ratings) : {},
      positions: s.positions ? JSON.parse(s.positions) : {},
      settings: s.settings ? JSON.parse(s.settings) : {},
      currentIndex: s.current_index || 0,
      shuffleEnabled: !!s.shuffle_enabled,
      repeatMode: s.repeat_mode || 'off',
      speed: s.speed || 1.0,
      positionSec: s.position_sec || 0,
      positionUpdatedAt: s.position_updated_at,
      playing: !!s.playing,
      updatedAt: s.updated_at,
      updatedByDevice: s.updated_by_device,
    };
  },

  async putSync(userId, patch) {
    await ensureSchema();
    const client = getClient();
    const current = await this.getSync(userId);
    // Shallow-merge nested objects so callers can patch one field at a time.
    const next = {
      queue: Array.isArray(patch.queue) ? patch.queue : current.queue,
      favorites: Array.isArray(patch.favorites) ? patch.favorites : current.favorites,
      ratings: patch.ratings
        ? { ...current.ratings, ...patch.ratings }
        : current.ratings,
      positions: patch.positions
        ? { ...current.positions, ...patch.positions }
        : current.positions,
      settings: patch.settings
        ? { ...current.settings, ...patch.settings }
        : current.settings,
      currentIndex: patch.currentIndex != null ? patch.currentIndex : current.currentIndex,
      shuffleEnabled: patch.shuffleEnabled != null ? patch.shuffleEnabled : current.shuffleEnabled,
      repeatMode: patch.repeatMode || current.repeatMode,
      speed: patch.speed != null ? patch.speed : current.speed,
      positionSec: patch.positionSec != null ? patch.positionSec : current.positionSec,
      positionUpdatedAt: patch.positionUpdatedAt != null ? patch.positionUpdatedAt : current.positionUpdatedAt,
      playing: patch.playing != null ? patch.playing : current.playing,
      updatedAt: Date.now(),
      updatedByDevice: patch.updatedByDevice || current.updatedByDevice,
    };
    await client.execute({
      sql: `INSERT INTO sync_state (
              user_id, queue, favorites, ratings, positions, settings,
              current_index, shuffle_enabled, repeat_mode, speed,
              position_sec, position_updated_at, playing,
              updated_at, updated_by_device
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET
              queue=excluded.queue, favorites=excluded.favorites,
              ratings=excluded.ratings, positions=excluded.positions,
              settings=excluded.settings, current_index=excluded.current_index,
              shuffle_enabled=excluded.shuffle_enabled,
              repeat_mode=excluded.repeat_mode, speed=excluded.speed,
              position_sec=excluded.position_sec,
              position_updated_at=excluded.position_updated_at,
              playing=excluded.playing, updated_at=excluded.updated_at,
              updated_by_device=excluded.updated_by_device`,
      args: [
        userId,
        JSON.stringify(next.queue),
        JSON.stringify(next.favorites),
        JSON.stringify(next.ratings),
        JSON.stringify(next.positions),
        JSON.stringify(next.settings),
        next.currentIndex,
        next.shuffleEnabled ? 1 : 0,
        next.repeatMode,
        next.speed,
        next.positionSec,
        next.positionUpdatedAt,
        next.playing ? 1 : 0,
        next.updatedAt,
        next.updatedByDevice,
      ],
    });
    return next;
  },

  // ── Devices ──────────────────────────────────────────────────────────────
  async listDevices(userId) {
    await ensureSchema();
    const client = getClient();
    const r = await client.execute({
      sql: 'SELECT * FROM devices WHERE user_id = ? AND is_revoked = 0 ORDER BY last_seen_at DESC',
      args: [userId],
    });
    return r.rows.map(d => {
      const r2 = row(d);
      return {
        id: r2.id,
        userId: r2.user_id,
        name: r2.name,
        platform: r2.platform,
        appVersion: r2.app_version,
        pushToken: r2.push_token,
        isRevoked: !!r2.is_revoked,
        createdAt: r2.created_at,
        lastSeenAt: r2.last_seen_at,
      };
    });
  },

  async upsertDevice(userId, deviceId, info = {}) {
    await ensureSchema();
    const client = getClient();
    const now = Date.now();
    await client.execute({
      sql: `INSERT INTO devices (id, user_id, name, platform, app_version, push_token,
                                  is_revoked, created_at, last_seen_at)
            VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?)
            ON CONFLICT(user_id, id) DO UPDATE SET
              name=excluded.name, platform=excluded.platform,
              app_version=excluded.app_version, push_token=excluded.push_token,
              last_seen_at=excluded.last_seen_at`,
      args: [
        deviceId, userId,
        info.name || null,
        info.platform || null,
        info.appVersion || null,
        info.pushToken || null,
        now, now,
      ],
    });
    return { id: deviceId, userId, ...info, createdAt: now, lastSeenAt: now };
  },

  async revokeDevice(userId, deviceId) {
    await ensureSchema();
    const client = getClient();
    const r = await client.execute({
      sql: 'UPDATE devices SET is_revoked = 1 WHERE user_id = ? AND id = ?',
      args: [userId, deviceId],
    });
    return r.rowsAffected > 0;
  },

  async revokeDeviceByPrefix(userId, prefix) {
    await ensureSchema();
    const client = getClient();
    // deviceId is a stable string, not a token prefix. For backward-compat
    // with the old API that used token prefixes, we match devices whose id
    // starts with the prefix.
    const r = await client.execute({
      sql: 'UPDATE devices SET is_revoked = 1 WHERE user_id = ? AND id LIKE ?',
      args: [userId, prefix + '%'],
    });
    return r.rowsAffected;
  },

  async touchDevice(userId, deviceId) {
    await ensureSchema();
    const client = getClient();
    await client.execute({
      sql: 'UPDATE devices SET last_seen_at = ? WHERE user_id = ? AND id = ?',
      args: [Date.now(), userId, deviceId],
    });
  },

  // ── Misc ─────────────────────────────────────────────────────────────────
  async stats() {
    await ensureSchema();
    const client = getClient();
    const tables = ['users', 'tracks', 'playlists', 'lyrics', 'devices', 'sync_state'];
    const out = {};
    for (const t of tables) {
      try {
        const r = await client.execute({ sql: `SELECT COUNT(*) as n FROM ${t}`, args: [] });
        out[t] = r.rows[0].n;
      } catch (_) {
        out[t] = 0;
      }
    }
    return out;
  },
};

// ─── Row mappers ────────────────────────────────────────────────────────────

function rowFromTrackRow(r) {
  const t = row(r);
  return {
    id: t.id,
    userId: t.user_id,
    title: t.title,
    artist: t.artist,
    album: t.album,
    albumArtist: t.album_artist,
    genre: t.genre,
    composer: t.composer,
    year: t.year,
    duration: t.duration_sec,
    format: t.format,
    fileSize: t.file_size,
    fileSystemPath: t.file_system_path,
    cloudProvider: t.cloud_provider,
    sourceId: t.source_id,
    rating: t.rating,
    playCount: t.play_count,
    lastPlayedAt: t.last_played_at,
    dateAdded: t.date_added,
    isFavorite: !!t.is_favorite,
    isCloudOnly: !!t.is_cloud_only,
    updatedAt: t.updated_at,
    updatedByDevice: t.updated_by_device,
  };
}

function rowFromPlaylistRow(r) {
  const p = row(r);
  return {
    id: p.id,
    userId: p.user_id,
    name: p.name,
    kind: p.kind,
    trackIds: p.track_ids ? JSON.parse(p.track_ids) : [],
    rules: p.rules ? JSON.parse(p.rules) : [],
    autoKind: p.auto_kind,
    description: p.description,
    artUrl: p.art_url,
    createdAt: p.created_at,
    updatedAt: p.updated_at,
    updatedByDevice: p.updated_by_device,
  };
}

module.exports = { db, getClient, ensureSchema };
