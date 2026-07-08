// GET /api/stream?trackId=<id>
//
// Returns a 302 redirect to the Vercel Blob URL for the track's audio file.
// Used as a CORS-free streaming proxy — the Flutter app can always hit
// /api/stream?trackId=X regardless of where the audio bytes live.
//
// If the track's sourceId is a direct URL (e.g., a Vercel Blob URL), we
// redirect to it. If the track was uploaded to a cloud provider, we'd
// need to generate a time-limited URL (future enhancement).

const { ok, error, requireAuth, toVercel } = require('./_lib/http');
const { db } = require('./_lib/db');

module.exports = toVercel(async (event) => {
  if (event.httpMethod !== 'GET') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }
  const { userId } = requireAuth(event, null);
  const trackId = event.queryStringParameters?.trackId;
  if (!trackId) return error('Missing query param: trackId', 400, 'invalid_request');

  const track = await db.getTrack(userId, trackId);
  if (!track) return error('Track not found', 404, 'not_found');

  // The sourceId field holds the audio URL for uploaded tracks
  const audioUrl = track.sourceId;
  if (!audioUrl || !audioUrl.startsWith('http')) {
    return error('Track has no streamable URL (sourceId is not a URL)', 404, 'no_stream_url');
  }

  // Return the URL as JSON — the client can use it directly with just_audio
  return ok({ trackId, url: audioUrl, format: track.format });
});
