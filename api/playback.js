// In-memory playback state (per serverless instance — for production use
// Vercel KV, Upstash Redis, or a database)
let playbackState = {
  isPlaying: false,
  currentTrack: null,
  position: 0,
  duration: 0,
  queue: [],
};

export default function handler(req, res) {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  if (req.method === 'GET') {
    res.status(200).json(playbackState);
    return;
  }

  if (req.method === 'POST') {
    playbackState = { ...playbackState, ...req.body };
    res.status(200).json({ status: 'updated', state: playbackState });
    return;
  }

  res.status(405).json({ error: 'Method not allowed' });
}
