// POST /api/upload
// Body: multipart/form-data with:
//   file:    the audio file (required)
//   title:   track title (optional, defaults to filename)
//   artist:  track artist (optional, defaults to "Unknown Artist")
//   album:   track album (optional)
//
// Stores the file in Vercel Blob, creates a track record in Turso, and
// returns the track metadata + the blob URL.
//
// The blob URL is publicly readable — just_audio can stream it directly
// on web, mobile, and desktop. The URL is stored in tracks.audio_url
// (via the source_id field since the tracks table doesn't have an
// audio_url column — the client resolves it from the blob URL).
//
// Setup: set BLOB_READ_WRITE_TOKEN in Vercel env vars (create at
// https://vercel.com/stores — free tier: 1GB storage, 10GB bandwidth).

const { put } = require('@vercel/blob');
const { ok, error, requireAuth, toVercel } = require('./_lib/http');
const { db } = require('./_lib/db');
const crypto = require('crypto');

/// Parse a multipart/form-data body from the raw request buffer.
/// Returns { fields: {...}, file: { name, type, data } }.
function parseMultipart(buffer, contentType) {
  const boundaryMatch = /boundary=(.+)$/.exec(contentType);
  if (!boundaryMatch) throw new Error('No boundary in content-type');
  const boundary = boundaryMatch[1].trim();

  const boundaryBuf = Buffer.from('--' + boundary);
  const parts = [];
  let start = buffer.indexOf(boundaryBuf);

  while (start !== -1) {
    const nextStart = buffer.indexOf(boundaryBuf, start + boundaryBuf.length);
    if (nextStart === -1) break;
    const partData = buffer.slice(start + boundaryBuf.length + 2, nextStart - 2); // -2 for \r\n before boundary
    parts.push(partData);
    start = nextStart;
  }

  const fields = {};
  let file = null;

  for (const part of parts) {
    const headerEnd = part.indexOf('\r\n\r\n');
    if (headerEnd === -1) continue;
    const headerStr = part.slice(0, headerEnd).toString('utf-8');
    const body = part.slice(headerEnd + 4);

    // Parse Content-Disposition
    const nameMatch = /name="([^"]+)"/.exec(headerStr);
    if (!nameMatch) continue;
    const name = nameMatch[1];

    const filenameMatch = /filename="([^"]*)"/.exec(headerStr);
    if (filenameMatch) {
      // This is a file part
      const typeMatch = /Content-Type:\s*(.+)/i.exec(headerStr);
      file = {
        name: filenameMatch[1],
        type: typeMatch ? typeMatch[1].trim() : 'application/octet-stream',
        data: body,
      };
    } else {
      // This is a regular field
      fields[name] = body.toString('utf-8');
    }
  }

  return { fields, file };
}

/// Extract file extension from filename.
function getExtension(filename) {
  const idx = filename.lastIndexOf('.');
  return idx >= 0 ? filename.slice(idx + 1).toLowerCase() : '';
}

/// Map file extension to AudioFormat name.
function formatFromExt(ext) {
  const map = {
    mp3: 'mp3', flac: 'flac', wav: 'wav', aac: 'aac',
    ogg: 'ogg', m4a: 'm4a', opus: 'opus',
  };
  return map[ext] || null;
}

module.exports = toVercel(async (event) => {
  if (event.httpMethod !== 'POST') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }
  const { userId } = requireAuth(event, null);

  // Check that blob storage is configured
  if (!process.env.BLOB_READ_WRITE_TOKEN) {
    return error(
      'File upload not configured. Set BLOB_READ_WRITE_TOKEN env var on Vercel. ' +
      'Create a blob store at https://vercel.com/stores (free tier: 1GB).',
      503,
      'blob_not_configured',
    );
  }

  // Parse multipart body
  const contentType = event.headers['content-type'] || event.headers['Content-Type'] || '';
  if (!contentType.includes('multipart/form-data')) {
    return error('Content-Type must be multipart/form-data', 400, 'invalid_content_type');
  }

  let parsed;
  try {
    const bodyBuf = Buffer.from(event.body || '', event.isBase64Encoded ? 'base64' : 'utf-8');
    parsed = parseMultipart(bodyBuf, contentType);
  } catch (e) {
    return error(`Failed to parse multipart body: ${e.message}`, 400, 'parse_error');
  }

  if (!parsed.file || !parsed.file.data) {
    return error('No file in upload. Include a "file" field in the multipart body.', 400, 'no_file');
  }

  const file = parsed.file;
  const ext = getExtension(file.name);
  const format = formatFromExt(ext);

  if (!format) {
    return error(
      `Unsupported file format: .${ext}. Supported: mp3, flac, wav, aac, ogg, m4a, opus`,
      400,
      'unsupported_format',
    );
  }

  // Limit file size to 100MB (Vercel function payload limit is ~4.5MB on Hobby,
  // so this mainly applies to mobile/desktop uploads via the API)
  const MAX_SIZE = 100 * 1024 * 1024;
  if (file.data.length > MAX_SIZE) {
    return error(`File too large: ${file.data.length} bytes (max ${MAX_SIZE})`, 413, 'file_too_large');
  }

  // Generate a unique track ID + blob path
  const trackId = 'tr_' + crypto.randomBytes(8).toString('hex');
  const blobPathname = `tracks/${userId}/${trackId}.${ext}`;

  // Upload to Vercel Blob
  let blob;
  try {
    blob = await put(blobPathname, file.data, {
      access: 'public',
      contentType: file.type,
      addRandomSuffix: false,
      token: process.env.BLOB_READ_WRITE_TOKEN,
    });
  } catch (e) {
    return error(`Blob upload failed: ${e.message}`, 502, 'blob_upload_failed');
  }

  // Extract title from filename if not provided
  const title = parsed.fields.title || file.name.replace(/\.[^.]+$/, '');
  const artist = parsed.fields.artist || 'Unknown Artist';
  const album = parsed.fields.album || '';

  // Estimate duration from file size (rough — real duration needs audio parsing)
  // ~1MB per minute for MP3 @ 128kbps. This is just a placeholder; the client
  // will update the real duration after loading the audio.
  const estimatedDuration = Math.max(1, Math.round(file.data.length / (1024 * 1024) * 60));

  // Create track record in Turso
  const track = await db.putTrack(userId, trackId, {
    title,
    artist,
    album,
    duration: estimatedDuration,
    format,
    fileSize: file.data.length,
    fileSystemPath: blobPathname,
    cloudProvider: 'vercel-blob',
    sourceId: blob.url,  // Store the blob URL in source_id — client uses this as audioUrl
    isFavorite: false,
    isCloudOnly: true,
    playCount: 0,
    rating: 0,
    dateAdded: Date.now(),
    updatedByDevice: 'upload',
  });

  return ok({
    track,
    blobUrl: blob.url,
    uploadSize: file.data.length,
  }, 201);
});
