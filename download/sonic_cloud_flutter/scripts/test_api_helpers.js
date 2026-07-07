// Quick sanity test of the API helpers — runs without Vercel by stubbing
// the requireAuth path. Run with: node scripts/test_api_helpers.js

const assert = require('assert');
const { parseLrc } = require('../api/_lib/lrc');
const { Store } = require('../api/_lib/store');

let pass = 0, fail = 0;
function test(name, fn) {
  try { fn(); pass++; console.log('  ✓', name); }
  catch (e) { fail++; console.error('  ✗', name, '-', e.message); }
}

console.log('\nLRC parser:');
test('parses plain text (no timestamps)', () => {
  const r = parseLrc('Hello world');
  assert.strictEqual(r.synced, false);
  assert.strictEqual(r.lines.length, 1);
  assert.strictEqual(r.lines[0].text, 'Hello world');
  assert.strictEqual(r.lines[0].time, null);
});
test('parses single timestamp', () => {
  const r = parseLrc('[00:12.34] Hello world');
  assert.strictEqual(r.synced, true);
  assert.strictEqual(r.lines[0].time, 12.34);
  assert.strictEqual(r.lines[0].text, 'Hello world');
});
test('parses multi-timestamp per line', () => {
  const r = parseLrc('[00:01.00][00:05.00] Repeat');
  assert.strictEqual(r.lines.length, 2);
  assert.strictEqual(r.lines[0].time, 1.0);
  assert.strictEqual(r.lines[1].time, 5.0);
  assert.strictEqual(r.lines[0].text, 'Repeat');
});
test('parses metadata headers', () => {
  const r = parseLrc('[ti:Song Title]\n[ar:Artist]\n[00:01.00] Line');
  assert.strictEqual(r.metadata.ti, 'Song Title');
  assert.strictEqual(r.metadata.ar, 'Artist');
  assert.strictEqual(r.lines.length, 1);
});
test('parses ms-precision timestamps', () => {
  const r = parseLrc('[00:01.234] Hi');
  assert.ok(Math.abs(r.lines[0].time - 1.234) < 0.001, 'got ' + r.lines[0].time);
});
test('empty input returns empty', () => {
  const r = parseLrc('');
  assert.strictEqual(r.synced, false);
  assert.strictEqual(r.lines.length, 0);
});

console.log('\nStore:');
test('upsertUser creates new user', () => {
  const s = new Store();
  const u = s.upsertUser('usr_test1', 'a@b.com');
  assert.strictEqual(u.id, 'usr_test1');
  assert.strictEqual(u.email, 'a@b.com');
  assert.ok(u.createdAt > 0);
});
test('createSession returns token, getSession validates', () => {
  const s = new Store();
  s.upsertUser('usr_test2');
  const t = s.createSession('usr_test2', 'dev1');
  assert.ok(typeof t === 'string' && t.length === 64);
  const sess = s.getSession(t);
  assert.ok(sess);
  assert.strictEqual(sess.userId, 'usr_test2');
  assert.strictEqual(sess.deviceId, 'dev1');
});
test('listSessions only returns current user', () => {
  const s = new Store();
  s.upsertUser('usr_a'); s.upsertUser('usr_b');
  s.createSession('usr_a', 'dev1');
  s.createSession('usr_a', 'dev2');
  s.createSession('usr_b', 'dev3');
  const list = s.listSessions('usr_a');
  assert.strictEqual(list.length, 2);
  assert.ok(list.every(x => x.userId === 'usr_a'));
});
test('putTrack + getTrack + deleteTrack', () => {
  const s = new Store();
  s.putTrack('usr_t', 'tr1', { title: 'Song' });
  assert.strictEqual(s.getTrack('usr_t', 'tr1').title, 'Song');
  // isolation across users
  assert.strictEqual(s.getTrack('usr_other', 'tr1'), null);
  assert.strictEqual(s.deleteTrack('usr_t', 'tr1'), true);
  assert.strictEqual(s.getTrack('usr_t', 'tr1'), null);
});
test('listTracks paginates by user', () => {
  const s = new Store();
  for (let i = 0; i < 5; i++) s.putTrack('usr_p', 'tr' + i, { i });
  s.putTrack('usr_other', 'trX', {});
  assert.strictEqual(s.listTracks('usr_p').length, 5);
  assert.strictEqual(s.listTracks('usr_other').length, 1);
});
test('putSync merges nested objects', () => {
  const s = new Store();
  s.putSync('usr_s', { settings: { theme: 'dark' }, favorites: ['a'] });
  s.putSync('usr_s', { settings: { accent: '#0FF' }, ratings: { a: 5 } });
  const sync = s.getSync('usr_s');
  assert.deepStrictEqual(sync.settings, { theme: 'dark', accent: '#0FF' });
  assert.deepStrictEqual(sync.favorites, ['a']);
  assert.deepStrictEqual(sync.ratings, { a: 5 });
});
test('putSync replaces arrays (no merge)', () => {
  const s = new Store();
  s.putSync('usr_s', { queue: ['a', 'b'] });
  s.putSync('usr_s', { queue: ['c'] });
  assert.deepStrictEqual(s.getSync('usr_s').queue, ['c']);
});

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
