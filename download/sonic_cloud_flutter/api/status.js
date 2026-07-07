// GET /api/status — health check + version info + DB stats.
// Public, no auth required.

const { ok, VERSION, toVercel } = require('./_lib/http');
const { db } = require('./_lib/db');

module.exports = toVercel(async (event) => {
  if (event.httpMethod !== 'GET') {
    return require('./_lib/http').error('Method not allowed', 405, 'method_not_allowed');
  }
  let stats = {};
  try {
    stats = await db.stats();
  } catch (e) {
    stats = { error: e.message };
  }
  return ok({
    name: 'sonic-cloud-api',
    version: VERSION,
    time: new Date().toISOString(),
    database: process.env.TURSO_DB_URL ? 'turso' : 'memory',
    stats,
    endpoints: [
      'POST /api/auth/signin',
      'GET  /api/auth/me',
      'GET  /api/library',
      'POST /api/library',
      'GET  /api/library/:id',
      'PUT  /api/library/:id',
      'DELETE /api/library/:id',
      'GET  /api/playlists',
      'POST /api/playlists',
      'GET  /api/playlists/:id',
      'PUT  /api/playlists/:id',
      'PATCH /api/playlists/:id',
      'DELETE /api/playlists/:id',
      'GET  /api/lyrics?trackId=',
      'PUT  /api/lyrics?trackId=',
      'POST /api/sync/push',
      'GET  /api/sync/pull?since=',
      'GET  /api/devices',
      'DELETE /api/devices?prefix=',
    ],
  });
});
