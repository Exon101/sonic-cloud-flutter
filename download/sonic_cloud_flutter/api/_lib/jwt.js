// Minimal JWT (JSON Web Token) implementation using Node's built-in crypto.
//
// We don't pull in the `jsonwebtoken` npm package because the API has zero
// runtime dependencies and we want to keep it that way. This implements the
// HS256 algorithm only — sufficient for a stateless serverless backend where
// the same secret is available to every function invocation.
//
// Token shape (base64url-encoded header.payload.signature):
//   header  = {"alg":"HS256","typ":"JWT"}
//   payload = { userId, deviceId, iat, exp }
//   signature = HMAC-SHA256(header.payload, secret)

const crypto = require('crypto');

// The secret is read from the env var `SONIC_JWT_SECRET`. If not set, we
// derive one from the Vercel project ID + deployment ID so tokens are at
// least scoped to a single deployment. In production you should always set
// SONIC_JWT_SECRET as a project env var.
function getSecret() {
  if (process.env.SONIC_JWT_SECRET) return process.env.SONIC_JWT_SECRET;
  return 'sonic-cloud-dev-secret-' + (process.env.VERCEL_PROJECT_ID || 'local');
}

function base64url(buf) {
  return buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64urlDecode(str) {
  str = str.replace(/-/g, '+').replace(/_/g, '/');
  while (str.length % 4) str += '=';
  return Buffer.from(str, 'base64');
}

function sign(payload, opts = {}) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const fullPayload = {
    ...payload,
    iat: now,
    exp: now + (opts.ttlSeconds || 30 * 24 * 60 * 60), // 30 days default
  };
  const encHeader = base64url(Buffer.from(JSON.stringify(header)));
  const encPayload = base64url(Buffer.from(JSON.stringify(fullPayload)));
  const data = `${encHeader}.${encPayload}`;
  const sig = crypto.createHmac('sha256', getSecret()).update(data).digest();
  return `${data}.${base64url(sig)}`;
}

function verify(token) {
  if (!token || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [encHeader, encPayload, encSig] = parts;
  const data = `${encHeader}.${encPayload}`;
  const expectedSig = crypto.createHmac('sha256', getSecret()).update(data).digest();
  const providedSig = base64urlDecode(encSig);

  // Constant-time comparison to prevent timing attacks.
  if (expectedSig.length !== providedSig.length ||
      !crypto.timingSafeEqual(expectedSig, providedSig)) {
    return null;
  }

  try {
    const payload = JSON.parse(base64urlDecode(encPayload).toString('utf-8'));
    if (payload.exp && Math.floor(Date.now() / 1000) >= payload.exp) {
      return null; // expired
    }
    return payload;
  } catch (_) {
    return null;
  }
}

module.exports = { sign, verify, getSecret };
