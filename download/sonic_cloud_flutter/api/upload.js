// POST /api/upload
//
// Accepts multipart/form-data with one or more files. Supports three modes:
//
// 1. Single audio file:
//    file: track.mp3  (+ optional title/artist/album fields)
//
// 2. ZIP archive:
//    file: album.zip
//    The ZIP is extracted server-side. Each audio file becomes a track.
//    .lrc files are paired with tracks by filename (track1.mp3 ↔ track1.lrc).
//    A metadata.json in the ZIP provides title/artist/album/year for tracks.
//    Supported audio: mp3, flac, wav, aac, ogg, m4a, opus
//
// 3. Multiple files (batch):
//    files: track1.mp3, track2.flac, lyrics1.lrc, metadata.json
//    Same processing as ZIP but without the zip wrapper.
//
// Returns: { tracks: [...], lyrics: [...], errors: [...], totalSize }
//
// Setup: set BLOB_READ_WRITE_TOKEN in Vercel env vars.

const { put } = require('@vercel/blob');
const AdmZip = require('adm-zip');
const { ok, error, requireAuth, toVercel } = require('./_lib/http');
const { db } = require('./_lib/db');
const { parseLrc } = require('./_lib/lrc');
const crypto = require('crypto');

// ── Helpers ────────────────────────────────────────────────────────────────

const AUDIO_EXTENSIONS = ['mp3', 'flac', 'wav', 'aac', 'ogg', 'm4a', 'opus'];
const LYRICS_EXTENSIONS = ['lrc', 'txt'];
const METADATA_EXTENSIONS = ['json'];

function getExtension(filename) {
  const idx = filename.lastIndexOf('.');
  return idx >= 0 ? filename.slice(idx + 1).toLowerCase() : '';
}

function getBaseName(filename) {
  const ext = getExtension(filename);
  return ext ? filename.slice(0, -(ext.length + 1)) : filename;
}

function isAudio(name) {
  return AUDIO_EXTENSIONS.includes(getExtension(name));
}
function isLyrics(name) {
  return LYRICS_EXTENSIONS.includes(getExtension(name));
}
function isMetadata(name) {
  return METADATA_EXTENSIONS.includes(getExtension(name)) || getBaseName(name).toLowerCase() === 'metadata';
}
function isZip(name) {
  return getExtension(name) === 'zip';
}

function formatFromExt(ext) {
  return AUDIO_EXTENSIONS.includes(ext) ? ext : null;
}

/// Parse multipart/form-data body. Returns array of parts.
function parseMultipart(buffer, contentType) {
  const boundaryMatch = /boundary=(.+)$/.exec(contentType);
  if (!boundaryMatch) throw new Error('No boundary in content-type');
  const boundary = boundaryMatch[1].trim().replace(/"/g, '');

  const boundaryBuf = Buffer.from('--' + boundary);
  const parts = [];
  let start = buffer.indexOf(boundaryBuf);

  while (start !== -1) {
    const nextStart = buffer.indexOf(boundaryBuf, start + boundaryBuf.length);
    if (nextStart === -1) break;
    // Skip the \r\n after the boundary
    const partStart = start + boundaryBuf.length + 2;
    const partEnd = nextStart - 2; // -2 for \r\n before next boundary
    if (partEnd > partStart) {
      parts.push(buffer.slice(partStart, partEnd));
    }
    start = nextStart;
  }

  const fields = {};
  const files = [];

  for (const part of parts) {
    const headerEnd = part.indexOf('\r\n\r\n');
    if (headerEnd === -1) continue;
    const headerStr = part.slice(0, headerEnd).toString('utf-8');
    const body = part.slice(headerEnd + 4);

    const nameMatch = /name="([^"]+)"/.exec(headerStr);
    if (!nameMatch) continue;
    const name = nameMatch[1];

    const filenameMatch = /filename="([^"]*)"/.exec(headerStr);
    if (filenameMatch) {
      const typeMatch = /Content-Type:\s*(.+)/i.exec(headerStr);
      files.push({
        fieldName: name,
        name: filenameMatch[1],
        type: typeMatch ? typeMatch[1].trim() : 'application/octet-stream',
        data: body,
      });
    } else {
      fields[name] = body.toString('utf-8');
    }
  }

  return { fields, files };
}

