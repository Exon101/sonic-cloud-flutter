export default function handler(req, res) {
  res.status(200).json({
    status: 'ok',
    service: 'sonic-cloud',
    version: '4.5.0',
    timestamp: new Date().toISOString(),
  });
}
