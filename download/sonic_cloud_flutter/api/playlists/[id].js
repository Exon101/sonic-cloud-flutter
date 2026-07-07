// GET    /api/playlists/:id  — fetch one playlist
// PUT    /api/playlists/:id  — full replace
// PATCH  /api/playlists/:id  — partial patch (e.g. add/remove trackIds)
// DELETE /api/playlists/:id  — delete

const { store } = require('../_lib/store');
const { ok, error, readJson, requireAuth, handle, toVercel} = require('../_lib/http');

function patchPlaylist(existing, patch) {
  const next = { ...existing };
  if (typeof patch.name === 'string') next.name = patch.name.slice(0, 200);
  if (typeof patch.kind === 'string' && ['manual', 'smart', 'auto'].includes(patch.kind)) {
    next.kind = patch.kind;
  }
  if (Array.isArray(patch.rules)) next.rules = patch.rules;
  if ('autoKind' in patch) next.autoKind = patch.autoKind ? String(patch.autoKind) : null;

  if (Array.isArray(patch.trackIds)) {
    next.trackIds = patch.trackIds.map(String);
  } else if (Array.isArray(patch.addTrackIds) || Array.isArray(patch.removeTrackIds)) {
    const set = new Set(next.trackIds || []);
    for (const t of patch.addTrackIds || []) set.add(String(t));
    for (const t of patch.removeTrackIds || []) set.delete(String(t));
    next.trackIds = [...set];
  }
  return next;
}

module.exports = toVercel(async (event) => {
  const { userId } = requireAuth(event, store);
  const id = event.queryStringParameters?.id || (event.path || '').split('/').pop();
  if (!id) return error('Missing playlist id', 400, 'invalid_request');

  if (event.httpMethod === 'GET') {
    const playlist = store.getPlaylist(userId, id);
    if (!playlist) return error('Playlist not found', 404, 'not_found');
    return ok({ playlist });
  }

  if (event.httpMethod === 'PUT') {
    const body = await readJson(event);
    const saved = store.putPlaylist(userId, id, body || {});
    return ok({ playlist: saved });
  }

  if (event.httpMethod === 'PATCH') {
    const existing = store.getPlaylist(userId, id);
    if (!existing) return error('Playlist not found', 404, 'not_found');
    const patch = await readJson(event);
    const saved = store.putPlaylist(userId, id, patchPlaylist(existing, patch));
    return ok({ playlist: saved });
  }

  if (event.httpMethod === 'DELETE') {
    const removed = store.deletePlaylist(userId, id);
    if (!removed) return error('Playlist not found', 404, 'not_found');
    return ok({ deleted: true, id });
  }

  return error('Method not allowed', 405, 'method_not_allowed');
});
