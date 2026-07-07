// POST /api/auth/signin
// Body: { email?: string, anonymous?: boolean, deviceId?: string }
// Returns: { token, userId, createdAt }
//
// Anonymous mode is the default — pass { anonymous: true } or omit email to
// get a fresh ephemeral user. Passing an email address will return the same
// user record if one already exists for that address (idempotent).

const crypto = require('crypto');
const { store } = require('../_lib/store');
const { ok, error, readJson, handle } = require('../_lib/http');

function hashEmail(email) {
  return crypto.createHash('sha256').update(email.toLowerCase().trim()).digest('hex');
}

module.exports = handle(async (event) => {
  if (event.httpMethod !== 'POST') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }
  const body = await readJson(event);
  const deviceId = body.deviceId ? String(body.deviceId).slice(0, 64) : null;

  let userId;
  if (body.email && typeof body.email === 'string') {
    userId = 'usr_' + hashEmail(body.email).slice(0, 24);
    store.upsertUser(userId, body.email.toLowerCase().trim());
  } else {
    userId = 'usr_' + crypto.randomBytes(12).toString('hex');
    store.upsertUser(userId, null);
  }

  const token = store.createSession(userId, deviceId);
  return ok({
    token,
    userId,
    user: store.getUser(userId),
    deviceId,
    createdAt: Date.now(),
  });
});
