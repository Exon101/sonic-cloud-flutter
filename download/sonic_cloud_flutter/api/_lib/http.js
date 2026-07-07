// Shared HTTP helpers for the Sonic Cloud API.
//
// HANDLER SIGNATURE
// -----------------
// Each route handler is an async function `async (event) => responseObject`
// where `event` has the shape:
//   { httpMethod, path, headers, body, isBase64Encoded, queryStringParameters }
// and `responseObject` is `{ statusCode, headers, body }`.
//
// This is the AWS Lambda / Netlify-style signature. Vercel's serverless
// functions use the Node.js (req, res) signature instead, so we expose
// `toVercel(fn)` which adapts our handlers to Vercel's runtime.

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

// ── Vercel adapter ───────────────────────────────────────────────────────────
//
// Convert a handler with our `(event) => responseObject` signature to the
// Vercel `(req, res) => void` signature. The adapter:
//   1. Reads the request body from the `req` stream
//   2. Converts `req` to our `event` shape
//   3. Calls the handler (wrapped in `handle()` for error catching)
//   4. Sends the returned response object via `res.status().setHeader().end()`

function toVercel(fn) {
  const wrapped = handle(fn);
  return async (req, res) => {
    // Read the body from the req stream. For GET/DELETE there's usually no
    // body; for POST/PUT/PATCH we read it as a string.
    let body = null;
    if (req.method && req.method !== 'GET' && req.method !== 'HEAD') {
      const chunks = [];
      for await (const chunk of req) {
        chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk);
      }
      body = chunks.length > 0 ? Buffer.concat(chunks).toString('utf-8') : null;
    }

    // Build the `event` shape our handlers expect.
    const event = {
      httpMethod: req.method,
      path: req.url || '',
      headers: req.headers || {},
      body,
      isBase64Encoded: false,
      queryStringParameters: req.query || null,
    };

    // Call the handler and send the response.
    try {
      const result = await wrapped(event, {});
      if (!result) {
        res.status(204).end();
        return;
      }
      const status = result.statusCode || 200;
      const headers = result.headers || {};
      for (const [k, v] of Object.entries(headers)) {
        res.setHeader(k, v);
      }
      res.status(status).end(result.body || '');
    } catch (e) {
      console.error('Vercel adapter error:', e);
      if (!res.headersSent) {
        res.status(500).setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({ ok: false, error: 'Internal server error', code: 'internal' }));
      }
    }
  };
}

module.exports = { VERSION, json, ok, error, readJson, bearer, requireAuth, handle, toVercel };
