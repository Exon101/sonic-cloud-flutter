// Full sync endpoint — combines playback + library + playlists + settings
// In-memory storage (for production use Vercel KV or Upstash Redis)
let syncData = {
  playback: { isPlaying: false, currentTrack: null, position: 0 },
  tracks: [],
  playlists: [],
  settings: {},
};

export default function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  if (req.method === 'GET') {
    res.status(200).json({
      ...syncData,
      syncedAt: new Date().toISOString(),
    });
    return;
  }

  if (req.method === 'POST') {
    const { playback, tracks, playlists, settings } = req.body;
    if (playback) syncData.playback = { ...syncData.playback, ...playback };
    if (tracks) syncData.tracks = tracks;
    if (playlists) syncData.playlists = playlists;
    if (settings) syncData.settings = { ...syncData.settings, ...settings };
    res.status(200).json({ status: 'synced', timestamp: new Date().toISOString() });
    return;
  }

  res.status(405).json({ error: 'Method not allowed' });
}
