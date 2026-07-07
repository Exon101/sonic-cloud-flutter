// POST /api/auth/signin
// Body: { email?: string, anonymous?: boolean, deviceId?: string }
// Returns: { token, userId, user, deviceId, createdAt }
//
// Issues a JWT containing { userId, deviceId } so subsequent requests can
// authenticate without a server-side session lookup — essential for
// serverless. Persists the user + device rows in Turso so other devices can
// enumerate active sessions.

const crypto = require('crypto');
const { ok, error, readJson, toVercel } = require('../_lib/http');
const { sign } = require('../_lib/jwt');
const { db } = require('../_lib/db');

function hashEmail(email) {
  return crypto.createHash('sha256').update(email.toLowerCase().trim()).digest('hex');
}

module.exports = toVercel(async (event) => {
  if (event.httpMethod !== 'POST') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }
  const body = await readJson(event);
  const deviceId = body.deviceId ? String(body.deviceId).slice(0, 64) : null;

  let userId, email, isAnonymous;
  if (body.email && typeof body.email === 'string') {
    email = body.email.toLowerCase().trim();
    userId = 'usr_' + hashEmail(email).slice(0, 24);
    isAnonymous = false;
  } else {
    userId = 'usr_' + crypto.randomBytes(12).toString('hex');
    isAnonymous = true;
  }

  // Persist user + device in Turso (idempotent).
  await db.upsertUser(userId, email, {
    isAnonymous,
    displayName: email || 'Anonymous User',
    tier: isAnonymous ? 'guest' : 'member',
  });
  if (deviceId) {
    await db.upsertDevice(userId, deviceId, {
      name: body.deviceName || deviceId,
      platform: body.platform || null,
      appVersion: body.appVersion || null,
    });
  }

  const token = sign({ userId, deviceId });
  const user = await db.getUser(userId);

  return ok({
    token,
    userId,
    user,
    deviceId,
    createdAt: Date.now(),
  });
});