/// Upload a single audio file to Vercel Blob + create track in Turso.
/// Returns the track object.
async function uploadAudioFile(userId, file, metadata = {}) {
  const ext = getExtension(file.name);
  const format = formatFromExt(ext);
  if (!format) throw new Error(`Unsupported format: .${ext}`);

  const trackId = 'tr_' + crypto.randomBytes(8).toString('hex');
  const blobPathname = `tracks/${userId}/${trackId}.${ext}`;

  const blob = await put(blobPathname, file.data, {
    access: 'public',
    contentType: file.type || `audio/${ext}`,
    addRandomSuffix: false,
    token: process.env.BLOB_READ_WRITE_TOKEN,
  });

  // Estimate duration (~1MB/min for MP3@128kbps — placeholder, client updates)
  const estimatedDuration = Math.max(1, Math.round(file.data.length / (1024 * 1024) * 60));

  const title = metadata.title || getBaseName(file.name);
  const track = await db.putTrack(userId, trackId, {
    title,
    artist: metadata.artist || 'Unknown Artist',
    album: metadata.album || '',
    year: metadata.year || 0,
    duration: estimatedDuration,
    format,
    fileSize: file.data.length,
    fileSystemPath: blobPathname,
    cloudProvider: 'vercel-blob',
    sourceId: blob.url,
    isCloudOnly: true,
    playCount: 0,
    rating: 0,
    dateAdded: Date.now(),
    updatedByDevice: 'upload',
  });

  return { track, blobUrl: blob.url };
}

/// Store lyrics for a track. Pairs by base filename.
async function uploadLyricsFile(userId, file, trackMap) {
  const baseName = getBaseName(file.name);
  // Find a track with the same base name
  const trackEntry = trackMap[baseName];
  if (!trackEntry) {
    return { error: `No track found matching lyrics file "${file.name}" (looking for "${baseName}.mp3/flac/etc")` };
  }

  const rawLrc = file.data.toString('utf-8');
  const parsed = parseLrc(rawLrc);
  const saved = await db.putLyrics(userId, trackEntry.track.id, {
    raw: rawLrc,
    provider: 'upload',
    synced: parsed.synced,
  });

  return { trackId: trackEntry.track.id, lyrics: saved };
}

/// Parse metadata.json from a ZIP or batch upload.
/// Expected format: { "tracks": [{ "file": "track1.mp3", "title": "...", "artist": "...", ... }] }
/// Or flat: { "track1.mp3": { "title": "...", "artist": "..." }, ... }
function parseMetadataJson(jsonString) {
  try {
    const data = JSON.parse(jsonString);
    // Normalize to { filename: { title, artist, album, year } }
    const map = {};
    if (Array.isArray(data.tracks)) {
      for (const t of data.tracks) {
        if (t.file) map[t.file.toLowerCase()] = t;
      }
    } else {
      for (const [key, val] of Object.entries(data)) {
        map[key.toLowerCase()] = val;
      }
    }
    return map;
  } catch (e) {
    return {};
  }
}

/// Process a ZIP file: extract, categorize files, upload each.
async function processZip(userId, zipFile) {
  const results = { tracks: [], lyrics: [], errors: [], totalSize: 0 };
  let zip;

  try {
    zip = new AdmZip(zipFile.data);
  } catch (e) {
    results.errors.push(`Failed to open ZIP: ${e.message}`);
    return results;
  }

  const entries = zip.getEntries();
  const audioFiles = [];
  const lyricsFiles = [];
  let metadataMap = {};

  // First pass: categorize files
  for (const entry of entries) {
    if (entry.isDirectory) continue;
    const name = entry.entryName;
    // Skip macOS hidden files
    if (name.startsWith('__MACOSX/') || name.startsWith('.') || name.includes('/.')) continue;

    const fileObj = {
      name: name.includes('/') ? name.split('/').pop() : name, // Use basename
      data: entry.getData(),
      type: 'application/octet-stream',
    };

    if (isAudio(name)) {
      audioFiles.push(fileObj);
    } else if (isLyrics(name)) {
      lyricsFiles.push(fileObj);
    } else if (isMetadata(name)) {
      metadataMap = { ...metadataMap, ...parseMetadataJson(fileObj.data.toString('utf-8')) };
    }
  }

  // Second pass: upload audio files
  const trackMap = {}; // baseName → { track, blobUrl }
  for (const file of audioFiles) {
    try {
      const baseName = getBaseName(file.name);
      const meta = metadataMap[file.name.toLowerCase()] ||
                   metadataMap[baseName.toLowerCase()] || {};
      const { track, blobUrl } = await uploadAudioFile(userId, file, meta);
      trackMap[baseName] = { track, blobUrl };
      results.tracks.push(track);
      results.totalSize += file.data.length;
    } catch (e) {
      results.errors.push(`${file.name}: ${e.message}`);
    }
  }

  // Third pass: upload lyrics, pair with tracks
  for (const file of lyricsFiles) {
    try {
      const result = await uploadLyricsFile(userId, file, trackMap);
      if (result.error) {
        results.errors.push(result.error);
      } else {
        results.lyrics.push(result);
      }
    } catch (e) {
      results.errors.push(`${file.name}: ${e.message}`);
    }
  }

  return results;
}

