// /api/sync — consolidated sync endpoint (push + pull).
//
// Vercel Hobby plan limits each deployment to 12 serverless functions.
// We consolidate the 2 sync endpoints into a single file to stay under
// the limit.
//
// Routes:
//   POST /api/sync?action=push  — merge user data into cloud sync state
//   GET  /api/sync?action=pull  — return the user's full sync state
//
// For backward compat, the old paths still work via rewrites in vercel.json:
//   /api/sync/push → /api/sync?action=push
//   /api/sync/pull → /api/sync?action=pull

const { ok, error, readJson, requireAuth, toVercel } = require('./_lib/http');
const { db } = require('./_lib/db');

module.exports = toVercel(async (event) => {
  const action = event.queryStringParameters?.action || 'pull';
  const { userId } = requireAuth(event, null);

  // ── pull ────────────────────────────────────────────────────────────────
  if (action === 'pull' && event.httpMethod === 'GET') {
    const sync = await db.getSync(userId);
    const since = event.queryStringParameters?.since
      ? parseInt(event.queryStringParameters.since, 10)
      : null;
    if (since != null && sync.updatedAt <= since) {
      return ok({ unchanged: true, serverTime: sync.updatedAt });
    }
    return ok({ sync, serverTime: sync.updatedAt });
  }

  // ── push ────────────────────────────────────────────────────────────────
  if (action === 'push' && event.httpMethod === 'POST') {
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
  }

  return error(`Unknown sync action: ${action}`, 400, 'unknown_action');
});
