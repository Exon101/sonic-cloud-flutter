// GET    /api/devices         — list the user's active sessions
// DELETE /api/devices/:token  — revoke a specific session by token prefix
//
// Token prefixes are returned by GET so callers can revoke without ever
// seeing the full token again. The prefix must match the first 8 chars of
// the token (the part shown in `session.token`).

const { store } = require('../_lib/store');
const { ok, error, requireAuth, handle } = require('../_lib/http');

module.exports = handle(async (event) => {
  const { userId } = requireAuth(event, store);

  if (event.httpMethod === 'GET') {
    return ok({ sessions: store.listSessions(userId) });
  }

  if (event.httpMethod === 'DELETE') {
    const prefix = event.queryStringParameters?.prefix
      || (event.path || '').split('/').pop();
    if (!prefix) return error('Missing session prefix', 400, 'invalid_request');

    let revoked = 0;
    for (const [token] of [...store.sessions.entries()]) {
      if (token.startsWith(prefix)) {
        store.sessions.delete(token);
        revoked++;
      }
    }
    if (revoked === 0) return error('Session not found', 404, 'not_found');
    return ok({ revoked, prefix });
  }

  return error('Method not allowed', 405, 'method_not_allowed');
});
