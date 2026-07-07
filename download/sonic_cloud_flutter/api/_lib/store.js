// In-memory store for the Sonic Cloud API.
//
// This is a single-process, ephemeral store intended for development and
// demos. Each Vercel serverless function invocation may run on a different
// instance, so data written here is NOT guaranteed to persist across
// invocations in production.
//
// To make the API persistent in production, swap the implementation of
// `Store` for one backed by Vercel KV, Vercel Postgres, Upstash Redis, or
// any other durable store. The public surface (async get/set/delete/list)
// is intentionally minimal so a real backend can be dropped in without
// touching the route handlers.

const crypto = require('crypto');

class Store {
  constructor() {
    this.users = new Map();        // userId -> { id, email, createdAt }
    this.sessions = new Map();     // token -> { userId, deviceId, createdAt, lastSeenAt }
    this.tracks = new Map();       // `${userId}:${trackId}` -> track
    this.playlists = new Map();    // `${userId}:${playlistId}` -> playlist
    this.lyrics = new Map();       // `${userId}:${trackId}` -> lyrics
    this.sync = new Map();         // userId -> { queue, favorites, ratings, positions, settings, updatedAt }
  }

  // ── Users ──────────────────────────────────────────────────────────────
  upsertUser(id, email = null) {
    if (!this.users.has(id)) {
      this.users.set(id, { id, email, createdAt: Date.now() });
    } else if (email) {
      this.users.get(id).email = email;
    }
    return this.users.get(id);
  }

  getUser(id) {
    return this.users.get(id) || null;
  }

  // ── Sessions ───────────────────────────────────────────────────────────
  createSession(userId, deviceId = null) {
    const token = crypto.randomBytes(32).toString('hex');
    const now = Date.now();
    this.sessions.set(token, { userId, deviceId, createdAt: now, lastSeenAt: now });
    return token;
  }

  getSession(token) {
    const s = this.sessions.get(token);
    if (!s) return null;
    s.lastSeenAt = Date.now();
    return s;
  }

  revokeSession(token) {
    return this.sessions.delete(token);
  }

  listSessions(userId) {
    return [...this.sessions.entries()]
      .filter(([, s]) => s.userId === userId)
      .map(([token, s]) => ({ token: token.slice(0, 8) + '…', ...s }));
  }

  // ── Tracks ─────────────────────────────────────────────────────────────
  listTracks(userId) {
    return [...this.tracks.entries()]
      .filter(([k]) => k.startsWith(userId + ':'))
      .map(([, v]) => v);
  }

  getTrack(userId, trackId) {
    return this.tracks.get(`${userId}:${trackId}`) || null;
  }

  putTrack(userId, trackId, track) {
    this.tracks.set(`${userId}:${trackId}`, { ...track, id: trackId, userId, updatedAt: Date.now() });
    return this.tracks.get(`${userId}:${trackId}`);
  }

  deleteTrack(userId, trackId) {
    return this.tracks.delete(`${userId}:${trackId}`);
  }

  // ── Playlists ──────────────────────────────────────────────────────────
  listPlaylists(userId) {
    return [...this.playlists.entries()]
      .filter(([k]) => k.startsWith(userId + ':'))
      .map(([, v]) => v);
  }

  getPlaylist(userId, playlistId) {
    return this.playlists.get(`${userId}:${playlistId}`) || null;
  }

  putPlaylist(userId, playlistId, playlist) {
    this.playlists.set(`${userId}:${playlistId}`, {
      ...playlist,
      id: playlistId,
      userId,
      updatedAt: Date.now(),
    });
    return this.playlists.get(`${userId}:${playlistId}`);
  }

  deletePlaylist(userId, playlistId) {
    return this.playlists.delete(`${userId}:${playlistId}`);
  }

  // ── Lyrics ─────────────────────────────────────────────────────────────
  getLyrics(userId, trackId) {
    return this.lyrics.get(`${userId}:${trackId}`) || null;
  }

  putLyrics(userId, trackId, lyrics) {
    this.lyrics.set(`${userId}:${trackId}`, { ...lyrics, trackId, updatedAt: Date.now() });
    return this.lyrics.get(`${userId}:${trackId}`);
  }

  // ── Sync state ─────────────────────────────────────────────────────────
  getSync(userId) {
    if (!this.sync.has(userId)) {
      this.sync.set(userId, {
        queue: [],
        favorites: [],
        ratings: {},
        positions: {},
        settings: {},
        updatedAt: Date.now(),
      });
    }
    return this.sync.get(userId);
  }

  putSync(userId, patch) {
    const cur = this.getSync(userId);
    const next = {
      ...cur,
      ...patch,
      // Shallow-merge nested objects so callers can patch just one field.
      settings: { ...cur.settings, ...(patch.settings || {}) },
      ratings: { ...cur.ratings, ...(patch.ratings || {}) },
      positions: { ...cur.positions, ...(patch.positions || {}) },
      updatedAt: Date.now(),
    };
    this.sync.set(userId, next);
    return next;
  }
}

// Singleton across warm invocations of the same instance.
const store = new Store();

module.exports = { Store, store };
