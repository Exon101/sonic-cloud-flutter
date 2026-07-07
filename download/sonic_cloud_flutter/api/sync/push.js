// POST /api/sync/push  — merge user data into the cloud sync state
//
// Body (all fields optional):
// {
//   queue?:       string[],
//   favorites?:   string[],
//   ratings?:     { [trackId: string]: number },      // 0..5
//   positions?:   { [trackId: string]: number },      // seconds
//   settings?:    { [key: string]: any },
//   currentIndex?:      number,
//   shuffleEnabled?:    boolean,
//   repeatMode?:        string,
//   speed?:             number,
//   positionSec?:       number,
//   positionUpdatedAt?: number,
//   playing?:           boolean,
//   updatedByDevice?:  string,
// }

const { ok, error, readJson, requireAuth, toVercel } = require('../_lib/http');
const { db } = require('../_lib/db');

module.exports = toVercel(async (event) => {
  if (event.httpMethod !== 'POST') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }
  const { userId } = requireAuth(event, null);
  const patch = await readJson(event);

  // Whitelist + light validation
  const clean = {};
  if (Array.isArray(patch.queue)) clean.queue = patch.queue.map(String);
  if (Array.isArray(patch.favorites)) clean.favorites = patch.favorites.map(String);
  if (patch.ratings && typeof patch.ratings === 'object') {
    clean.ratings = {};
    for (const [k, v] of Object.entries(patch.ratings)) {
      const n = Math.max(0, Math.min(5, Number(v) || 0));
      clean.ratings[String(k)] = n;
    }
  }
  if (patch.positions && typeof patch.positions === 'object') {
    clean.positions = {};
    for (const [k, v] of Object.entries(patch.positions)) {
      const n = Math.max(0, Number(v) || 0);
      clean.positions[String(k)] = n;
    }
  }
  if (patch.settings && typeof patch.settings === 'object') {
    clean.settings = patch.settings;
  }
  if (patch.currentIndex != null) clean.currentIndex = patch.currentIndex;
  if (patch.shuffleEnabled != null) clean.shuffleEnabled = !!patch.shuffleEnabled;
  if (patch.repeatMode) clean.repeatMode = patch.repeatMode;
  if (patch.speed != null) clean.speed = patch.speed;
  if (patch.positionSec != null) clean.positionSec = patch.positionSec;
  if (patch.positionUpdatedAt != null) clean.positionUpdatedAt = patch.positionUpdatedAt;
  if (patch.playing != null) clean.playing = !!patch.playing;
  if (patch.updatedByDevice) clean.updatedByDevice = patch.updatedByDevice;

  const merged = await db.putSync(userId, clean);
  return ok({ sync: merged, serverTime: merged.updatedAt });
});
