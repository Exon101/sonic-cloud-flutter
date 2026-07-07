// GET  /api/lyrics?trackId=<id>  — fetch stored lyrics for a track
// PUT  /api/lyrics?trackId=<id>  — store lyrics for a track
//
// Body for PUT: { raw: string, provider?: string }
// Returns for GET: { trackId, raw, provider, synced, updatedAt }
//
// The server parses LRC so the wire format is uniform regardless of where
// the lyrics came from (embedded ID3 tag, .lrc file, third-party provider).

const { ok, error, readJson, requireAuth, toVercel } = require('../_lib/http');
const { db } = require('../_lib/db');
const { parseLrc } = require('../_lib/lrc');

module.exports = toVercel(async (event) => {
  const { userId } = requireAuth(event, null);
  const trackId = event.queryStringParameters?.trackId;
  if (!trackId) return error('Missing query param: trackId', 400, 'invalid_request');

  if (event.httpMethod === 'GET') {
    const stored = await db.getLyrics(userId, trackId);
    if (!stored) return error('Lyrics not found', 404, 'not_found');
    // Re-parse on read so the client gets lines + metadata without extra work.
    const parsed = parseLrc(stored.raw);
    return ok({ trackId, ...stored, lines: parsed.lines, metadata: parsed.metadata });
  }

  if (event.httpMethod === 'PUT') {
    const body = await readJson(event);
    if (!body || typeof body.raw !== 'string') {
      return error('Missing required field: raw', 400, 'invalid_request');
    }
    const parsed = parseLrc(body.raw);
    const saved = await db.putLyrics(userId, trackId, {
      raw: body.raw,
      provider: body.provider || 'user',
      synced: parsed.synced,
    });
    // Return the full parsed object so the client gets lines + metadata
    // without having to re-parse the raw text.
    return ok({
      trackId,
      lyrics: {
        ...saved,
        lines: parsed.lines,
        metadata: parsed.metadata,
      },
    });
  }

  return error('Method not allowed', 405, 'method_not_allowed');
});
