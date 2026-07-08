// Local end-to-end test of the API.
//
// Handlers now export `toVercel(fn)` which takes the standard Vercel
// `(req, res)` signature. This test builds mock `req` and `res` objects,
// invokes each handler, and asserts on the captured response.
//
// Run with: node scripts/test_api_e2e.js

const assert = require('assert');
const { Readable } = require('stream');

const status = require('../api/status');
const auth = require('../api/auth');  // consolidated: signin/signup/oauth/me
const library = require('../api/library/index');
const libraryId = require('../api/library/[id]');
const playlists = require('../api/playlists/index');
const playlistsId = require('../api/playlists/[id]');
const lyrics = require('../api/lyrics/index');
const sync = require('../api/sync');  // consolidated: push/pull
const devices = require('../api/devices/index');

let pass = 0, fail = 0;
async function test(name, fn) {
  try { await fn(); pass++; console.log('  ✓', name); }
  catch (e) { fail++; console.error('  ✗', name, '-', e.message); }
}

// Build a mock req (Readable stream) + res (captures status/headers/body).
function mockReq(method, opts = {}) {
  const url = new URL(opts.path || '/api/test', 'http://test.local');
  if (opts.query) {
    for (const [k, v] of Object.entries(opts.query)) {
      url.searchParams.set(k, v);
    }
  }
  const bodyStr = opts.body != null
    ? (typeof opts.body === 'string' ? opts.body : JSON.stringify(opts.body))
    : null;

  const req = Readable.from(bodyStr ? [Buffer.from(bodyStr)] : []);
  req.method = method;
  req.url = url.pathname + url.search;
  req.headers = { ...(opts.headers || {}) };
  if (bodyStr && !req.headers['content-type']) {
    req.headers['content-type'] = 'application/json';
  }
  // req.query — Vercel populates this from the URL query string
  const query = {};
  for (const [k, v] of url.searchParams.entries()) query[k] = v;
  req.query = Object.keys(query).length > 0 ? query : null;

  return req;
}

function mockRes() {
  const res = {
    statusCode: 200,
    headers: {},
    body: '',
    finished: false,
    headersSent: false,
    setHeader(k, v) { this.headers[k] = v; },
    getHeader(k) { return this.headers[k]; },
    status(code) { this.statusCode = code; return this; },
    end(data) {
      if (data) this.body = typeof data === 'string' ? data : data.toString();
      this.finished = true;
      this.headersSent = true;
    },
    json(data) { this.body = JSON.stringify(data); this.end(); },
  };
  return res;
}

// Invoke a handler with mock req/res and return the parsed response.
async function invoke(handler, method, opts = {}) {
  const req = mockReq(method, opts);
  const res = mockRes();
  await handler(req, res);
  let parsed;
  try { parsed = JSON.parse(res.body); } catch (_) { parsed = null; }
  return { statusCode: res.statusCode, headers: res.headers, body: res.body, json: parsed };
}

function parse(r) { return r.json; }
function authHeader(token) { return { Authorization: 'Bearer ' + token }; }

