// GET  /api/library      — list current user's tracks (supports ?limit=, ?cursor=)
// POST /api/library      — create or upsert a track into the cloud library

const { ok, error, readJson, requireAuth, toVercel } = require('../_lib/http');
const { db } = require('../_lib/db');

module.exports = toVercel(async (event) => {
  const { userId } = requireAuth(event, null);

  if (event.httpMethod === 'GET') {
    const limit = event.queryStringParameters?.limit ? parseInt(event.queryStringParameters.limit, 10) : 100;
    const cursor = event.queryStringParameters?.cursor ? parseInt(event.queryStringParameters.cursor, 10) : 0;
    const result = await db.listTracks(userId, { limit, cursor });
    return ok(result);
  }

  if (event.httpMethod === 'POST') {
    const body = await readJson(event);
    if (!body || !body.id) {
      return error('Missing required field: id', 400, 'invalid_request');
    }
    const saved = await db.putTrack(userId, String(body.id), body);
    return ok({ track: saved }, 201);
  }

  return error('Method not allowed', 405, 'method_not_allowed');
});
