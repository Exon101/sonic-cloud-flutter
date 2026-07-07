// GET  /api/lyrics?trackId=<id>  — fetch stored lyrics for a track
// PUT  /api/lyrics?trackId=<id>  — store lyrics for a track
//
// Body for PUT: { raw: string, provider?: string }
// Returns for GET: { synced: boolean, lines: [{time, text}], metadata: {} }
//
// The server parses LRC so the wire format is uniform regardless of where
// the lyrics came from (embedded ID3 tag, .lrc file, third-party provider).

const { store } = require('../_lib/store');
const { ok, error, readJson, requireAuth, handle } = require('../_lib/http');
const { parseLrc } = require('../_lib/lrc');

module.exports = handle(async (event) => {
  const { userId } = requireAuth(event, store);
  const trackId = event.queryStringParameters?.trackId;
  if (!trackId) return error('Missing query param: trackId', 400, 'invalid_request');

  if (event.httpMethod === 'GET') {
    const stored = store.getLyrics(userId, trackId);
    if (!stored) return error('Lyrics not found', 404, 'not_found');
    return ok({ trackId, ...stored });
  }

  if (event.httpMethod === 'PUT') {
    const body = await readJson(event);
    if (!body || typeof body.raw !== 'string') {
      return error('Missing required field: raw', 400, 'invalid_request');
    }
    const parsed = parseLrc(body.raw);
    const saved = store.putLyrics(userId, trackId, {
      raw: body.raw,
      provider: body.provider || 'user',
      ...parsed,
    });
    return ok({ trackId, lyrics: saved });
  }

  return error('Method not allowed', 405, 'method_not_allowed');
});
