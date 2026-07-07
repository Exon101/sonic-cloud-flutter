// GET  /api/playlists     — list user's playlists
// POST /api/playlists     — create a new playlist

const crypto = require('crypto');
const { ok, error, readJson, requireAuth, toVercel } = require('../_lib/http');
const { db } = require('../_lib/db');

module.exports = toVercel(async (event) => {
  const { userId } = requireAuth(event, null);

  if (event.httpMethod === 'GET') {
    const playlists = await db.listPlaylists(userId);
    return ok({ playlists, count: playlists.length });
  }

  if (event.httpMethod === 'POST') {
    const body = await readJson(event);
    if (!body || !body.name) {
      return error('Missing required field: name', 400, 'invalid_request');
    }
    const id = body.id || ('pl_' + crypto.randomBytes(8).toString('hex'));
    const playlist = await db.putPlaylist(userId, id, {
      name: String(body.name).slice(0, 200),
      kind: ['manual', 'smart', 'auto'].includes(body.kind) ? body.kind : 'manual',
      rules: Array.isArray(body.rules) ? body.rules : [],
      autoKind: body.autoKind ? String(body.autoKind) : null,
      trackIds: Array.isArray(body.trackIds) ? body.trackIds.map(String) : [],
      description: body.description || null,
      artUrl: body.artUrl || null,
    });
    return ok({ playlist }, 201);
  }

  return error('Method not allowed', 405, 'method_not_allowed');
});
