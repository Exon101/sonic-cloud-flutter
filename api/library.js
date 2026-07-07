// In-memory library (for production use Vercel KV or a database)
let tracks = [];

export default function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  if (req.method === 'GET') {
    res.status(200).json({ tracks, count: tracks.length });
    return;
  }

  if (req.method === 'POST') {
    const track = req.body;
    tracks.push({ ...track, id: track.id || Date.now().toString() });
    res.status(201).json({ status: 'added', track });
    return;
  }

  if (req.method === 'DELETE') {
    const { id } = req.query;
    if (id) {
      tracks = tracks.filter(t => t.id !== id);
      res.status(200).json({ status: 'deleted', id });
    } else {
      tracks = [];
      res.status(200).json({ status: 'cleared' });
    }
    return;
  }

  res.status(405).json({ error: 'Method not allowed' });
}
