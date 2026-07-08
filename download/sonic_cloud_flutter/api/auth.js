// /api/auth/* — consolidated auth endpoint (signs in, signs up, OAuth, me).
//
// Vercel Hobby plan limits each deployment to 12 serverless functions.
// We consolidate the 4 auth endpoints into a single file to stay under
// the limit. The route is determined by the `action` query param or
// the request path suffix.
//
// Routes:
//   POST /api/auth?action=signin    — anonymous or email+password signin
//   POST /api/auth?action=signup    — email+password signup
//   POST /api/auth?action=oauth     — Google OAuth token verification
//   GET  /api/auth?action=me        — current user info
//
// For backward compat, the old paths still work via rewrites in vercel.json:
//   /api/auth/signin → /api/auth?action=signin
//   /api/auth/signup → /api/auth?action=signup
//   /api/auth/oauth  → /api/auth?action=oauth
//   /api/auth/me     → /api/auth?action=me

const crypto = require('crypto');
const { ok, error, readJson, requireAuth, toVercel } = require('./_lib/http');
const { sign } = require('./_lib/jwt');
const { db } = require('./_lib/db');
const { hashPassword, verifyPassword, validatePassword, validateEmail } = require('./_lib/password');

function hashEmail(email) {
  return crypto.createHash('sha256').update(email.toLowerCase().trim()).digest('hex');
}

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

async function verifyGoogleIdToken(idToken) {
  const expectedClientId = process.env.GOOGLE_OAUTH_CLIENT_ID;
  const url = new URL('https://oauth2.googleapis.com/tokeninfo');
  url.searchParams.set('id_token', idToken);
  const res = await fetch(url.toString());
  if (!res.ok) {
    throw Object.assign(new Error(`Google token verification failed: ${res.status}`), {
      status: 401, code: 'oauth_verification_failed',
    });
  }
  const payload = await res.json();
  if (expectedClientId && payload.aud !== expectedClientId) {
    throw Object.assign(new Error('Token audience mismatch'), { status: 401, code: 'oauth_audience_mismatch' });
  }
  if (payload.iss !== 'https://accounts.google.com' && payload.iss !== 'accounts.google.com') {
    throw Object.assign(new Error('Invalid token issuer'), { status: 401, code: 'oauth_invalid_issuer' });
  }
  const now = Math.floor(Date.now() / 1000);
  if (payload.exp && payload.exp < now) {
    throw Object.assign(new Error('Token expired'), { status: 401, code: 'oauth_token_expired' });
  }
  return {
    subject: payload.sub,
    email: payload.email,
    emailVerified: payload.email_verified === 'true' || payload.email_verified === true,
    name: payload.name,
    picture: payload.picture,
  };
}

