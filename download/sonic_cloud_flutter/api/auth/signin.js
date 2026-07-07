// POST /api/auth/signin
// Body: { email?: string, anonymous?: boolean, deviceId?: string }
// Returns: { token, userId, user, deviceId, createdAt }
//
// Issues a JWT containing { userId, deviceId } so subsequent requests can
// authenticate without a server-side session lookup — essential for
// serverless where the in-memory store doesn't persist across invocations.
//
// Anonymous mode is the default — pass { anonymous: true } or omit email to
// get a fresh ephemeral user. Passing an email address will return the same
// userId every time (idempotent) so it can be used as a lightweight
// cross-device identity without a password flow.

const crypto = require('crypto');
const { store } = require('../_lib/store');
const { ok, error, readJson, toVercel } = require('../_lib/http');
const { sign } = require('../_lib/jwt');

function hashEmail(email) {
  return crypto.createHash('sha256').update(email.toLowerCase().trim()).digest('hex');
}

module.exports = toVercel(async (event) => {
  if (event.httpMethod !== 'POST') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }
  const body = await readJson(event);
  const deviceId = body.deviceId ? String(body.deviceId).slice(0, 64) : null;

  let userId, email;
  if (body.email && typeof body.email === 'string') {
    email = body.email.toLowerCase().trim();
    userId = 'usr_' + hashEmail(email).slice(0, 24);
    store.upsertUser(userId, email);
  } else {
    userId = 'usr_' + crypto.randomBytes(12).toString('hex');
    store.upsertUser(userId, null);
  }

  // Issue a self-contained JWT. The token carries the userId + deviceId so
  // /auth/me and requireAuth can work without looking up the session.
  const token = sign({ userId, deviceId });

  return ok({
    token,
    userId,
    user: store.getUser(userId),
    deviceId,
    createdAt: Date.now(),
  });
});
