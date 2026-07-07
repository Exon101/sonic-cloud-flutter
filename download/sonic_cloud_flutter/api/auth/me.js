// GET /api/auth/me — return the current authenticated user + device list.
//
// Auth is JWT-based: the user id is extracted from the token payload, so
// this endpoint works statelessly (no server-side session lookup needed).

const { ok, error, requireAuth, toVercel } = require('../_lib/http');
const { db } = require('../_lib/db');

module.exports = toVercel(async (event) => {
  if (event.httpMethod !== 'GET') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }
  const { userId, session } = requireAuth(event, null);
  const user = await db.getUser(userId);
  const devices = await db.listDevices(userId);
  return ok({
    user: user || { id: userId, email: null, isAnonymous: true, createdAt: 0 },
    session: {
      deviceId: session.deviceId,
      createdAt: session.createdAt || 0,
      lastSeenAt: Date.now(),
    },
    devices,
  });
});
