// GET    /api/library/:id   — fetch one track
// PUT    /api/library/:id   — upsert one track (full replace)
// DELETE /api/library/:id   — remove a track from the cloud library

const { store } = require('../_lib/store');
const { ok, error, readJson, requireAuth, handle } = require('../_lib/http');

module.exports = handle(async (event) => {
  const { userId } = requireAuth(event, store);
  const id = event.queryStringParameters?.id || (event.path || '').split('/').pop();
  if (!id) return error('Missing track id', 400, 'invalid_request');

  if (event.httpMethod === 'GET') {
    const track = store.getTrack(userId, id);
    if (!track) return error('Track not found', 404, 'not_found');
    return ok({ track });
  }

  if (event.httpMethod === 'PUT') {
    const body = await readJson(event);
    const saved = store.putTrack(userId, id, body || {});
    return ok({ track: saved });
  }

  if (event.httpMethod === 'DELETE') {
    const removed = store.deleteTrack(userId, id);
    if (!removed) return error('Track not found', 404, 'not_found');
    return ok({ deleted: true, id });
  }

  return error('Method not allowed', 405, 'method_not_allowed');
});
