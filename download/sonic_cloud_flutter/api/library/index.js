// GET  /api/library      — list current user's tracks (supports ?limit=, ?cursor=)
// POST /api/library      — create or upsert a track into the cloud library
//
// A "track" in the cloud library is metadata only — the audio bytes live on
// the user's device or one of their connected cloud providers. The cloud
// library just remembers what's in the universal library so it can be
// synced across devices.

const { store } = require('../_lib/store');
const { ok, error, readJson, requireAuth, handle } = require('../_lib/http');

module.exports = handle(async (event) => {
  const { userId } = requireAuth(event, store);

  if (event.httpMethod === 'GET') {
    const limit = Math.min(parseInt(event.queryStringParameters?.limit, 10) || 100, 500);
    const cursor = event.queryStringParameters?.cursor ? parseInt(event.queryStringParameters.cursor, 10) : 0;
    const all = store.listTracks(userId);
    const slice = all.slice(cursor, cursor + limit);
    return ok({
      tracks: slice,
      count: slice.length,
      total: all.length,
      nextCursor: cursor + slice.length < all.length ? String(cursor + slice.length) : null,
    });
  }

  if (event.httpMethod === 'POST') {
    const body = await readJson(event);
    if (!body || !body.id) {
      return error('Missing required field: id', 400, 'invalid_request');
    }
    const allowed = ['title', 'artist', 'album', 'albumArtist', 'genre', 'composer',
                     'year', 'duration', 'format', 'fileSize', 'fileSystemPath',
                     'source', 'cloudProvider', 'rating', 'lastPlayedAt', 'playCount'];
    const clean = {};
    for (const k of allowed) if (k in body) clean[k] = body[k];
    const saved = store.putTrack(userId, String(body.id), clean);
    return ok({ track: saved }, 201);
  }

  return error('Method not allowed', 405, 'method_not_allowed');
});
