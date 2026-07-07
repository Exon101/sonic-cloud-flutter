// GET /api/auth/me — return the current authenticated user.

const { store } = require('../_lib/store');
const { ok, error, requireAuth, handle } = require('../_lib/http');

module.exports = handle(async (event) => {
  if (event.httpMethod !== 'GET') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }
  const { userId, session } = requireAuth(event, store);
  return ok({
    user: store.getUser(userId),
    session: {
      deviceId: session.deviceId,
      createdAt: session.createdAt,
      lastSeenAt: session.lastSeenAt,
    },
  });
});
