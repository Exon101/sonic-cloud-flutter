// GET    /api/devices         — list the user's active sessions
// DELETE /api/devices?prefix= — revoke a specific device by id (or id prefix)
//
// Devices are identified by a stable deviceId (set by the client at sign-in).
// For backward-compat with the old API that used token prefixes, the DELETE
// endpoint matches devices whose id starts with the given prefix.

const { ok, error, requireAuth, toVercel } = require('../_lib/http');
const { db } = require('../_lib/db');

module.exports = toVercel(async (event) => {
  const { userId } = requireAuth(event, null);

  if (event.httpMethod === 'GET') {
    const devices = await db.listDevices(userId);
    return ok({ sessions: devices, count: devices.length });
  }

  if (event.httpMethod === 'DELETE') {
    const prefix = event.queryStringParameters?.prefix
      || (event.path || '').split('/').pop();
    if (!prefix) return error('Missing device id / prefix', 400, 'invalid_request');

    const revoked = await db.revokeDeviceByPrefix(userId, prefix);
    if (revoked === 0) return error('Device not found', 404, 'not_found');
    return ok({ revoked, prefix });
  }

  return error('Method not allowed', 405, 'method_not_allowed');
});
