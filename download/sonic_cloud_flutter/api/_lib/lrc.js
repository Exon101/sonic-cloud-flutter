// LRC parser shared between /api/lyrics endpoints and any future server-side
// lyrics providers. Mirrors the parser in lib/services/lyrics_service.dart
// so the client and server agree on the wire format.

function parseLrc(raw) {
  if (typeof raw !== 'string' || !raw.trim()) {
    return { synced: false, lines: [], metadata: {} };
  }

  const lines = raw.split(/\r?\n/);
  const out = [];
  const metadata = {};
  const tsRe = /\[(\d+):(\d+)(?:[.:](\d+))?\]/g;

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;

    // Metadata header: [ar:Artist], [ti:Title], [al:Album], [by:Author], [offset:123]
    const meta = /^\[([a-zA-Z]+):\s*(.*?)\s*\]$/.exec(trimmed);
    if (meta && isNaN(parseInt(meta[1], 10))) {
      metadata[meta[1].toLowerCase()] = meta[2];
      continue;
    }

    let m;
    let lastMatches = [];
    while ((m = tsRe.exec(trimmed)) !== null) {
      const min = parseInt(m[1], 10);
      const sec = parseInt(m[2], 10);
      const frac = m[3] ? parseInt(m[3].padEnd(3, '0').slice(0, 3), 10) : 0;
      lastMatches.push(min * 60 + sec + frac / 1000);
    }
    tsRe.lastIndex = 0;

    const text = trimmed.replace(tsRe, '').trim();
    if (lastMatches.length === 0) {
      // Untimestamped line.
      out.push({ time: null, text });
    } else {
      for (const t of lastMatches) {
        out.push({ time: t, text });
      }
    }
  }

  out.sort((a, b) => (a.time == null ? 1 : b.time == null ? -1 : a.time - b.time));
  const synced = out.length > 0 && out.some((l) => l.time != null);
  return { synced, lines: out, metadata };
}

module.exports = { parseLrc };
