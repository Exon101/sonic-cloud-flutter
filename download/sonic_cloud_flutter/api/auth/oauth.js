// POST /api/auth/oauth
// Body: { provider: 'google', idToken: string, deviceId?, deviceName?, platform?, appVersion? }
// Returns: { token, userId, user, deviceId, createdAt, linked: bool }
//
// Verifies a Google ID token (issued by google_sign_in on the client) by
// calling Google's tokeninfo endpoint. If valid, extracts the user's Google
// subject ID + email, then either:
//   - Returns the existing user linked to this Google subject, or
//   - Creates a new user with the Google email + links the OAuth subject.
//
// The client-side flow uses the `google_sign_in` Flutter package, which
// returns an ID token after the user signs in with their Google account.
// We verify that token server-side (so the client can't forge it) and
// issue our own JWT — the client never sees the Google OAuth client secret.
//
// Setup (one-time, free):
//   1. Create a Google OAuth client ID at https://console.cloud.google.com
//      (APIs & Services → Credentials → Create OAuth client ID → Web application)
//   2. Add the client ID to the Flutter app's web/index.html + Android/iOS config
//   3. (Optional) Set GOOGLE_OAUTH_CLIENT_ID env var on Vercel to restrict
//      token verification to your client only. If unset, any Google ID token
//      is accepted — fine for personal use, tighter for production.
//
// Cost: $0 — Google's tokeninfo endpoint is free, no API quota.

const crypto = require('crypto');
const { ok, error, readJson, toVercel } = require('../_lib/http');
const { sign } = require('../_lib/jwt');
const { db } = require('../_lib/db');
const { publicUser, hashEmail } = require('./signup');

/// Verify a Google ID token by calling Google's tokeninfo endpoint.
/// Returns { subject, email, emailVerified, name, picture } on success,
/// throws on failure.
async function verifyGoogleIdToken(idToken) {
  const expectedClientId = process.env.GOOGLE_OAUTH_CLIENT_ID;
  const url = new URL('https://oauth2.googleapis.com/tokeninfo');
  url.searchParams.set('id_token', idToken);
  if (expectedClientId) {
    // tokeninfo will return 401 if the audience doesn't match
  }

  const res = await fetch(url.toString());
  if (!res.ok) {
    const text = await res.text();
    throw Object.assign(new Error(`Google token verification failed: ${res.status}`), {
      status: 401,
      code: 'oauth_verification_failed',
      detail: text,
    });
  }
  const payload = await res.json();

  // Verify audience matches our client ID (if configured)
  if (expectedClientId && payload.aud !== expectedClientId) {
    throw Object.assign(new Error('Token audience mismatch'), {
      status: 401,
      code: 'oauth_audience_mismatch',
    });
  }

  // Verify issuer
  if (payload.iss !== 'https://accounts.google.com' && payload.iss !== 'accounts.google.com') {
    throw Object.assign(new Error('Invalid token issuer'), {
      status: 401,
      code: 'oauth_invalid_issuer',
    });
  }

  // Verify token isn't expired
  const now = Math.floor(Date.now() / 1000);
  if (payload.exp && payload.exp < now) {
    throw Object.assign(new Error('Token expired'), {
      status: 401,
      code: 'oauth_token_expired',
    });
  }

  return {
    subject: payload.sub,           // Google's stable user ID
    email: payload.email,           // user's Google email
    emailVerified: payload.email_verified === 'true' || payload.email_verified === true,
    name: payload.name,             // user's display name
    picture: payload.picture,       // avatar URL
  };
}

module.exports = toVercel(async (event) => {
  if (event.httpMethod !== 'POST') {
    return error('Method not allowed', 405, 'method_not_allowed');
  }
  const body = await readJson(event);
  const provider = body.provider || 'google';
  if (provider !== 'google') {
    return error(`Unsupported OAuth provider: ${provider}`, 400, 'unsupported_provider');
  }
  if (!body.idToken || typeof body.idToken !== 'string') {
    return error('Missing required field: idToken', 400, 'invalid_request');
  }

  // Verify the Google ID token
  let googleUser;
  try {
    googleUser = await verifyGoogleIdToken(body.idToken);
  } catch (e) {
    return error(e.message || 'OAuth verification failed', e.status || 401, e.code || 'oauth_failed');
  }
  if (!googleUser.emailVerified) {
    return error('Google email is not verified', 403, 'email_not_verified');
  }

  // Check if a user is already linked to this Google subject
  let user = await db.getUserByOAuth('google', googleUser.subject);
  let linked = true;

  if (!user) {
    // No existing link — create a new user (or merge with an existing email user)
    const email = googleUser.email.toLowerCase();
    const userId = 'usr_' + hashEmail(email).slice(0, 24);
    user = await db.getUser(userId);
    if (user) {
      // Email user exists — link the OAuth subject to it
      await db.linkOAuth(userId, 'google', googleUser.subject);
    } else {
      // Create a new user
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

  // Register device if provided
  const deviceId = body.deviceId ? String(body.deviceId).slice(0, 64) : null;
  if (deviceId) {
    await db.upsertDevice(user.id, deviceId, {
      name: body.deviceName || deviceId,
      platform: body.platform || null,
      appVersion: body.appVersion || null,
    });
  }

  // Issue our JWT
  const token = sign({ userId: user.id, deviceId });
  const freshUser = await db.getUser(user.id);

  return ok({
    token,
    userId: user.id,
    user: publicUser(freshUser),
    deviceId,
    createdAt: Date.now(),
    linked,
  });
});