module.exports = toVercel(async (event) => {
  const action = event.queryStringParameters?.action || 'me';
  const deviceId = (() => {
    const body = event.body ? (() => { try { return JSON.parse(event.body); } catch { return {}; } })() : {};
    return body.deviceId ? String(body.deviceId).slice(0, 64) : null;
  })();

  // ── me ──────────────────────────────────────────────────────────────────
  if (action === 'me' && event.httpMethod === 'GET') {
    const { userId, session } = requireAuth(event, null);
    const user = await db.getUser(userId);
    const devices = await db.listDevices(userId);
    return ok({
      user: publicUser(user) || { id: userId, email: null, isAnonymous: true, createdAt: 0 },
      session: {
        deviceId: session.deviceId,
        createdAt: session.createdAt || 0,
        lastSeenAt: Date.now(),
      },
      devices,
    });
  }

  // All other actions are POST
  if (event.httpMethod !== 'POST') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }

  const body = await readJson(event);

  // ── signin ──────────────────────────────────────────────────────────────
  if (action === 'signin') {
    const did = body.deviceId ? String(body.deviceId).slice(0, 64) : null;
    let userId, email, isAnonymous;

    if (body.email && typeof body.email === 'string') {
      email = body.email.toLowerCase().trim();
      userId = 'usr_' + hashEmail(email).slice(0, 24);
      isAnonymous = false;

      if (body.password) {
        const user = await db.getUserByEmail(email);
        if (!user || !user.passwordHash) {
          return error('Invalid email or password', 401, 'invalid_credentials');
        }
        const valid = await verifyPassword(body.password, user.passwordHash);
        if (!valid) {
          return error('Invalid email or password', 401, 'invalid_credentials');
        }
      } else {
        const existing = await db.getUserByEmail(email);
        if (existing && existing.passwordHash) {
          return error('Password required for this account', 401, 'password_required');
        }
      }
      await db.upsertUser(userId, email, {
        isAnonymous: false,
        displayName: email.split('@')[0],
        tier: 'member',
      });
    } else {
      userId = 'usr_' + crypto.randomBytes(12).toString('hex');
      isAnonymous = true;
      await db.upsertUser(userId, null, {
        isAnonymous: true,
        displayName: 'Anonymous User',
        tier: 'guest',
      });
    }

    if (did) {
      await db.upsertDevice(userId, did, {
        name: body.deviceName || did,
        platform: body.platform || null,
        appVersion: body.appVersion || null,
      });
    }

    const token = sign({ userId, deviceId: did });
    const user = await db.getUser(userId);
    return ok({ token, userId, user: publicUser(user), deviceId: did, createdAt: Date.now() });
  }

  // ── signup ──────────────────────────────────────────────────────────────
  if (action === 'signup') {
    const emailErr = validateEmail(body.email);
    if (emailErr) return error(emailErr, 400, 'invalid_email');
    const email = body.email.toLowerCase().trim();

    const pwErr = validatePassword(body.password);
    if (pwErr) return error(pwErr, 400, 'invalid_password');

    const existing = await db.getUserByEmail(email);
    if (existing) return error('Email already registered', 409, 'email_taken');

    const passwordHash = await hashPassword(body.password);
    const userId = 'usr_' + hashEmail(email).slice(0, 24);
    const displayName = body.displayName || email.split('@')[0];

    await db.upsertUser(userId, email, {
      isAnonymous: false, displayName, tier: 'member', passwordHash,
    });

    const did = body.deviceId ? String(body.deviceId).slice(0, 64) : null;
    if (did) {
      await db.upsertDevice(userId, did, {
        name: body.deviceName || did,
        platform: body.platform || null,
        appVersion: body.appVersion || null,
      });
    }

    const token = sign({ userId, deviceId: did });
    const user = await db.getUser(userId);
    return ok({ token, userId, user: publicUser(user), deviceId: did, createdAt: Date.now() }, 201);
  }

  // ── oauth ───────────────────────────────────────────────────────────────
  if (action === 'oauth') {
    const provider = body.provider || 'google';
    if (provider !== 'google') {
      return error(`Unsupported OAuth provider: ${provider}`, 400, 'unsupported_provider');
    }
    if (!body.idToken || typeof body.idToken !== 'string') {
      return error('Missing required field: idToken', 400, 'invalid_request');
    }

    let googleUser;
    try {
      googleUser = await verifyGoogleIdToken(body.idToken);
    } catch (e) {
      return error(e.message || 'OAuth verification failed', e.status || 401, e.code || 'oauth_failed');
    }
    if (!googleUser.emailVerified) {
      return error('Google email is not verified', 403, 'email_not_verified');
    }

    let user = await db.getUserByOAuth('google', googleUser.subject);
    let linked = true;

    if (!user) {
      const email = googleUser.email.toLowerCase();
      const userId = 'usr_' + hashEmail(email).slice(0, 24);
      user = await db.getUser(userId);
      if (user) {
        await db.linkOAuth(userId, 'google', googleUser.subject);
      } else {
        await db.upsertUser(userId, email, {
          isAnonymous: false,
          displayName: googleUser.name || email.split('@')[0],
          avatarUrl: googleUser.picture || null,
          tier: 'member',
          oauthProvider: 'google',
          oauthSubject: googleUser.subject,
        });
        linked = false;
      }
    }

    const did = body.deviceId ? String(body.deviceId).slice(0, 64) : null;
    if (did) {
      await db.upsertDevice(user.id, did, {
        name: body.deviceName || did,
        platform: body.platform || null,
        appVersion: body.appVersion || null,
      });
    }

    const token = sign({ userId: user.id, deviceId: did });
    const freshUser = await db.getUser(user.id);
    return ok({ token, userId: user.id, user: publicUser(freshUser), deviceId: did, createdAt: Date.now(), linked });
  }

  return error(`Unknown auth action: ${action}`, 400, 'unknown_action');
});
