// POST /api/auth/signin
// Body: { email?, password?, anonymous?, deviceId?, deviceName?, platform?, appVersion? }
//
// Three sign-in modes:
//   1. Anonymous  — { anonymous: true } or omit email. Returns a fresh ephemeral user.
//   2. Email + password — { email, password }. Verifies the scrypt hash against
//      the stored password_hash. Returns 401 if the password is wrong.
//   3. Email only (legacy/idempotent) — { email } with no password. Returns the
//      same userId every time (used by M1/M2 before passwords existed). Kept
//      for backward compatibility but discouraged for new clients.
//
// On success, returns: { token, userId, user, deviceId, createdAt }

const crypto = require('crypto');
const { ok, error, readJson, toVercel } = require('../_lib/http');
const { sign } = require('../_lib/jwt');
const { db } = require('../_lib/db');
const { verifyPassword } = require('../_lib/password');
const { publicUser, hashEmail } = require('./signup');

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

    // If a password is provided, verify it against the stored hash
    if (body.password) {
      const user = await db.getUserByEmail(email);
      if (!user || !user.passwordHash) {
        // Don't leak whether the email exists — return the same error
        return error('Invalid email or password', 401, 'invalid_credentials');
      }
      const valid = await verifyPassword(body.password, user.passwordHash);
      if (!valid) {
        return error('Invalid email or password', 401, 'invalid_credentials');
      }
    }
    // If no password provided, fall through to idempotent email signin (M1 mode)
    // — but only if the user doesn't have a password_hash set. If they do, we
    // require a password (don't let passwordless signin bypass it).
    if (!body.password) {
      const existing = await db.getUserByEmail(email);
      if (existing && existing.passwordHash) {
        return error('Password required for this account', 401, 'password_required');
      }
    }

    // Upsert user (idempotent for M1 anonymous-style email signin)
    await db.upsertUser(userId, email, {
      isAnonymous: false,
      displayName: email.split('@')[0],
      tier: 'member',
    });
  } else {
    // Anonymous signin
    userId = 'usr_' + crypto.randomBytes(12).toString('hex');
    isAnonymous = true;
    await db.upsertUser(userId, null, {
      isAnonymous: true,
      displayName: 'Anonymous User',
      tier: 'guest',
    });
  }

  // Register device if provided
  if (deviceId) {
    await db.upsertDevice(userId, deviceId, {
      name: body.deviceName || deviceId,
      platform: body.platform || null,
      appVersion: body.appVersion || null,
    });
  }

  // Issue JWT
  const token = sign({ userId, deviceId });
  const user = await db.getUser(userId);

  return ok({
    token,
    userId,
    user: publicUser(user),
    deviceId,
    createdAt: Date.now(),
  });
});