(async () => {
  console.log('\n/status:');
  await test('GET returns 200 with endpoint list', async () => {
    const r = await invoke(status, 'GET');
    assert.strictEqual(r.statusCode, 200);
    const b = r.json;
    assert.ok(b.ok);
    assert.ok(Array.isArray(b.endpoints));
    assert.ok(b.endpoints.length > 5);
  });
  await test('POST returns 405', async () => {
    const r = await invoke(status, 'POST');
    assert.strictEqual(r.statusCode, 405);
  });

  console.log('\n/auth/signin:');
  let anonToken, emailToken;
  await test('anonymous signin returns token + userId', async () => {
    const r = await invoke(auth, 'POST', { query: { action: 'signin' }, body: { anonymous: true, deviceId: 'test-dev' } });
    assert.strictEqual(r.statusCode, 200);
    const b = r.json;
    assert.ok(b.token && b.token.length > 40);
    assert.ok(b.userId.startsWith('usr_'));
    anonToken = b.token;
  });
  await test('email signin is idempotent (same email → same userId)', async () => {
    const r1 = await invoke(auth, 'POST', { query: { action: 'signin' }, body: { email: 'alice@example.com' } });
    const r2 = await invoke(auth, 'POST', { query: { action: 'signin' }, body: { email: 'ALICE@example.com' } });
    assert.strictEqual(r1.json.userId, r2.json.userId);
    emailToken = r2.json.token;
  });
  await test('GET returns 405', async () => {
    const r = await invoke(auth, 'GET', { query: { action: 'signin' } });
    assert.strictEqual(r.statusCode, 405);
  });

  console.log('\n/auth/me:');
  await test('returns user with valid token', async () => {
    const r = await invoke(auth, 'GET', { query: { action: 'me' }, headers: authHeader(emailToken) });
    assert.strictEqual(r.statusCode, 200);
    const b = r.json;
    // JWT-based auth: the user id is extracted from the token, email is null
    // (the JWT doesn't carry email — only userId + deviceId).
    assert.ok(b.user.id.startsWith('usr_'));
    assert.ok(b.session.deviceId !== undefined);
  });
  await test('returns 401 without token', async () => {
    const r = await invoke(auth, 'GET', { query: { action: 'me' } });
    assert.strictEqual(r.statusCode, 401);
  });
  await test('returns 401 with bogus token', async () => {
    const r = await invoke(auth, 'GET', { query: { action: 'me' }, headers: authHeader('bogus') });
    assert.strictEqual(r.statusCode, 401);
  });

  console.log('\n/library:');
  let trackId = 'tr_e2e_1';
  await test('POST creates a track', async () => {
    const r = await invoke(library, 'POST', {
      headers: authHeader(anonToken),
      body: { id: trackId, title: 'Test Song', artist: 'Test Artist', duration: 180 },
    });
    assert.strictEqual(r.statusCode, 201);
    const b = r.json;
    assert.strictEqual(b.track.title, 'Test Song');
  });
  await test('GET lists tracks including the new one', async () => {
    const r = await invoke(library, 'GET', { headers: authHeader(anonToken) });
    assert.strictEqual(r.statusCode, 200);
    const b = r.json;
    assert.ok(b.total >= 1);
    assert.ok(b.tracks.some(t => t.id === trackId));
  });
  await test('GET /library/:id returns the track', async () => {
    const r = await invoke(libraryId, 'GET', { headers: authHeader(anonToken), query: { id: trackId } });
    assert.strictEqual(r.statusCode, 200);
    assert.strictEqual(r.json.track.id, trackId);
  });
  await test('PUT /library/:id updates the track', async () => {
    const r = await invoke(libraryId, 'PUT', {
      headers: authHeader(anonToken),
      query: { id: trackId },
      body: { title: 'Updated Title' },
    });
    assert.strictEqual(r.statusCode, 200);
    assert.strictEqual(r.json.track.title, 'Updated Title');
  });
  await test('DELETE /library/:id removes the track', async () => {
    const r = await invoke(libraryId, 'DELETE', { headers: authHeader(anonToken), query: { id: trackId } });
    assert.strictEqual(r.statusCode, 200);
    assert.ok(r.json.deleted);
    const after = await invoke(libraryId, 'GET', { headers: authHeader(anonToken), query: { id: trackId } });
    assert.strictEqual(after.statusCode, 404);
  });

  console.log('\n/playlists:');
  let plId;
  await test('POST creates a manual playlist', async () => {
    const r = await invoke(playlists, 'POST', {
      headers: authHeader(anonToken),
      body: { name: 'My List', trackIds: ['tr_a', 'tr_b'] },
    });
    assert.strictEqual(r.statusCode, 201);
    plId = r.json.playlist.id;
    assert.ok(plId);
  });
  await test('POST creates a smart playlist with rules', async () => {
    const r = await invoke(playlists, 'POST', {
      headers: authHeader(anonToken),
      body: { name: 'Smart', kind: 'smart', rules: [{ field: 'genre', op: 'equals', value: 'Rock' }] },
    });
    assert.strictEqual(r.json.playlist.kind, 'smart');
  });
  await test('PATCH adds trackIds', async () => {
    const r = await invoke(playlistsId, 'PATCH', {
      headers: authHeader(anonToken),
      query: { id: plId },
      body: { addTrackIds: ['tr_c', 'tr_d'] },
    });
    assert.strictEqual(r.statusCode, 200);
    const ids = r.json.playlist.trackIds;
    assert.ok(ids.includes('tr_c') && ids.includes('tr_d'));
  });
  await test('PATCH removes trackIds', async () => {
    const r = await invoke(playlistsId, 'PATCH', {
      headers: authHeader(anonToken),
      query: { id: plId },
      body: { removeTrackIds: ['tr_a'] },
    });
    assert.ok(!r.json.playlist.trackIds.includes('tr_a'));
  });
  await test('DELETE removes the playlist', async () => {
    const r = await invoke(playlistsId, 'DELETE', { headers: authHeader(anonToken), query: { id: plId } });
    assert.strictEqual(r.statusCode, 200);
  });

  console.log('\n/lyrics:');
  await test('PUT stores LRC lyrics', async () => {
    const r = await invoke(lyrics, 'PUT', {
      headers: authHeader(anonToken),
      query: { trackId: 'tr_lyrics' },
      body: { raw: '[ti:Title]\n[ar:Artist]\n[00:01.234] First line\n[00:05.00] Second line', provider: 'user' },
    });
    assert.strictEqual(r.statusCode, 200);
    const b = r.json;
    assert.strictEqual(b.lyrics.synced, true);
    assert.strictEqual(b.lyrics.lines.length, 2);
    assert.strictEqual(b.lyrics.metadata.ti, 'Title');
  });
  await test('GET returns the stored lyrics', async () => {
    const r = await invoke(lyrics, 'GET', { headers: authHeader(anonToken), query: { trackId: 'tr_lyrics' } });
    assert.strictEqual(r.statusCode, 200);
    assert.strictEqual(r.json.synced, true);
  });
  await test('GET 404 for unknown track', async () => {
    const r = await invoke(lyrics, 'GET', { headers: authHeader(anonToken), query: { trackId: 'nope' } });
    assert.strictEqual(r.statusCode, 404);
  });

  console.log('\n/sync:');
  await test('push merges partial state', async () => {
    const r1 = await invoke(sync, 'POST', {
      query: { action: 'push' },
      headers: authHeader(anonToken),
      body: { queue: ['a', 'b'], settings: { theme: 'dark' } },
    });
    assert.strictEqual(r1.statusCode, 200);
    const r2 = await invoke(sync, 'POST', {
      query: { action: 'push' },
      headers: authHeader(anonToken),
      body: { settings: { accent: '#0FF' }, favorites: ['a'] },
    });
    const syncState = r2.json.sync;
    assert.deepStrictEqual(syncState.queue, ['a', 'b']);
    assert.deepStrictEqual(syncState.settings, { theme: 'dark', accent: '#0FF' });
    assert.deepStrictEqual(syncState.favorites, ['a']);
  });
  await test('pull returns the merged state', async () => {
    const r = await invoke(sync, 'GET', { query: { action: 'pull' }, headers: authHeader(anonToken) });
    assert.strictEqual(r.statusCode, 200);
    const b = r.json;
    assert.deepStrictEqual(b.sync.queue, ['a', 'b']);
    assert.ok(b.serverTime > 0);
  });
  await test('pull with since=serverTime returns unchanged:true', async () => {
    const first = await invoke(sync, 'GET', { query: { action: 'pull' }, headers: authHeader(anonToken) });
    const r = await invoke(sync, 'GET', {
      query: { action: 'pull', since: String(first.json.serverTime) },
      headers: authHeader(anonToken),
    });
    assert.strictEqual(r.json.unchanged, true);
  });
  await test('ratings clamp to 0..5', async () => {
    const r = await invoke(sync, 'POST', {
      query: { action: 'push' },
      headers: authHeader(anonToken),
      body: { ratings: { good: 4, bad: 99, neg: -3 } },
    });
    const ratings = r.json.sync.ratings;
    assert.strictEqual(ratings.good, 4);
    assert.strictEqual(ratings.bad, 5);
    assert.strictEqual(ratings.neg, 0);
  });

  console.log('\n/devices:');
  await test('GET returns 200 (sessions may be empty in stateless mode)', async () => {
    const r = await invoke(devices, 'GET', { headers: authHeader(anonToken) });
    assert.strictEqual(r.statusCode, 200);
    // JWT-based auth doesn't create server-side sessions, so the list may
    // be empty. We just verify the endpoint responds successfully.
    assert.ok(Array.isArray(r.json.sessions));
  });

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail === 0 ? 0 : 1);
})();
