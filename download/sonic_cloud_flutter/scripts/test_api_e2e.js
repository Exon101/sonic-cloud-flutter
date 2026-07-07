// Local end-to-end test of the API by simulating Vercel function events.
// Run with: node scripts/test_api_e2e.js

const assert = require('assert');

// Each Vercel function exports an async (event, context) -> {statusCode, body, headers}.
const status = require('../api/status');
const signin = require('../api/auth/signin');
const me = require('../api/auth/me');
const library = require('../api/library/index');
const libraryId = require('../api/library/[id]');
const playlists = require('../api/playlists/index');
const playlistsId = require('../api/playlists/[id]');
const lyrics = require('../api/lyrics/index');
const syncPush = require('../api/sync/push');
const syncPull = require('../api/sync/pull');
const devices = require('../api/devices/index');

let pass = 0, fail = 0;
async function test(name, fn) {
  try { await fn(); pass++; console.log('  ✓', name); }
  catch (e) { fail++; console.error('  ✗', name, '-', e.message); }
}

function ev(method, opts = {}) {
  return {
    httpMethod: method,
    path: opts.path || '',
    headers: opts.headers || {},
    body: opts.body != null ? (typeof opts.body === 'string' ? opts.body : JSON.stringify(opts.body)) : null,
    isBase64Encoded: false,
    queryStringParameters: opts.query || null,
  };
}
function parse(r) { return JSON.parse(r.body); }
function authHeader(token) { return { Authorization: 'Bearer ' + token }; }

