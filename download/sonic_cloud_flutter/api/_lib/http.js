// Shared HTTP helpers for the Sonic Cloud API.

const VERSION = process.env.SONIC_API_VERSION || '1.0.0';

function json(body, status = 200, extraHeaders = {}) {
  return {
    statusCode: status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Sonic-Api-Version': VERSION,
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,PATCH,OPTIONS',
      'Access-Control-Allow-Headers': 'Authorization,Content-Type,X-Device-Id',
      ...extraHeaders,
    },
    body: JSON.stringify(body),
  };
}

function ok(data, status = 200) {
  return json({ ok: true, ...data }, status);
}

function error(message, status = 400, code = null, extra = {}) {
  return json({ ok: false, error: message, code, ...extra }, status);
}

// Read JSON body from a Vercel function event.
async function readJson(event) {
  if (!event.body) return {};
  const raw = event.isBase64Encoded ? Buffer.from(event.body, 'base64').toString('utf-8') : event.body;
  try {
    return JSON.parse(raw);
  } catch (e) {
    throw Object.assign(new Error('Invalid JSON body'), { status: 400 });
  }
}

// Extract the Bearer token from the Authorization header.
function bearer(event) {
  const h = event.headers && (event.headers.authorization || event.headers.Authorization);
  if (!h) return null;
  const m = /^Bearer\s+(.+)$/i.exec(h);
  return m ? m[1].trim() : null;
}

// Require an authenticated session. Returns { userId, session } on success,
// throws an object suitable for `error()` on failure.
function requireAuth(event, store) {
  const token = bearer(event);
  if (!token) {
    throw { status: 401, message: 'Missing Authorization header', code: 'unauthenticated' };
  }
  const session = store.getSession(token);
  if (!session) {
    throw { status: 401, message: 'Invalid or expired token', code: 'invalid_token' };
  }
  return { token, userId: session.userId, session };
}

// Wrap an async handler so thrown errors become proper JSON responses.
function handle(fn) {
  return async (event, context) => {
    if (event.httpMethod === 'OPTIONS') {
      return json({ ok: true }, 204);
    }
    try {
      return await fn(event, context);
    } catch (e) {
      if (e && typeof e === 'object' && 'status' in e) {
        return error(e.message || 'Request failed', e.status, e.code || null);
      }
      console.error('Unhandled error:', e);
      return error('Internal server error', 500, 'internal');
    }
  };
}

module.exports = { VERSION, json, ok, error, readJson, bearer, requireAuth, handle };
