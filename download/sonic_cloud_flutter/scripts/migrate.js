#!/usr/bin/env node
// Apply the schema to a Turso (libSQL) database.
//
// Usage:
//   TURSO_DB_URL=libsql://... TURSO_AUTH_TOKEN=... node scripts/migrate.js
//
// Or with args:
//   node scripts/migrate.js libsql://... <token>
//
// Idempotent — safe to run multiple times (uses CREATE TABLE IF NOT EXISTS).

const { createClient } = require('@libsql/client');
const fs = require('fs');
const path = require('path');

const url = process.argv[2] || process.env.TURSO_DB_URL;
const token = process.argv[3] || process.env.TURSO_AUTH_TOKEN;

if (!url) {
  console.error('Error: TURSO_DB_URL not set. Pass it as the first arg or env var.');
  process.exit(1);
}
if (!token) {
  console.error('Error: TURSO_AUTH_TOKEN not set. Pass it as the second arg or env var.');
  process.exit(1);
}

const schemaPath = path.join(__dirname, '..', 'api', '_lib', 'schema.sql');
const schema = fs.readFileSync(schemaPath, 'utf-8');

const stmts = schema
  .split(/;\s*\n/)
  .map(s => s.split('\n').filter(line => !line.trim().startsWith('--')).join('\n').trim())
  .filter(s => s.length > 0);

console.log(`▶ Connecting to ${url}`);
const client = createClient({ url, authToken: token });

(async () => {
  console.log(`▶ Running ${stmts.length} schema statements…`);
  let ok = 0, skipped = 0, failed = 0;
  for (const stmt of stmts) {
    const preview = stmt.split('\n')[0].slice(0, 80);
    try {
      await client.execute(stmt);
      console.log(`  ✓ ${preview}`);
      ok++;
    } catch (e) {
      if (/already exists/i.test(e.message)) {
        console.log(`  ⊙ ${preview} (already exists, skipped)`);
        skipped++;
      } else {
        console.error(`  ✗ ${preview}`);
        console.error(`    ${e.message}`);
        failed++;
      }
    }
  }
  console.log(`\n▶ Done: ${ok} applied, ${skipped} skipped, ${failed} failed`);

  // Verify by counting rows in each table
  console.log('\n▶ Verifying tables:');
  for (const t of ['users', 'tracks', 'playlists', 'lyrics', 'devices', 'sync_state']) {
    try {
      const r = await client.execute({ sql: `SELECT COUNT(*) as n FROM ${t}`, args: [] });
      console.log(`  ${t}: ${r.rows[0].n} rows`);
    } catch (e) {
      console.error(`  ${t}: ERROR — ${e.message}`);
    }
  }
  process.exit(failed > 0 ? 1 : 0);
})().catch(e => {
  console.error('Fatal:', e.message);
  process.exit(1);
});
