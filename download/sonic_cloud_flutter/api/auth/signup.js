// POST /api/auth/signup
// Body: { email: string, password: string, deviceId?: string, displayName?: string }
// Returns: { token, userId, user (without passwordHash), deviceId, createdAt }
//
// Creates a new user with email + scrypt-hashed password. If the email is
// already registered, returns 409 Conflict. On success, issues a JWT and
// persists the user + device rows.

const crypto = require('crypto');
const { ok, error, readJson, toVercel } = require('../_lib/http');
const { sign } = require('../_lib/jwt');
const { db } = require('../_lib/db');
const { hashPassword, validatePassword, validateEmail } = require('../_lib/password');

function hashEmail(email) {
  return crypto.createHash('sha256').update(email.toLowerCase().trim()).digest('hex');
}

/// Strip sensitive fields (passwordHash, oauthSubject) from the user object
/// before returning it to the client.
function publicUser(user) {
  if (!user) return null;
  return {
    id: user.id,
    email: user.email,
    isAnonymous: user.isAnonymous,
    displayName: user.displayName,
    avatarUrl: user.avatarUrl,
    tier: user.tier,
    oauthProvider: user.oauthProvider,
    settings: user.settings,
    createdAt: user.createdAt,
    lastSeenAt: user.lastSeenAt,
  };
}

module.exports = toVercel(async (event) => {
  if (event.httpMethod !== 'POST') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }
  const body = await readJson(event);

  // Validate email + password
  const emailErr = validateEmail(body.email);
  if (emailErr) return error(emailErr, 400, 'invalid_email');
  const email = body.email.toLowerCase().trim();

  const pwErr = validatePassword(body.password);
  if (pwErr) return error(pwErr, 400, 'invalid_password');

  // Check if email is already registered
  const existing = await db.getUserByEmail(email);
  if (existing) {
    return error('Email already registered', 409, 'email_taken');
  }

  // Hash the password + create the user
  const passwordHash = await hashPassword(body.password);
  const userId = 'usr_' + hashEmail(email).slice(0, 24);
  const displayName = body.displayName || email.split('@')[0];

  await db.upsertUser(userId, email, {
    isAnonymous: false,
    displayName,
    tier: 'member',
    passwordHash,
  });

  // Register device if provided
  const deviceId = body.deviceId ? String(body.deviceId).slice(0, 64) : null;
  if (deviceId) {
    await db.upsertDevice(userId, deviceId, {
      name: body.deviceName || deviceId,
      platform: body.platform || null,
      appVersion: body.appVersion || null,
    });
  }

  // Issue JWT + return
  const token = sign({ userId, deviceId });
  const user = await db.getUser(userId);

  return ok({
    token,
    userId,
    user: publicUser(user),
    deviceId,
    createdAt: Date.now(),
  }, 201);
});

// Export publicUser for reuse by signin.js and oauth.js
module.exports.publicUser = publicUser;
module.exports.hashEmail = hashEmail;
