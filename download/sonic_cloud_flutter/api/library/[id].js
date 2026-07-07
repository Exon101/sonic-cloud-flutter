// GET    /api/library/:id   — fetch one track
// PUT    /api/library/:id   — upsert one track (full replace)
// DELETE /api/library/:id   — remove a track from the cloud library

const { ok, error, readJson, requireAuth, toVercel } = require('../_lib/http');
const { db } = require('../_lib/db');

module.exports = toVercel(async (event) => {
  const { userId } = requireAuth(event, null);
  const id = event.queryStringParameters?.id || (event.path || '').split('/').pop();
  if (!id) return error('Missing track id', 400, 'invalid_request');

  if (event.httpMethod === 'GET') {
    const track = await db.getTrack(userId, id);
    if (!track) return error('Track not found', 404, 'not_found');
    return ok({ track });
  }

  if (event.httpMethod === 'PUT') {
    const body = await readJson(event);
    const saved = await db.putTrack(userId, id, body || {});
    return ok({ track: saved });
  }

  if (event.httpMethod === 'DELETE') {
    const removed = await db.deleteTrack(userId, id);
    if (!removed) return error('Track not found', 404, 'not_found');
    return ok({ deleted: true, id });
  }

  return error('Method not allowed', 405, 'method_not_allowed');
});
