// GET /api/auth/me — return the current authenticated user.
//
// Auth is JWT-based: the user info is extracted from the token payload, so
// this endpoint works statelessly (no server-side session lookup needed).

const { ok, error, requireAuth, toVercel } = require('../_lib/http');

module.exports = toVercel(async (event) => {
  if (event.httpMethod !== 'GET') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }
  const { userId, session } = requireAuth(event, null);
  return ok({
    user: {
      id: userId,
      email: null, // JWT doesn't carry email; use /api/auth/signin to set it
      createdAt: session.createdAt || 0,
    },
    session: {
      deviceId: session.deviceId,
      createdAt: session.createdAt || 0,
      lastSeenAt: Date.now(),
    },
  });
});
