// POST /api/sync/push  — merge user data into the cloud sync state
//
// Body (all fields optional):
// {
//   queue?:       string[],
//   favorites?:   string[],
//   ratings?:     { [trackId: string]: number },      // 0..5
//   positions?:   { [trackId: string]: number },      // seconds
//   settings?:    { [key: string]: any },
// }
//
// Returns the merged sync state and the server timestamp so the client
// can store it for next pull's `?since=` query.

const { store } = require('../_lib/store');
const { ok, error, readJson, requireAuth, handle, toVercel} = require('../_lib/http');

module.exports = toVercel(async (event) => {
  if (event.httpMethod !== 'POST') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }
  const { userId } = requireAuth(event, store);
  const patch = await readJson(event);

  // Whitelist + light validation.
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

  const merged = store.putSync(userId, clean);
  return ok({ sync: merged, serverTime: merged.updatedAt });
});