// ── Main handler ───────────────────────────────────────────────────────────

module.exports = toVercel(async (event) => {
  if (event.httpMethod !== 'POST') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }
  const { userId } = requireAuth(event, null);

  if (!process.env.BLOB_READ_WRITE_TOKEN) {
    return error(
      'File upload not configured. Set BLOB_READ_WRITE_TOKEN env var on Vercel. ' +
      'Create a blob store at https://vercel.com/stores (free tier: 1GB).',
      503,
      'blob_not_configured',
    );
  }

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

  if (!parsed.files || parsed.files.length === 0) {
    return error('No files in upload. Include a "file" or "files" field.', 400, 'no_files');
  }

  const results = { tracks: [], lyrics: [], errors: [], totalSize: 0 };

  // Separate ZIP files, audio files, lyrics files, and metadata
  const zipFiles = [];
  const audioFiles = [];
  const lyricsFiles = [];
  let metadataMap = {};

  for (const file of parsed.files) {
    if (isZip(file.name)) {
      zipFiles.push(file);
    } else if (isAudio(file.name)) {
      audioFiles.push(file);
    } else if (isLyrics(file.name)) {
      lyricsFiles.push(file);
    } else if (isMetadata(file.name)) {
      metadataMap = { ...metadataMap, ...parseMetadataJson(file.data.toString('utf-8')) };
    }
  }

  // Process ZIP files
  for (const zipFile of zipFiles) {
    const zipResults = await processZip(userId, zipFile);
    results.tracks.push(...zipResults.tracks);
    results.lyrics.push(...zipResults.lyrics);
    results.errors.push(...zipResults.errors);
    results.totalSize += zipResults.totalSize;
  }

  // Process individual audio files (from batch upload or single upload)
  const trackMap = {}; // baseName → { track, blobUrl }
  for (const file of audioFiles) {
    try {
      const baseName = getBaseName(file.name);
      const meta = metadataMap[file.name.toLowerCase()] ||
                   metadataMap[baseName.toLowerCase()] || {};
      // Also check form fields for single-file uploads
      if (audioFiles.length === 1) {
        if (parsed.fields.title) meta.title = parsed.fields.title;
        if (parsed.fields.artist) meta.artist = parsed.fields.artist;
        if (parsed.fields.album) meta.album = parsed.fields.album;
      }
      const { track, blobUrl } = await uploadAudioFile(userId, file, meta);
      trackMap[baseName] = { track, blobUrl };
      results.tracks.push(track);
      results.totalSize += file.data.length;
    } catch (e) {
      results.errors.push(`${file.name}: ${e.message}`);
    }
  }

  // Process lyrics files — pair with tracks
  for (const file of lyricsFiles) {
    try {
      const result = await uploadLyricsFile(userId, file, trackMap);
      if (result.error) {
        results.errors.push(result.error);
      } else {
        results.lyrics.push(result);
      }
    } catch (e) {
      results.errors.push(`${file.name}: ${e.message}`);
    }
  }

  // Return summary
  return ok({
    tracks: results.tracks,
    lyrics: results.lyrics,
    errors: results.errors,
    totalSize: results.totalSize,
    trackCount: results.tracks.length,
    lyricsCount: results.lyrics.length,
    errorCount: results.errors.length,
  }, 201);
});
