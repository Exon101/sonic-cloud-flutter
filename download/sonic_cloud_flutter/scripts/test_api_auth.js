// Local end-to-end test of the M3 auth endpoints (signup, password signin,
// OAuth verification shape). Run with: node scripts/test_api_auth.js

const assert = require('assert');
const { Readable } = require('stream');

const auth = require('../api/auth');  // consolidated: signin/signup/oauth/me

let pass = 0, fail = 0;
async function test(name, fn) {
  try { await fn(); pass++; console.log('  ✓', name); }
  catch (e) { fail++; console.error('  ✗', name, '-', e.message); }
}

function mockReq(method, opts = {}) {
  const url = new URL(opts.path || '/api/auth/test', 'http://test.local');
  if (opts.query) for (const [k, v] of Object.entries(opts.query)) url.searchParams.set(k, v);
  const bodyStr = opts.body != null
    ? (typeof opts.body === 'string' ? opts.body : JSON.stringify(opts.body))
    : null;
  const req = Readable.from(bodyStr ? [Buffer.from(bodyStr)] : []);
  req.method = method;
  req.url = url.pathname + url.search;
  req.headers = { ...(opts.headers || {}) };
  if (bodyStr && !req.headers['content-type']) req.headers['content-type'] = 'application/json';
  const query = {};
  for (const [k, v] of url.searchParams.entries()) query[k] = v;
  req.query = Object.keys(query).length > 0 ? query : null;
  return req;
}

function mockRes() {
  const res = {
    statusCode: 200, headers: {}, body: '', finished: false, headersSent: false,
    setHeader(k, v) { this.headers[k] = v; },
    getHeader(k) { return this.headers[k]; },
    status(code) { this.statusCode = code; return this; },
    end(data) { if (data) this.body = typeof data === 'string' ? data : data.toString(); this.finished = true; this.headersSent = true; },
    json(data) { this.body = JSON.stringify(data); this.end(); },
  };
  return res;
}

async function invoke(handler, method, opts = {}) {
  const req = mockReq(method, opts);
  const res = mockRes();
  await handler(req, res);
  let parsed;
  try { parsed = JSON.parse(res.body); } catch (_) { parsed = null; }
  return { statusCode: res.statusCode, headers: res.headers, body: res.body, json: parsed };
}

(async () => {
  console.log('\n/api/auth/signup:');
  const testEmail = `m3test_${Date.now()}@example.com`;
  let signupToken;

  await test('signup creates a new user with email + password', async () => {
    const r = await invoke(auth, 'POST', {
      query: { action: 'signup' },
      body: { email: testEmail, password: 'SecurePass123!', deviceId: 'dev-signup', displayName: 'M3 Tester' },
    });
    assert.strictEqual(r.statusCode, 201, `expected 201, got ${r.statusCode}: ${r.body}`);
    const b = r.json;
    assert.ok(b.token);
    assert.ok(b.userId.startsWith('usr_'));
    assert.strictEqual(b.user.email, testEmail);
    assert.strictEqual(b.user.displayName, 'M3 Tester');
    assert.strictEqual(b.user.passwordHash, undefined, 'passwordHash must not be returned to client');
    signupToken = b.token;
  });

  await test('signup rejects duplicate email with 409', async () => {
    const r = await invoke(auth, 'POST', {
      query: { action: 'signup' },
      body: { email: testEmail, password: 'AnotherPass456!' },
    });
    assert.strictEqual(r.statusCode, 409);
    assert.strictEqual(r.json.code, 'email_taken');
  });

  await test('signup rejects short password', async () => {
    const r = await invoke(auth, 'POST', {
      query: { action: 'signup' },
      body: { email: `short_${Date.now()}@example.com`, password: 'short' },
    });
    assert.strictEqual(r.statusCode, 400);
    assert.strictEqual(r.json.code, 'invalid_password');
  });

  await test('signup rejects invalid email', async () => {
    const r = await invoke(auth, 'POST', {
      query: { action: 'signup' },
      body: { email: 'not-an-email', password: 'SecurePass123!' },
    });
    assert.strictEqual(r.statusCode, 400);
    assert.strictEqual(r.json.code, 'invalid_email');
  });

  console.log('\n/api/auth/signin (with password):');
  await test('signin with correct password succeeds', async () => {
    const r = await invoke(auth, 'POST', {
      query: { action: 'signin' },
      body: { email: testEmail, password: 'SecurePass123!', deviceId: 'dev-signin' },
    });
    assert.strictEqual(r.statusCode, 200, `expected 200, got ${r.statusCode}: ${r.body}`);
    assert.ok(r.json.token);
    assert.strictEqual(r.json.user.email, testEmail);
    assert.strictEqual(r.json.user.passwordHash, undefined);
  });

  await test('signin with wrong password returns 401', async () => {
    const r = await invoke(auth, 'POST', {
      query: { action: 'signin' },
      body: { email: testEmail, password: 'WrongPassword!' },
    });
    assert.strictEqual(r.statusCode, 401);
    assert.strictEqual(r.json.code, 'invalid_credentials');
  });

  await test('signin with email but no password for password-protected account returns 401', async () => {
    const r = await invoke(auth, 'POST', {
      query: { action: 'signin' },
      body: { email: testEmail },
    });
    assert.strictEqual(r.statusCode, 401);
    assert.strictEqual(r.json.code, 'password_required');
  });

  await test('signin with non-existent email + password returns 401 (no email leak)', async () => {
    const r = await invoke(auth, 'POST', {
      query: { action: 'signin' },
      body: { email: 'nonexistent@example.com', password: 'Anything123!' },
    });
    assert.strictEqual(r.statusCode, 401);
    assert.strictEqual(r.json.code, 'invalid_credentials');
  });

  console.log('\n/api/auth/signin (anonymous — still works from M1):');
  await test('anonymous signin still works', async () => {
    const r = await invoke(auth, 'POST', {
      query: { action: 'signin' },
      body: { anonymous: true, deviceId: 'dev-anon' },
    });
    assert.strictEqual(r.statusCode, 200);
    assert.ok(r.json.token);
    assert.ok(r.json.userId.startsWith('usr_'));
    assert.strictEqual(r.json.user.isAnonymous, true);
  });

  console.log('\n/api/auth/oauth (Google):');
  await test('oauth rejects missing idToken', async () => {
    const r = await invoke(auth, 'POST', {
      query: { action: 'oauth' },
      body: { provider: 'google' },
    });
    assert.strictEqual(r.statusCode, 400);
    assert.strictEqual(r.json.code, 'invalid_request');
  });

  await test('oauth rejects unsupported provider', async () => {
    const r = await invoke(auth, 'POST', {
      query: { action: 'oauth' },
      body: { provider: 'facebook', idToken: 'fake-token' },
    });
    assert.strictEqual(r.statusCode, 400);
    assert.strictEqual(r.json.code, 'unsupported_provider');
  });

  await test('oauth rejects invalid Google token', async () => {
    const r = await invoke(auth, 'POST', {
      query: { action: 'oauth' },
      body: { provider: 'google', idToken: 'invalid-token-string' },
    });
    assert.strictEqual(r.statusCode, 401);
    // Either oauth_verification_failed or oauth_failed
    assert.ok(['oauth_verification_failed', 'oauth_failed'].includes(r.json.code));
  });

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail === 0 ? 0 : 1);
})();
