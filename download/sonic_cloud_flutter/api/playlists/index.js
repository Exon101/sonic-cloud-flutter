// GET  /api/playlists     — list user's playlists
// POST /api/playlists     — create a new playlist
//
// Playlist shape mirrors lib/models/models.dart:
// {
//   id: string,
//   name: string,
//   kind: 'manual' | 'smart' | 'auto',   // default 'manual'
//   rules?: SmartPlaylistRule[],         // for kind='smart'
//   autoKind?: string,                   // for kind='auto' (e.g. 'favorites')
//   trackIds: string[],
//   createdAt, updatedAt
// }

const crypto = require('crypto');
const { store } = require('../_lib/store');
const { ok, error, readJson, requireAuth, handle, toVercel} = require('../_lib/http');

module.exports = toVercel(async (event) => {
  const { userId } = requireAuth(event, store);

  if (event.httpMethod === 'GET') {
    const playlists = store.listPlaylists(userId);
    return ok({ playlists, count: playlists.length });
  }

  if (event.httpMethod === 'POST') {
    const body = await readJson(event);
    if (!body || !body.name) {
      return error('Missing required field: name', 400, 'invalid_request');
    }
    const id = body.id || ('pl_' + crypto.randomBytes(8).toString('hex'));
    const playlist = store.putPlaylist(userId, id, {
      name: String(body.name).slice(0, 200),
      kind: ['manual', 'smart', 'auto'].includes(body.kind) ? body.kind : 'manual',
      rules: Array.isArray(body.rules) ? body.rules : [],
      autoKind: body.autoKind ? String(body.autoKind) : null,
      trackIds: Array.isArray(body.trackIds) ? body.trackIds.map(String) : [],
      createdAt: Date.now(),
    });
    return ok({ playlist }, 201);
  }

  return error('Method not allowed', 405, 'method_not_allowed');
});