(async () => {
  console.log('\n/status:');
  await test('GET returns 200 with endpoint list', async () => {
    const r = await status(ev('GET'));
    assert.strictEqual(r.statusCode, 200);
    const b = parse(r);
    assert.ok(b.ok);
    assert.ok(Array.isArray(b.endpoints));
    assert.ok(b.endpoints.length > 5);
  });
  await test('POST returns 405', async () => {
    const r = await status(ev('POST'));
    assert.strictEqual(r.statusCode, 405);
  });

  console.log('\n/auth/signin:');
  let anonToken, emailToken;
  await test('anonymous signin returns token + userId', async () => {
    const r = await signin(ev('POST', { body: { anonymous: true, deviceId: 'test-dev' } }));
    assert.strictEqual(r.statusCode, 200);
    const b = parse(r);
    assert.ok(b.token && b.token.length > 40);
    assert.ok(b.userId.startsWith('usr_'));
    anonToken = b.token;
  });
  await test('email signin is idempotent (same email → same userId)', async () => {
    const r1 = await signin(ev('POST', { body: { email: 'alice@example.com' } }));
    const r2 = await signin(ev('POST', { body: { email: 'ALICE@example.com' } }));
    assert.strictEqual(parse(r1).userId, parse(r2).userId);
    emailToken = parse(r2).token;
  });
  await test('GET returns 405', async () => {
    const r = await signin(ev('GET'));
    assert.strictEqual(r.statusCode, 405);
  });

  console.log('\n/auth/me:');
  await test('returns user with valid token', async () => {
    const r = await me(ev('GET', { headers: authHeader(emailToken) }));
    assert.strictEqual(r.statusCode, 200);
    const b = parse(r);
    assert.ok(b.user.email.includes('alice'));
  });
  await test('returns 401 without token', async () => {
    const r = await me(ev('GET'));
    assert.strictEqual(r.statusCode, 401);
  });
  await test('returns 401 with bogus token', async () => {
    const r = await me(ev('GET', { headers: authHeader('bogus') }));
    assert.strictEqual(r.statusCode, 401);
  });

  console.log('\n/library:');
  let trackId = 'tr_e2e_1';
  await test('POST creates a track', async () => {
    const r = await library(ev('POST', {
      headers: authHeader(anonToken),
      body: { id: trackId, title: 'Test Song', artist: 'Test Artist', duration: 180 },
    }));
    assert.strictEqual(r.statusCode, 201);
    const b = parse(r);
    assert.strictEqual(b.track.title, 'Test Song');
    assert.strictEqual(b.track.userId, parse(await me(ev('GET', { headers: authHeader(anonToken) }))).user.id);
  });
  await test('GET lists tracks including the new one', async () => {
    const r = await library(ev('GET', { headers: authHeader(anonToken) }));
    assert.strictEqual(r.statusCode, 200);
    const b = parse(r);
    assert.ok(b.total >= 1);
    assert.ok(b.tracks.some(t => t.id === trackId));
  });
  await test('GET /library/:id returns the track', async () => {
    const r = await libraryId(ev('GET', { headers: authHeader(anonToken), query: { id: trackId } }));
    assert.strictEqual(r.statusCode, 200);
    assert.strictEqual(parse(r).track.id, trackId);
  });
  await test('PUT /library/:id updates the track', async () => {
    const r = await libraryId(ev('PUT', {
      headers: authHeader(anonToken),
      query: { id: trackId },
      body: { title: 'Updated Title' },
    }));
    assert.strictEqual(r.statusCode, 200);
    assert.strictEqual(parse(r).track.title, 'Updated Title');
  });
  await test('DELETE /library/:id removes the track', async () => {
    const r = await libraryId(ev('DELETE', { headers: authHeader(anonToken), query: { id: trackId } }));
    assert.strictEqual(r.statusCode, 200);
    assert.ok(parse(r).deleted);
    const after = await libraryId(ev('GET', { headers: authHeader(anonToken), query: { id: trackId } }));
    assert.strictEqual(after.statusCode, 404);
  });

  console.log('\n/playlists:');
  let plId;
  await test('POST creates a manual playlist', async () => {
    const r = await playlists(ev('POST', {
      headers: authHeader(anonToken),
      body: { name: 'My List', trackIds: ['tr_a', 'tr_b'] },
    }));
    assert.strictEqual(r.statusCode, 201);
    plId = parse(r).playlist.id;
    assert.ok(plId);
  });
  await test('POST creates a smart playlist with rules', async () => {
    const r = await playlists(ev('POST', {
      headers: authHeader(anonToken),
      body: { name: 'Smart', kind: 'smart', rules: [{ field: 'genre', op: 'equals', value: 'Rock' }] },
    }));
    assert.strictEqual(parse(r).playlist.kind, 'smart');
  });
  await test('PATCH adds trackIds', async () => {
    const r = await playlistsId(ev('PATCH', {
      headers: authHeader(anonToken),
      query: { id: plId },
      body: { addTrackIds: ['tr_c', 'tr_d'] },
    }));
    assert.strictEqual(r.statusCode, 200);
    const ids = parse(r).playlist.trackIds;
    assert.ok(ids.includes('tr_c') && ids.includes('tr_d'));
  });
  await test('PATCH removes trackIds', async () => {
    const r = await playlistsId(ev('PATCH', {
      headers: authHeader(anonToken),
      query: { id: plId },
      body: { removeTrackIds: ['tr_a'] },
    }));
    assert.ok(!parse(r).playlist.trackIds.includes('tr_a'));
  });
  await test('DELETE removes the playlist', async () => {
    const r = await playlistsId(ev('DELETE', { headers: authHeader(anonToken), query: { id: plId } }));
    assert.strictEqual(r.statusCode, 200);
  });

  console.log('\n/lyrics:');
  await test('PUT stores LRC lyrics', async () => {
    const r = await lyrics(ev('PUT', {
      headers: authHeader(anonToken),
      query: { trackId: 'tr_lyrics' },
      body: { raw: '[ti:Title]\n[ar:Artist]\n[00:01.234] First line\n[00:05.00] Second line', provider: 'user' },
    }));
    assert.strictEqual(r.statusCode, 200);
    const b = parse(r);
    assert.strictEqual(b.lyrics.synced, true);
    assert.strictEqual(b.lyrics.lines.length, 2);
    assert.strictEqual(b.lyrics.metadata.ti, 'Title');
  });
  await test('GET returns the stored lyrics', async () => {
    const r = await lyrics(ev('GET', { headers: authHeader(anonToken), query: { trackId: 'tr_lyrics' } }));
    assert.strictEqual(r.statusCode, 200);
    assert.strictEqual(parse(r).synced, true);
  });
  await test('GET 404 for unknown track', async () => {
    const r = await lyrics(ev('GET', { headers: authHeader(anonToken), query: { trackId: 'nope' } }));
    assert.strictEqual(r.statusCode, 404);
  });

  console.log('\n/sync:');
  await test('push merges partial state', async () => {
    const r1 = await syncPush(ev('POST', {
      headers: authHeader(anonToken),
      body: { queue: ['a', 'b'], settings: { theme: 'dark' } },
    }));
    assert.strictEqual(r1.statusCode, 200);
    const r2 = await syncPush(ev('POST', {
      headers: authHeader(anonToken),
      body: { settings: { accent: '#0FF' }, favorites: ['a'] },
    }));
    const sync = parse(r2).sync;
    assert.deepStrictEqual(sync.queue, ['a', 'b']);
    assert.deepStrictEqual(sync.settings, { theme: 'dark', accent: '#0FF' });
    assert.deepStrictEqual(sync.favorites, ['a']);
  });
  await test('pull returns the merged state', async () => {
    const r = await syncPull(ev('GET', { headers: authHeader(anonToken) }));
    assert.strictEqual(r.statusCode, 200);
    const b = parse(r);
    assert.deepStrictEqual(b.sync.queue, ['a', 'b']);
    assert.ok(b.serverTime > 0);
  });
  await test('pull with since=serverTime returns unchanged:true', async () => {
    const first = parse(await syncPull(ev('GET', { headers: authHeader(anonToken) })));
    const r = await syncPull(ev('GET', { headers: authHeader(anonToken), query: { since: String(first.serverTime) } }));
    assert.strictEqual(parse(r).unchanged, true);
  });
  await test('ratings clamp to 0..5', async () => {
    const r = await syncPush(ev('POST', {
      headers: authHeader(anonToken),
      body: { ratings: { good: 4, bad: 99, neg: -3 } },
    }));
    const ratings = parse(r).sync.ratings;
    assert.strictEqual(ratings.good, 4);
    assert.strictEqual(ratings.bad, 5);
    assert.strictEqual(ratings.neg, 0);
  });

  console.log('\n/devices:');
  await test('GET lists sessions', async () => {
    const r = await devices(ev('GET', { headers: authHeader(anonToken) }));
    assert.strictEqual(r.statusCode, 200);
    assert.ok(parse(r).sessions.length >= 1);
  });

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail === 0 ? 0 : 1);
})();
