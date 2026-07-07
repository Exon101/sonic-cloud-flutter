// GET /api/sync/pull  — return the user's full sync state
//
// Query params:
//   ?since=<ms>  — if provided, only returns sync state if it changed
//                  after the given timestamp; otherwise returns 304-style
//                  { unchanged: true }.

const { store } = require('../_lib/store');
const { ok, error, requireAuth, handle, toVercel} = require('../_lib/http');

module.exports = toVercel(async (event) => {
  if (event.httpMethod !== 'GET') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }
  const { userId } = requireAuth(event, store);
  const sync = store.getSync(userId);

  const since = event.queryStringParameters?.since ? parseInt(event.queryStringParameters.since, 10) : null;
  if (since != null && sync.updatedAt <= since) {
    return ok({ unchanged: true, serverTime: sync.updatedAt });
  }
  return ok({ sync, serverTime: sync.updatedAt });
});
