// GET /api/status — health check + version info.
// Public, no auth required.

const { ok, VERSION } = require('./_lib/http');
const { store } = require('./_lib/store');

module.exports = async (event) => {
  if (event.httpMethod !== 'GET') {
    return require('./_lib/http').error('Method not allowed', 405, 'method_not_allowed');
  }
  return ok({
    name: 'sonic-cloud-api',
    version: VERSION,
    time: new Date().toISOString(),
    stats: {
      users: store.users.size,
      sessions: store.sessions.size,
      tracks: store.tracks.size,
      playlists: store.playlists.size,
    },
    endpoints: [
      'POST /api/auth/signin',
      'GET  /api/auth/me',
      'GET  /api/library',
      'GET  /api/library/:id',
      'PUT  /api/library/:id',
      'DELETE /api/library/:id',
      'GET  /api/playlists',
      'POST /api/playlists',
      'GET  /api/playlists/:id',
      'PUT  /api/playlists/:id',
      'DELETE /api/playlists/:id',
      'GET  /api/lyrics?trackId=',
      'PUT  /api/lyrics?trackId=',
      'POST /api/sync/push',
      'GET  /api/sync/pull',
      'GET  /api/devices',
      'DELETE /api/devices/:token',
    ],
  });
};
